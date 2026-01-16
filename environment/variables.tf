variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "name_prefix" {
  type    = string
  default = "mc"
}

variable "minecraft_port" {
  type    = number
  default = 25565
}

# NLBはSGを持たないので、ECSタスクSGに「プレイヤーの送信元CIDR」を許可する
variable "allowed_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"] # まず動かすならこれ。落ち着いたら自宅IP等に絞るの推奨
}

# size別Fargate CPU/Memory（例：small/medium/large）
# cpu: 256/512/1024/2048/4096 ... のようなFargate対応値
variable "sizes" {
  type = map(object({
    cpu    = number
    memory = number
  }))
  default = {
    small  = { cpu = 1024, memory = 2048 }
    medium = { cpu = 2048, memory = 4096 }
    large  = { cpu = 4096, memory = 8192 }
  }
}

variable "minecraft_op_name" {
  type        = string
  description = "OPにする自分のMinecraftユーザー名"
}

# workflowで作るzipのパス（environment/ からの相対）
variable "lambda_zip_path" {
  type    = string
  default = "../lambda/discord-control/dist/discord-control.zip"
}

# Discord Interaction署名検証用Public Key（Discord Developer Portalから）
# この値はSSM Parameter Storeに保存されます
variable "discord_public_key" {
  type        = string
  description = "Discord Application Public Key (will be stored in SSM Parameter Store)"
}

# Discordで許可するRole ID（このRoleを持つユーザーのみ/start /stop）
# この値はSSM Parameter Storeに保存されます
variable "allowed_role_id" {
  type        = string
  description = "Discord Allowed Role ID (will be stored in SSM Parameter Store)"
}
