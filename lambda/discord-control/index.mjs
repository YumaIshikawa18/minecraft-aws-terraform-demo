import nacl from "tweetnacl";
import { ECSClient, DescribeServicesCommand, UpdateServiceCommand } from "@aws-sdk/client-ecs";

function hexToUint8(hex) {
    return new Uint8Array(hex.match(/.{1,2}/g).map((b) => parseInt(b, 16)));
}

function verifyDiscordSignature({ publicKeyHex, signatureHex, timestamp, body }) {
    const msg = new TextEncoder().encode(timestamp + body);
    const sig = hexToUint8(signatureHex);
    const pk  = hexToUint8(publicKeyHex);
    return nacl.sign.detached.verify(msg, sig, pk);
}

function json(statusCode, obj) {
    return {
        statusCode,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(obj)
    };
}

export const handler = async (event) => {
    // API Gateway HTTP API (payload v2.0)
    const rawBody = event.body ?? "";
    const headers = Object.fromEntries(Object.entries(event.headers ?? {}).map(([k, v]) => [k.toLowerCase(), v]));

    const sig = headers["x-signature-ed25519"];
    const ts  = headers["x-signature-timestamp"];

    const publicKey = process.env.DISCORD_PUBLIC_KEY;

    if (!sig || !ts || !publicKey) {
        return json(401, { error: "missing signature headers or public key" });
    }

    const ok = verifyDiscordSignature({
        publicKeyHex: publicKey,
        signatureHex: sig,
        timestamp: ts,
        body: rawBody
    });

    if (!ok) {
        return json(401, { error: "invalid request signature" });
    }

    const body = JSON.parse(rawBody);

    // Discord PING
    if (body.type === 1) {
        return json(200, { type: 1 });
    }

    // Command
    const memberRoles = body?.member?.roles ?? [];
    const allowedRole = process.env.ALLOWED_ROLE_ID;

    if (!allowedRole || !memberRoles.includes(allowedRole)) {
        return json(200, {
            type: 4,
            data: { content: "権限がありません（許可ロールが必要）", flags: 64 }
        });
    }

    const name = body?.data?.name;

    const clusterArn = process.env.ECS_CLUSTER_ARN;
    const serviceName = process.env.ECS_SERVICE_NAME;

    const ecs = new ECSClient({});

    if (name === "start") {
        // size option（choice）
        const opt = (body?.data?.options ?? []).find(o => o.name === "size");
        const size = opt?.value ?? "small";

        const taskDef =
            size === "large" ? process.env.TASKDEF_LARGE :
                size === "medium" ? process.env.TASKDEF_MEDIUM :
                    process.env.TASKDEF_SMALL;

        if (!taskDef) {
            return json(200, { type: 4, data: { content: `task definitionが見つかりません: ${size}`, flags: 64 } });
        }

        await ecs.send(new UpdateServiceCommand({
            cluster: clusterArn,
            service: serviceName,
            desiredCount: 1,
            taskDefinition: taskDef
        }));

        return json(200, { type: 4, data: { content: `起動しました（size=${size}）`, flags: 64 } });
    }

    if (name === "stop") {
        await ecs.send(new UpdateServiceCommand({
            cluster: clusterArn,
            service: serviceName,
            desiredCount: 0
        }));

        return json(200, { type: 4, data: { content: "停止しました", flags: 64 } });
    }

    return json(200, { type: 4, data: { content: "未対応コマンドです", flags: 64 } });
};
