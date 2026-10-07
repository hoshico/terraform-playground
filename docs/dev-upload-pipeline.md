# ファイル受付パイプライン

dev 環境、リージョン `ap-northeast-1`、LocalStack Hobby。クライアントが API へファイルを渡し、S3 への保存を契機に SQS へイベントを送り、処理 Lambda がログを残す。

図は `docs/diagrams/dev-upload-pipeline.drawio` に置く。

## 処理の流れ

1. クライアントが API Gateway の `POST /uploads` にファイルを渡す。
2. 受付 Lambda が S3 の `incoming/` に保存し、CloudWatch Logs に書く。
3. S3 の `ObjectCreated` が SQS `incoming-objects` に届く。3 回失敗したら DLQ へ回す。
4. 処理 Lambda がキューを受け、オブジェクトを読み、結果を CloudWatch Logs に書く。

処理 Lambda の S3 読み直しは、イベントの進行とは別の参照である。

## 通信要件

LocalStack の列は、Hobby で API を叩いて確認できるかを表す。`実行できる` は確認できる経路、`定義のみ` は `terraform apply` でリソースは残るが、パケット到達や AZ 配置は再現しない経路。

| 経路 | 送信元 | 宛先 | 内容 | 制御 | LocalStack |
| --- | --- | --- | --- | --- | --- |
| 受付 | クライアント | API Gateway | HTTPS POST /uploads | 公開エンドポイント | 実行できる |
| 起動 | API Gateway | Lambda 受付 | lambda:InvokeFunction | Lambda のリソースポリシー | 実行できる |
| 保存 | Lambda 受付 | S3 incoming/ | s3:PutObject | IAM ロール | 実行できる |
| 記録 | Lambda 受付 | CloudWatch Logs | logs:PutLogEvents | IAM ロール | 実行できる |
| 通知 | S3 | SQS incoming-objects | s3:ObjectCreated:* | キューポリシー（s3.amazonaws.com） | 実行できる |
| 配送 | SQS | Lambda 処理 | event source mapping | IAM ロール | 実行できる |
| 参照 | Lambda 処理 | S3 incoming/ | s3:GetObject | IAM ロール | 実行できる |
| 記録 | Lambda 処理 | CloudWatch Logs | logs:PutLogEvents | IAM ロール | 実行できる |
| 失敗 | SQS | SQS DLQ | maxReceiveCount 3 | redrive policy | 実行できる |
| 配置 | Lambda 処理 | private subnet 1a / 1c | ENI を 2 つの AZ に配置 | VPC 設定 | 定義のみ |
| 到達 | Lambda の SG | SQS / Logs の VPC endpoint | TCP 443 | セキュリティグループ | 定義のみ |
| 到達 | private ルートテーブル | S3 gateway endpoint | S3 の prefix list | ルート | 定義のみ |

## VPC

処理 Lambda の配置先として作る。LocalStack ではオブジェクトとして残り、サブネットの中でパケットが流れるところまでは再現しない。

| リソース | 値 | 置くもの |
| --- | --- | --- |
| VPC | 10.0.0.0/16 | 全体 |
| public subnet | 10.0.0.0/24、10.0.1.0/24 | 1a と 1c。ワークロードは置かない |
| private subnet | 10.0.10.0/24、10.0.11.0/24 | 1a と 1c。処理 Lambda |
| ルート | public は IGW、private は S3 gateway endpoint | NAT は作らない |
| セキュリティグループ | Lambda 用と interface endpoint 用 | endpoint への TCP 443 |
| VPC endpoint | S3 gateway、SQS、CloudWatch Logs | 処理 Lambda の出口 |

## Terraform の置き場所

| パス | 持たせるもの |
| --- | --- |
| modules/vpc | VPC 10.0.0.0/16、public / private を 1a と 1c、IGW、ルート、Lambda 用 SG、endpoint 用 SG、S3 gateway endpoint、SQS と Logs の interface endpoint |
| modules/s3 | バケット、パブリックアクセスブロック、incoming/ への ObjectCreated 通知 |
| modules/sqs | incoming-objects、DLQ、S3 からの sqs:SendMessage を許すキューポリシー |
| modules/upload-api | REST API、POST /uploads、受付 Lambda、ロググループ /aws/lambda/request-upload |
| modules/upload-worker | 処理 Lambda、SQS の event source mapping、ロググループ、private subnet への VPC 接続 |
| environments/dev | 上記を接続する。AWS プロバイダの endpoint は http://localhost:4566 |

`modules/ec2` と `modules/ecs` は空のまま残す。`environments/prod` も今回は作らない。

## LocalStack Hobby での確認範囲

セキュリティグループは通信を止めない。Lambda は private subnet の ENI としては動かない。コンテナを止めるとリソースは消える。EC2、ALB、RDS、ECS はこの構成に入れない。
