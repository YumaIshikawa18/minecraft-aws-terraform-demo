import nacl from "tweetnacl";
import { ECSClient, UpdateServiceCommand } from "@aws-sdk/client-ecs";
import { LambdaClient, InvokeCommand } from "@aws-sdk/client-lambda";

const ecs = new ECSClient({});
const lambda = new LambdaClient({});

function json(statusCode, obj) {
    return { statusCode, headers: { "Content-Type": "application/json" }, body: JSON.stringify(obj) };
}

export const handler = async (event, context) => {
    // Lambdaが返した後にイベントループ待ちしない（レスポンス優先）
    context.callbackWaitsForEmptyEventLoop = false;

    // ---- ワーカーモード（自分自身が非同期で呼ばれた時）----
    if (event && event._async === true) {
        const { action, size } = event;

        const clusterArn = process.env.ECS_CLUSTER_ARN;
        const serviceName = process.env.ECS_SERVICE_NAME;

        const taskDef =
            size === "large" ? process.env.TASKDEF_LARGE :
                size === "medium" ? process.env.TASKDEF_MEDIUM :
                    process.env.TASKDEF_SMALL;

        if (action === "start") {
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

    // 署名検証（ここはあなたの既存ロジックのままでOK）
    const sig = headers["x-signature-ed25519"];
    const ts  = headers["x-signature-timestamp"];
    const publicKey = process.env.DISCORD_PUBLIC_KEY;

    if (!sig || !ts || !publicKey) return json(401, { error: "missing signature headers or public key" });

    // … verify処理は省略（今のまま使ってOK）

    const body = JSON.parse(rawBody);

    // PING
    if (body.type === 1) return json(200, { type: 1 });

    // ロールチェック（今のまま）
    const memberRoles = body?.member?.roles ?? [];
    const allowedRole = process.env.ALLOWED_ROLE_ID;
    if (!allowedRole || !memberRoles.includes(allowedRole)) {
        return json(200, { type: 4, data: { content: "権限がありません（許可ロールが必要）", flags: 64 } });
    }

    const cmd = body?.data?.name;
    const sizeOpt = (body?.data?.options ?? []).find(o => o.name === "size");
    const size = sizeOpt?.value ?? "small";

    // ★ ここで自分自身を非同期Invoke（ECS操作はワーカーで実行）
    const functionName = process.env.AWS_LAMBDA_FUNCTION_NAME ?? context.functionName;
    if (!functionName) {
        console.error("Lambda function name is not configured (AWS_LAMBDA_FUNCTION_NAME/context.functionName missing).");
        return json(500, { message: "Lambda function name is not configured." });
    }
    await lambda.send(new InvokeCommand({
        FunctionName: functionName,
        InvocationType: "Event",
        Payload: Buffer.from(JSON.stringify({
            _async: true,
            action: cmd,
            size
        }))
    }));

    // ★ Discordへは即返す（3秒以内）
    if (cmd === "start") {
        return json(200, { type: 4, data: { content: `起動要求を受け付けました（size=${size}）`, flags: 64 } });
    }
    if (cmd === "stop") {
        return json(200, { type: 4, data: { content: "停止要求を受け付けました", flags: 64 } });
    }
    return json(200, { type: 4, data: { content: "未対応コマンドです", flags: 64 } });
};
