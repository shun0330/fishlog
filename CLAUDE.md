# fishlog — Claude Code 用プロジェクトメモ

このファイルは、claude.ai でのこれまでのやり取りを要約した引き継ぎ資料。作業を始める前に必ず全部読むこと。

## 目的
- 釣果記録の CRUD アプリ「fishlog」を AWS 上に Terraform で構築し、ポートフォリオとして完成させる
- 作業者が「なぜその設計にしたか」を自分の言葉で説明できる状態にする

## 作業者と進め方
- 作業PCは Windows 11。シェルは PowerShell（VS Code のターミナル）
- 作業者はネットワーク/セキュリティのインフラエンジニア（約3年）で、AWS は学習中
- 返答は日本語のタメ口でOK。結論から言う。推測の部分は「これは推測です」と明記する
- ファイルを作る・変える前に「何を・なぜ」を短く説明し、ネットワークの知識での例えを1つ添える
- 作業者が理解しながら進めたいので、一度に大量に変更しない。1ステップごとに区切って結果を報告する

## 構成（完成済み）
- アプリ：FastAPI + PostgreSQL、Docker（`app/`、ローカルは `docker compose up`）
- リージョン：ap-northeast-1
- VPC 10.0.0.0/16、2AZ
  - public-1a 10.0.1.0/24、public-1c 10.0.2.0/24
  - private-1a 10.0.11.0/24、private-1c 10.0.12.0/24
  - IGW、NAT Gateway は public-1a に1つだけ（コスト優先）
- SG はすべて参照指定で絞っている
  - alb-sg：80 を 0.0.0.0/0 から許可、出口は 8000 を ecs-sg へ
  - ecs-sg：8000 を alb-sg から許可、出口は全部
  - rds-sg：5432 を ecs-sg から許可、出口なし
- RDS：PostgreSQL 16、db.t4g.micro、private サブネット、暗号化あり、パスワードは `manage_master_user_password` で Secrets Manager 管理、バックアップ0、skip_final_snapshot
- ECR（scan_on_push）→ ECS Fargate（256/512、ログは /ecs/fishlog、DB_PASSWORD は Secrets Manager から注入）
- ALB → ターゲットグループ（ip、8000、ヘルスチェック /health）→ リスナー 80
- Terraform：AWS provider ~> 6.0、default_tags Project=fishlog
- SNS トピック（メール購読）＋ CloudWatch アラーム（ALB の Target 5XX、ALARM/OK の両方を通知）
- terraform/ のファイル：main.tf, variables.tf, outputs.tf, network.tf, security.tf, database.tf, ecr.tf, ecs.tf, alb.tf, sns.tf, monitoring.tf
- GitHub：shun0330/fishlog（フェーズ5まで push 済み）

## 進捗
- 完了：フェーズ0〜6（環境準備、ローカルCRUD、Terraform土台、ネットワーク、SG・RDS、ECR・ECS・ALB、監視）
- フェーズ6：2026-11-07 に再作成して、購読承認と set-alarm-state による ALARM→OK の通知メール受信を確認。そのあと destroy 済みで、今は AWS 上に何も無い
- 残り：フェーズ7（構成図・README・再現確認）
- 7-4 の再現確認は、作業者が README を見ながら自分で手を動かして行う（Claude Code はサポート役）。動作確認チェックリストもフェーズ7で作る

## 残タスク

### フェーズ6：監視
- 6-1 `terraform/sns.tf`：SNS トピックとメール購読。メールアドレスは変数 `alert_email` にして、値は terraform.tfvars に入れる（tfvars はコミットしない）
- 6-2 `terraform/monitoring.tf`：CloudWatch アラーム1つ
  - AWS/ApplicationELB の `HTTPCode_Target_5XX_Count`、Sum、期間300秒、しきい値1以上、treat_missing_data は notBreaching
  - ディメンション LoadBalancer は alb.tf の aws_lb リソースの `arn_suffix` を参照する（リソース名は alb.tf を読んで確認）
  - アクションは 6-1 の SNS トピック
