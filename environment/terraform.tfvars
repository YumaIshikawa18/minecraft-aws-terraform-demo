# Discord Application の Public Key（16進）
discord_public_key = "78f4d8c6aac06ddd406816870b5afaaf13738b06df8f857370409aae3abbd919"

# /start /stop を許可する Discord Role ID
allowed_role_id = "1460573468855767192"

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

minecraft_op_name = "Yuzukiku"
