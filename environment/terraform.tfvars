# Discord Application の Public Key（16進）
# この値はSSM Parameter Storeに保存されます
# 実際の値はterraform apply後に手動でSSMに設定してください
discord_public_key = "dummy"

# /start /stop を許可する Discord Role ID
# この値はSSM Parameter Storeに保存されます
# 実際の値はterraform apply後に手動でSSMに設定してください
allowed_role_id = "dummy"

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
