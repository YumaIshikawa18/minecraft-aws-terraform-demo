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

function buildMessage(event) {
    const detail = event?.detail ?? {};
    const status = detail.lastStatus ?? "UNKNOWN";
    const desired = detail.desiredStatus ?? "UNKNOWN";
    const clusterArn = detail.clusterArn ?? "UNKNOWN";
    const group = detail.group ?? "UNKNOWN";
    const taskArn = detail.taskArn ?? "UNKNOWN";

    if (status === "RUNNING") {
        return [
            "✅ Minecraft server task is RUNNING",
            `- group: ${group}`,
            `- task: ${taskArn}`,
            `- cluster: ${clusterArn}`,
        ].join("\n");
    }

    if (status === "STOPPED") {
        const stoppedReason = detail.stoppedReason ?? "UNKNOWN";
        const stopCode = detail.stopCode ?? "UNKNOWN";
        return [
            "🛑 Minecraft server task is STOPPED",
            `- group: ${group}`,
            `- task: ${taskArn}`,
            `- desired: ${desired}`,
            `- stopCode: ${stopCode}`,
            `- reason: ${stoppedReason}`,
        ].join("\n");
    }

    // Other statuses not notified (message created for logging purposes)
    return [
        "ℹ️ ECS task state changed",
        `- lastStatus: ${status}`,
        `- desiredStatus: ${desired}`,
        `- group: ${group}`,
        `- task: ${taskArn}`,
    ].join("\n");
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

        const status = event?.detail?.lastStatus;

        const notifyRunning = (process.env.NOTIFY_ON_RUNNING ?? "true") === "true";
        const notifyStopped = (process.env.NOTIFY_ON_STOPPED ?? "true") === "true";

        if (status === "RUNNING" && !notifyRunning) return { ignored: true };
        if (status === "STOPPED" && !notifyStopped) return { ignored: true };

        // Ignore statuses other than RUNNING/STOPPED (but log them)
        if (status !== "RUNNING" && status !== "STOPPED") {
            console.log("Ignore status:", status);
            return { ignored: true };
        }

        const webhookUrl = await getWebhookUrl();
        const message = buildMessage(event);

        console.log("Posting to Discord webhook:", {
            status,
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

        // Make it a failed invocation so the issue is visible (and retriable if configured).
        throw error;
    }
};
