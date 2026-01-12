# Discord Application の Public Key（16進）
discord_public_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# /start /stop を許可する Discord Role ID
allowed_role_id = "123456789012345678"

# Minecraft 接続を許可するCIDR
allowed_cidr_blocks = [
  "0.0.0.0/0" # まずは確認用。後で自宅IPに絞るのがおすすめ
]

# サイズ定義（必要なら調整）
sizes = {
  small = {
    cpu    = 1024
    memory = 2048
  }
  medium = {
    cpu    = 2048
    memory = 4096
  }
  large = {
    cpu    = 4096
    memory = 8192
  }
}
