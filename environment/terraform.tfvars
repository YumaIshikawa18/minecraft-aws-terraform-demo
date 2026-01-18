# Minecraft 接続を許可するCIDR
allowed_cidr_blocks = [
  "0.0.0.0/0" # まずは確認用。後で自宅IPに絞るのがおすすめ
]

# サイズ定義（必要なら調整）
sizes = {
  small = {
    cpu    = 4096
    memory = 8192
  }
  medium = {
    cpu    = 4096
    memory = 16384
  }
  large = {
    cpu    = 8192
    memory = 16384
  }
}

minecraft_op_name = "Yuzukiku"

# Discord設定（本番では適切な値に置き換え）
discord_public_key_name = "mc/discord/public-key"
allowed_role_id_name    = "mc/discord/allowed-role-id"
