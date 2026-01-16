// lambda/discord-control/index.mjs
import nacl from "tweetnacl";
import { ECSClient, UpdateServiceCommand } from "@aws-sdk/client-ecs";
import { LambdaClient, InvokeCommand } from "@aws-sdk/client-lambda";
import { SSMClient, GetParameterCommand } from "@aws-sdk/client-ssm";

// Reuse clients across invocations
const ecs = new ECSClient({});
const lambda = new LambdaClient({});
const ssm = new SSMClient({});

// Cache for Discord public key
let cachedPublicKey = null;
// Cache for allowed role ID
let cachedAllowedRoleId = null;

async function getDiscordPublicKey() {
    if (cachedPublicKey) {
        return cachedPublicKey;
    }

    const paramName = process.env.DISCORD_PUBLIC_KEY_PARAM;
    if (!paramName) {
        throw new Error("DISCORD_PUBLIC_KEY_PARAM environment variable is not set");
    }

    try {
        const command = new GetParameterCommand({
            Name: paramName,
            WithDecryption: true,
        });
        const response = await ssm.send(command);
        cachedPublicKey = response.Parameter?.Value;
        
        if (!cachedPublicKey || cachedPublicKey.trim() === '') {
            throw new Error("Discord public key not found in SSM Parameter Store");
        }
        
        return cachedPublicKey;
    } catch (err) {
        console.error("Failed to fetch Discord public key from SSM:", err);
        throw err;
    }
}

async function getAllowedRoleId() {
    if (cachedAllowedRoleId) {
        return cachedAllowedRoleId;
    }

    const paramName = process.env.ALLOWED_ROLE_ID_PARAM;
    if (!paramName) {
        throw new Error("ALLOWED_ROLE_ID_PARAM environment variable is not set");
    }

    try {
        const command = new GetParameterCommand({
            Name: paramName,
            WithDecryption: true,
        });
        const response = await ssm.send(command);
        cachedAllowedRoleId = response.Parameter?.Value;
        
        if (!cachedAllowedRoleId || cachedAllowedRoleId.trim() === '') {
            throw new Error("Allowed role ID not found in SSM Parameter Store");
        }
        
        return cachedAllowedRoleId;
    } catch (err) {
        console.error("Failed to fetch allowed role ID from SSM:", err);
        throw err;
    }
}

function json(statusCode, obj) {
    return {
        statusCode,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(obj),
    };
}

function verifyDiscordSignature(rawBody, signatureHex, timestamp, publicKeyHex) {
    try {
        const message = new Uint8Array(Buffer.from(timestamp + rawBody));
        const sig = new Uint8Array(Buffer.from(signatureHex, "hex"));
        const key = new Uint8Array(Buffer.from(publicKeyHex, "hex"));
        return nacl.sign.detached.verify(message, sig, key);
    } catch (err) {
        console.error("Signature verification error:", err);
        return false;
    }
}

/**
 * Extract worker payload robustly.
 * - Self-invocation via Lambda Invoke may arrive as:
 *   - an object (most common)
 *   - a JSON string (rare)
 *   - { body: "json-string" } (rare)
 */
function extractWorkerPayload(event) {
    if (event == null) return null;

    if (typeof event === "string") {
        try {
            return JSON.parse(event);
        } catch {
            return null;
        }
    }

    if (typeof event === "object" && typeof event.body === "string") {
        try {
            return JSON.parse(event.body);
        } catch {
            // fallthrough
        }
    }

    return event;
}

function discordEphemeral(content) {
    return json(200, {
        type: 4,
        data: { content, flags: 64 },
    });
}