- 6-3 `terraform fmt` → `terraform validate` → `terraform plan` で差分を確認して、結果を要約して止まる
- 6-4 作業者の確認後に再作成（下の「再作成手順」）
- 6-5 作業者がメールで購読を承認する
- 6-6 `aws cloudwatch set-alarm-state` でアラームを手動で ALARM にして、通知が届くか確認する
- 6-7 destroy して commit / push

### フェーズ7：仕上げ
- 7-1 構成図：作業者が draw.io で描く。Claude Code は載せる要素の一覧と配置案を出す。PNG は `docs/architecture.png`
- 7-2 README.md：概要／構成図／使用技術／設計で決めたこと（理由つき）／再現手順／コスト（普段は destroy している理由）／今後の改善（CI/CD、HTTPS、WAF、モジュール分割、NAT冗長化）
- 7-3 `terraform/terraform.tfvars.example` を追加する（値は入れない）
- 7-4 別フォルダに clone して、README の手順どおりに構築できるか確認する → destroy
- 7-5 tfstate・tfvars が Git に含まれていないことを確認して最終 push
- 余裕があれば：GitHub Actions で `terraform fmt -check` / `validate` を自動実行する

## 絶対に守るルール
- `terraform apply` / `terraform destroy` / `git push` / `docker push` は必ず作業者の承認を得てから実行する。`-auto-approve` は使わない
- apply したら、その作業日のうちに destroy する（NAT Gateway と ALB は置いておくだけで課金される）
- `terraform.tfstate*`、`terraform.tfvars`、`.terraform/` はコミットしない。git add の前に `git status` で確認する
- `terraform.tfvars`・`terraform.tfstate*` の中身は開かない。Read ツールだけでなく、`cat`・`Get-Content`・スクリプトなどシェル経由でも読まない（settings.json の deny は Read ツールにしか効かないため）
- AWS アカウントID・ARN・メールアドレスを README・コード・コミットメッセージに書かない
- 既存の設定ファイル（`~/.docker/config.json`、`~/.aws/config` など）は丸ごと上書きしない。変更が必要なら差分だけ提案して、作業者に編集してもらう
- 認証コードやワンタイムコードは扱わない。AWS の認証が切れたら作業者に再ログインを頼む

## 認証とコマンドの注意
- 認証は短期認証。作業者が `$env:AWS_PROFILE="fishlog"` → `aws login --remote` を実行する。アクセスキーは作らない
- PowerShell では `-target` を引数ごとクォートする：`terraform apply '-target=aws_ecr_repository.app'`
- ディレクトリ移動は `cd ~\fishlog` / `cd ~\fishlog\terraform` を使う（`cd ..` で上がりすぎた前例あり）

## 再作成手順（AWS 上に再構築するとき）
1. Docker Desktop を起動して、立ち上がるまで待つ
2. `cd ~\fishlog\terraform` → `terraform apply '-target=aws_ecr_repository.app'`
3. ECR にログイン：`aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin <アカウントID>.dkr.ecr.ap-northeast-1.amazonaws.com`（アカウントIDは `aws sts get-caller-identity` で確認する。ファイルには書かない）
4. `cd ~\fishlog` → `docker build -t fishlog ./app` → ECR の URL で tag → push
5. `cd ~\fishlog\terraform` → `terraform apply` → `terraform output` で ALB の DNS を確認する
6. ターゲットが healthy になるまで約10分待ち、ブラウザで確認する
7. 終わったら `terraform destroy`

## 過去のつまずき
- `aws login` が 400 エラーになる → `aws login --remote` を使う
- ECR ログインで "stub received bad data" → `~/.docker/config.json` の credHelpers に ECR のホストを `""` で追加して回避した（他の設定は残した）
- Docker の API エラー → Docker Desktop が起動していなかった
