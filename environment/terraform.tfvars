# Minecraft 接続を許可するCIDR
allowed_cidr_blocks = [
  "0.0.0.0/0" # まずは確認用。後で自宅IPに絞るのがおすすめ
]

# サイズ定義（必要なら調整）
sizes = {
  small = {
    cpu    = 2048
    memory = 4096
  }
  medium = {
    cpu    = 2048
    memory = 8192
  }
  large = {
    cpu    = 4096
    memory = 8192
  }
}

minecraft_op_name = "Yuzukiku"

# Discord設定（本番では適切な値に置き換え）
discord_public_key = "dummy"
allowed_role_id    = "dummy"