export const handler = async (event, context) => {
    // Prefer returning immediately; don't wait on open handles.
    if (context && typeof context.callbackWaitsForEmptyEventLoop !== "undefined") {
        context.callbackWaitsForEmptyEventLoop = false;
    }

    // ---- Worker mode (async self-invoked) ----
    const workerPayload = extractWorkerPayload(event);
    const isWorkerMode =
        workerPayload &&
        (workerPayload._async === true || workerPayload.__workerMode === true);

    if (isWorkerMode) {
        const action = workerPayload.action;
        const size = workerPayload.size;

        const clusterArn = process.env.ECS_CLUSTER_ARN;
        const serviceName = process.env.ECS_SERVICE_NAME;

        if (!clusterArn || !serviceName) {
            console.error("Missing ECS_CLUSTER_ARN or ECS_SERVICE_NAME");
            return { ok: false, error: "Missing ECS configuration" };
        }

        const taskDef =
            size === "large"
                ? process.env.TASKDEF_LARGE
                : size === "medium"
                    ? process.env.TASKDEF_MEDIUM
                    : process.env.TASKDEF_SMALL;

        try {
            if (action === "start") {
                if (!taskDef) {
                    console.error(`Task definition not configured for size: ${size}`);
                    return { ok: false, error: `Task definition not configured: ${size}` };
                }

                await ecs.send(
                    new UpdateServiceCommand({
                        cluster: clusterArn,
                        service: serviceName,
                        desiredCount: 1,
                        taskDefinition: taskDef,
                    })
                );
                return { ok: true };
            }

            if (action === "stop") {
                await ecs.send(
                    new UpdateServiceCommand({
                        cluster: clusterArn,
                        service: serviceName,
                        desiredCount: 0,
                    })
                );
                return { ok: true };
            }

            console.error("Unknown action:", action);
            return { ok: false, error: "Unknown action" };
        } catch (err) {
            console.error("Worker failed:", err);
            return { ok: false, error: "Worker failed" };
        }
    }

    // ---- HTTP mode (Discord -> API Gateway -> Lambda) ----
    const rawBody = event?.body ?? "";
    const headers = Object.fromEntries(
        Object.entries(event?.headers ?? {}).map(([k, v]) => [
            k.toLowerCase(),
            v,
        ])
    );

    const sig = headers["x-signature-ed25519"];
    const ts = headers["x-signature-timestamp"];

    if (!sig || !ts) {
        // Discord expects a quick response; 401 is fine here.
        return json(401, { error: "missing signature headers" });
    }

    // Fetch public key from SSM Parameter Store
    let publicKey;
    try {
        publicKey = await getDiscordPublicKey();
    } catch (err) {
        console.error("Failed to get Discord public key:", err);
        return json(500, { error: "internal server error" });
    }

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

    // Discord PING
    if (body.type === 1) {
        return json(200, { type: 1 });
    }

    // Role check
    const memberRoles = body?.member?.roles ?? [];
    
    let allowedRole;
    try {
        allowedRole = await getAllowedRoleId();
    } catch (err) {
        console.error("Failed to get allowed role ID:", err);
        return json(500, { error: "internal server error" });
    }

    if (!allowedRole || !memberRoles.includes(allowedRole)) {
        return discordEphemeral("権限がありません（許可ロールが必要）");
    }

    const commandName = body?.data?.name;
    const sizeOpt = (body?.data?.options ?? []).find((o) => o.name === "size");
    const size = sizeOpt?.value ?? "small";

    if (commandName !== "start" && commandName !== "stop") {
        return discordEphemeral("未対応コマンドです");
    }

    // Self-invoke asynchronously for long-running ECS operations
    const functionName = process.env.AWS_LAMBDA_FUNCTION_NAME ?? context?.functionName;
    if (!functionName) {
        console.error("Missing function name (AWS_LAMBDA_FUNCTION_NAME / context.functionName)");
        return discordEphemeral("内部エラーが発生しました。しばらくしてから再試行してください。");
    }

    try {
        await lambda.send(
            new InvokeCommand({
                FunctionName: functionName,
                InvocationType: "Event",
                Payload: Buffer.from(
                    JSON.stringify({
                        _async: true,
                        action: commandName,
                        size,
                    })
                ),
            })
        );
    } catch (err) {
        console.error("Failed to invoke async worker:", err);
        return discordEphemeral("内部エラーが発生しました。しばらくしてから再試行してください。");
    }

    // Immediate ACK to Discord (within 3 seconds)
    if (commandName === "start") {
        return discordEphemeral(`起動要求を受け付けました（size=${size}）`);
    }
    return discordEphemeral("停止要求を受け付けました");
};
