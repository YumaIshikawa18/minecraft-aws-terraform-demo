import nacl from "tweetnacl";
import { ECSClient, UpdateServiceCommand } from "@aws-sdk/client-ecs";
import { LambdaClient, InvokeCommand } from "@aws-sdk/client-lambda";

// Initialize AWS SDK clients at module level for reuse across Lambda invocations
// This improves performance by reusing connections. Both clients are needed:
// - ECS client: used in worker mode for service updates
// - Lambda client: used in HTTP mode for self-invocation
const ecs = new ECSClient({});
const lambda = new LambdaClient({});

function json(statusCode, obj) {
    return { statusCode, headers: { "Content-Type": "application/json" }, body: JSON.stringify(obj) };
}

/**
 * Verify Discord request signature using Ed25519
 * @param {string} rawBody - The raw request body
 * @param {string} signature - The signature from x-signature-ed25519 header
 * @param {string} timestamp - The timestamp from x-signature-timestamp header
 * @param {string} publicKey - Discord application public key
 * @returns {boolean} True if signature is valid
 */
function verifyDiscordSignature(rawBody, signature, timestamp, publicKey) {
    try {
        const message = timestamp + rawBody;
        const isValid = nacl.sign.detached.verify(
            Buffer.from(message),
            Buffer.from(signature, "hex"),
            Buffer.from(publicKey, "hex")
        );
        return isValid;
    } catch (err) {
        console.error("Signature verification error:", err);
        return false;
    }
}

/**
 * Discord Control Lambda Handler
 * 
 * This Lambda function operates in two modes:
 * 1. HTTP Request Handler Mode: Receives Discord slash commands via API Gateway,
 *    validates requests, and immediately responds to Discord within 3-second timeout.
 * 2. Async Worker Mode: Executes long-running ECS operations (start/stop) asynchronously
 *    after being invoked by the HTTP handler.
 * 
 * Flow:
 * - Discord → API Gateway → Lambda (HTTP mode) → Immediate response to Discord
 * - Lambda (HTTP mode) → Lambda (Worker mode, async) → ECS operations
 * 
 * This pattern ensures Discord receives a response within their 3-second requirement
 * while allowing ECS operations to complete in the background.
 */
export const handler = async (event, context) => {
    // Lambdaが返した後にイベントループ待ちしない（レスポンス優先）
    if (context && typeof context.callbackWaitsForEmptyEventLoop !== "undefined") {
        context.callbackWaitsForEmptyEventLoop = false;
    }

    // ---- ワーカーモード（自分自身が非同期で呼ばれた時）----
    const isWorkerMode =
        event &&
        (
            // 推奨: namespaced metadata か明示的フラグ
            (event.customInvokeMetadata && event.customInvokeMetadata._async === true) ||
            event.__workerMode === true ||
            // 互換性のための旧フラグ（将来的に削除候補）
            event._async === true
        );

    if (isWorkerMode) {
        const { action, size } = event;

        const clusterArn = process.env.ECS_CLUSTER_ARN;
        const serviceName = process.env.ECS_SERVICE_NAME;

        if (!clusterArn || !serviceName) {
            return { ok: false, error: "Missing ECS configuration: ECS_CLUSTER_ARN or ECS_SERVICE_NAME is not set" };
        }
        const taskDef =
            size === "large" ? process.env.TASKDEF_LARGE :
                size === "medium" ? process.env.TASKDEF_MEDIUM :
                    process.env.TASKDEF_SMALL;

        if (action === "start") {
            if (!taskDef) {
                console.error(`Task definition not found for size: ${size}`);
                return { ok: false, error: `Task definition not configured for size: ${size}` };
            }
            await ecs.send(new UpdateServiceCommand({
                cluster: clusterArn,
                service: serviceName,
                desiredCount: 1,
                taskDefinition: taskDef
            }));
            return { ok: true };
        }

        if (action === "stop") {
            await ecs.send(new UpdateServiceCommand({
                cluster: clusterArn,
                service: serviceName,
                desiredCount: 0
            }));
            return { ok: true };
        }

        return { ok: false, error: "unknown action" };
    }

    // ---- 通常モード（DiscordからのHTTPリクエスト）----
    const rawBody = event.body ?? "";
    const headers = Object.fromEntries(Object.entries(event.headers ?? {}).map(([k, v]) => [k.toLowerCase(), v]));

    // Discord署名検証（セキュリティ必須）
    const sig = headers["x-signature-ed25519"];
    const ts  = headers["x-signature-timestamp"];
    const publicKey = process.env.DISCORD_PUBLIC_KEY;

    if (!sig || !ts || !publicKey) {
        return json(401, { error: "missing signature headers or public key" });
    }

    // Verify Discord request signature
    if (!verifyDiscordSignature(rawBody, sig, ts, publicKey)) {
        console.error("Invalid Discord signature");
        return json(401, { error: "invalid request signature" });
    }

    let body;
    try {
        body = JSON.parse(rawBody);
    } catch (e) {
        return json(400, { error: "invalid JSON body" });
    }

    // PING
    if (body.type === 1) return json(200, { type: 1 });

    // ロールチェック（今のまま）
    const memberRoles = body?.member?.roles ?? [];
    const allowedRole = process.env.ALLOWED_ROLE_ID;
    if (!allowedRole || !memberRoles.includes(allowedRole)) {
        return json(200, { type: 4, data: { content: "権限がありません（許可ロールが必要）", flags: 64 } });
    }

    const commandName = body?.data?.name;
    const sizeOpt = (body?.data?.options ?? []).find(o => o.name === "size");
    const size = sizeOpt?.value ?? "small";

    // NOTE: Concurrent invocations are possible if multiple users send commands simultaneously.
    // The ECS UpdateService API is idempotent, but last-write-wins behavior may occur.
    // Consider implementing a locking mechanism if strict ordering is required.

    // Only invoke async worker for valid start/stop commands
    if (commandName === "start" || commandName === "stop") {
        // ★ ここで自分自身を非同期Invoke（ECS操作はワーカーで実行）
        const functionName = process.env.AWS_LAMBDA_FUNCTION_NAME ?? context.functionName;
        if (!functionName) {
            console.error("Lambda function name is not configured (AWS_LAMBDA_FUNCTION_NAME/context.functionName missing).");
            return json(500, { message: "Lambda function name is not configured." });
        }
        try {
            await lambda.send(new InvokeCommand({
                FunctionName: functionName,
                InvocationType: "Event",
                Payload: Buffer.from(JSON.stringify({
                    _async: true,
                    action: commandName,
                    size
                }))
            }));
        } catch (err) {
            console.error("Failed to invoke async worker Lambda", err);
            return json(200, {
                type: 4,
                data: {
                    content: "内部エラーが発生しました。しばらくしてから再試行してください。",
                    flags: 64
                }
            });
        }

        // ★ Discordへは即返す（3秒以内）
        if (commandName === "start") {
            return json(200, { type: 4, data: { content: `起動要求を受け付けました（size=${size}）`, flags: 64 } });
        }
        if (commandName === "stop") {
            return json(200, { type: 4, data: { content: "停止要求を受け付けました", flags: 64 } });
        }
    }

    // Unknown command
    return json(200, { type: 4, data: { content: "未対応コマンドです", flags: 64 } });
};
