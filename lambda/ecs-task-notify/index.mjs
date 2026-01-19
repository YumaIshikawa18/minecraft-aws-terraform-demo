import { SSMClient, GetParameterCommand } from "@aws-sdk/client-ssm";

const ssm = new SSMClient({});

// Cache for Lambda container reuse
let cachedWebhookUrl = null;

async function getWebhookUrl() {
    if (cachedWebhookUrl) return cachedWebhookUrl;

    const paramName = process.env.DISCORD_WEBHOOK_URL_PARAM;
    if (!paramName) {
        throw new Error("DISCORD_WEBHOOK_URL_PARAM is not set");
    }

    const res = await ssm.send(
        new GetParameterCommand({
            Name: paramName,
            WithDecryption: true,
        })
    );

    const url = res?.Parameter?.Value;
    if (!url) {
        throw new Error(`SSM parameter has no value: ${paramName}`);
    }

    cachedWebhookUrl = url;
    return url;
}

function buildSimpleMessage(event) {
    const status = event?.detail?.lastStatus;

    if (status === "RUNNING") {
        return "✅ サーバー起動開始しました";
    }
    if (status === "STOPPED") {
        return "🛑 サーバー停止しました";
    }
    return null; // ignore others
}

async function postToDiscordWebhook(webhookUrl, content) {
    const resp = await fetch(webhookUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ content }),
    });

    if (!resp.ok) {
        const body = await resp.text().catch(() => "");
        throw new Error(
            `Discord webhook failed: ${resp.status} ${resp.statusText} body=${body}`
        );
    }
}

export const handler = async (event) => {
    try {
        // Expected from EventBridge (ECS Task State Change)
        const detailType = event?.["detail-type"];
        if (detailType !== "ECS Task State Change") {
            console.log("Ignore event (detail-type mismatch):", detailType);
            return { ignored: true };
        }

        const message = buildSimpleMessage(event);
        if (!message) {
            console.log("Ignore status:", event?.detail?.lastStatus);
            return { ignored: true };
        }

        const webhookUrl = await getWebhookUrl();

        // ログも最小限に（必要なら削ってOK）
        console.log("Posting to Discord webhook:", {
            status: event?.detail?.lastStatus,
            group: event?.detail?.group,
            taskArn: event?.detail?.taskArn,
        });

        await postToDiscordWebhook(webhookUrl, message);
        return { ok: true };
    } catch (error) {
        console.error("Error in ECS task notify handler:", {
            message: error?.message ?? String(error),
            name: error?.name,
            stack: error?.stack,
        });
        throw error;
    }
};
