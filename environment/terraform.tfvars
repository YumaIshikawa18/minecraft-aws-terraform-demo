aws_region     = "ap-northeast-1"
name_prefix    = "mc"
minecraft_port = 25565

# Minecraft 接続を許可するCIDR
allowed_cidr_blocks = [
  "0.0.0.0/0" # まずは確認用。後で自宅IPに絞るのがおすすめ
]

# サイズ定義（必要なら調整）
sizes = {
  small = {
    cpu    = 2048
    memory = 8192
  }
  medium = {
    cpu    = 4096
    memory = 16384
  }
  large = {
    cpu    = 8192
    memory = 32768
  }
}

minecraft_op_name = "Yuzukiku"

# Discord設定（本番では適切な値に置き換え）
discord_public_key_name        = "/mc/discord/public-key"
allowed_role_id_name           = "/mc/discord/allowed-role-id"
discord_webhook_url_param_name = "/mc/discord/webhook-url"

lambda_discord_control_zip_path = "../lambda/discord-control/dist/discord-control.zip"
lambda_ecs_task_notify_zip_path = "../lambda/ecs-task-notify/dist/ecs-task-notify.zip"
