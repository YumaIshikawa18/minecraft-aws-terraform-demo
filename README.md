# minecraft-aws-terraform-demo

AWS上でMinecraftサーバーをTerraformで構築し、Discordから制御できるデモプロジェクトです。

## 🎮 概要

このプロジェクトは、AWS ECS Fargate上でMinecraftサーバーを稼働させ、Discordのスラッシュコマンドでサーバーの起動（サイズ指定可）・停止を行えるインフラストラクチャです。

### 主な特徴

- **AWS ECS Fargate** - サーバーレスコンテナでMinecraftサーバーを実行
- **Amazon EFS** - Minecraftのワールドデータを永続化
- **Discord Bot統合** - スラッシュコマンドでサーバー制御（起動〔サイズ指定可〕/停止）
- **動的スケーリング** - small/medium/largeの3サイズから選択可能
- **GitHub Actions** - OIDC認証でセキュアなCI/CD
- **Infrastructure as Code** - Terraformで全インフラを管理

## 🏗️ アーキテクチャ

```
Discord Slash Commands
    ↓
API Gateway (HTTP API)
    ↓
Lambda Function (Discord Control)
    ↓
ECS Service (Minecraft Server on Fargate)
    ↓
EFS (World Data Storage)
```

### 主要コンポーネント

- **VPC & ネットワーク** - パブリック/プライベートサブネット構成
- **ECS Cluster** - FargateタスクとしてMinecraftサーバーを実行
- **Network Load Balancer** - Minecraftクライアントからの接続を受け付け
- **EFS** - ワールドデータの永続化ストレージ
- **Lambda** - Discord InteractionエンドポイントとECS制御
- **API Gateway** - Lambda用のHTTPエンドポイント

## 📋 前提条件

- AWSアカウント
- Terraform 1.14.3
- Node.js 20.x（Lambdaビルド用）
- GitHubアカウント
- Discordアカウントと開発者アプリケーション

## 🚀 セットアップ

### 1. Bootstrap（初回のみ）

GitHub ActionsがTerraformを実行するための基盤を作成します。

```bash
cd bootstrap
# terraform.tfvars を編集（必要な変数は variables.tf を参照）
# 例：github_owner, github_repo, tfstate_bucket_name など
terraform init
terraform apply
```

これにより以下が作成されます：
- S3バケット（Terraform State用）
- GitHub OIDC Provider
- GitHub Actions用のIAMロール

### 2. Discord Botのセットアップ

1. [Discord Developer Portal](https://discord.com/developers/applications)でアプリケーションを作成
2. Botを追加し、必要な権限を付与
3. `Public Key`をメモ
4. サーバーに招待するBotのURLを生成
5. Slash Commandsを登録：
   - `/start` - サーバーを起動
   - `/stop` - サーバーを停止
6. Interactions Endpoint URLは後でAPI GatewayのURLを設定

### 3. GitHub Secretsの設定

リポジトリのSettings > Secrets and variables > Actionsで以下を設定：

- `AWS_ROLE_ARN` - Bootstrapで作成したIAMロールのARN

### 4. 環境変数の設定

```bash
cd environment
# terraform.tfvars を作成または編集（必要な変数は variables.tf を参照）
```

主な設定項目：
- `discord_public_key` - Discord BotのPublic Key（Discord Developer Portalから取得）
- `allowed_role_id` - 許可するDiscord Role ID（操作を許可するロールのID）
- `allowed_cidr_blocks` - Minecraftサーバーへの接続を許可するCIDR（デフォルト: `0.0.0.0/0`）
- `sizes` - サーバーサイズ別のCPU/メモリ設定

### 5. デプロイ

GitHub Actionsでデプロイします：

1. `.github/workflows/terraform-apply.yml`を実行
2. `confirm_apply`に`APPLY`と入力
3. デプロイ完了後、OutputsにAPI Gateway URLが表示される
4. Discord Developer PortalでInteractions Endpoint URLを設定

## 🎯 使い方

### Discordからサーバーを制御

```
/start [size]     # サーバーを起動（size: small/medium/large、省略時はsmall）
/stop             # サーバーを停止
```

### Minecraftクライアントから接続

Network Load BalancerのDNS名を使用して接続：
```
<NLB-DNS-NAME>:25565
```

NLB DNS名はTerraform OutputsまたはAWSコンソールで確認できます。

## ⚙️ 設定

### サーバーサイズ

`environment/terraform.tfvars`で定義：

```hcl
sizes = {
  small  = { cpu = 1024, memory = 2048 }   # 1vCPU, 2GB RAM
  medium = { cpu = 2048, memory = 4096 }   # 2vCPU, 4GB RAM
  large  = { cpu = 4096, memory = 8192 }   # 4vCPU, 8GB RAM
}
```

### セキュリティ

- `allowed_cidr_blocks` - 接続を許可するIPアドレス範囲を制限することを推奨
- `allowed_role_id` - Discord上で特定のロールを持つユーザーのみ制御可能

## 🗂️ ディレクトリ構造

```
.
├── bootstrap/           # 初期セットアップ（S3, IAM, GitHub OIDC）
├── environment/         # メインのTerraform構成
├── lambda/
│   └── discord-control/ # Discord制御用Lambda関数
├── modules/             # Terraformモジュール
│   ├── discord_control/ # Discord統合
│   ├── efs/            # EFS設定
│   ├── iam_control/    # IAMロール・ポリシー
│   ├── minecraft_ecs/  # ECS/Fargate Minecraft設定
│   └── network/        # VPC、サブネット、セキュリティグループ
└── .github/workflows/  # GitHub Actions CI/CD
```

## 💰 コスト見積もり

主なコスト要因：
- **ECS Fargate** - タスクが稼働している時間に応じて課金
  - Small: 約$0.04/時間
  - Medium: 約$0.08/時間
  - Large: 約$0.16/時間
- **EFS** - ストレージ容量と転送量
- **NLB** - 稼働時間とデータ転送量
- **その他** - Lambda、API Gateway（微量）

💡 **コスト削減のヒント**: 使用しない時は`/stop`コマンドでサーバーを停止してください。EFSにデータは保存されているため、再起動時にワールドが復元されます。

## 🔧 トラブルシューティング

### サーバーが起動しない

1. ECS Cluster/Serviceのログを確認
   ```bash
   aws ecs describe-services --cluster mc-cluster --services mc-service
   ```
2. CloudWatch Logsでコンテナログを確認

### Discordコマンドが応答しない

1. Lambda関数のログをCloudWatch Logsで確認
2. API GatewayのURLが正しく設定されているか確認
3. Discord Public Keyが正しいか確認

## 📝 ライセンス

このプロジェクトはデモ目的で作成されています。

## 参考リンク

- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Discord Developer Portal](https://discord.com/developers/docs)
- [Minecraft Server Properties](https://minecraft.fandom.com/wiki/Server.properties)