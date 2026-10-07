# 1. dev はファイル受付パイプラインにする

日付: 2026-10-07

状態: 採用

## 背景

このリポジトリは LocalStack Hobby で、Terraform の定義と通信要件を残す練習場である。最初の案は Multi-AZ の EC2、ロードバランサー、RDS だった。Hobby では EC2 インスタンスの起動、ALB、RDS、ECS が使えず、セキュリティグループの到達確認もできない。

S3、SQS、API Gateway、Lambda、CloudWatch Logs、それに VPC とサブネットとセキュリティグループの定義は Hobby で扱える。S3 にオブジェクトを置いたイベントを SQS へ届けるところまで実行できる。

## 決定

dev の最初の構成は、API Gateway、受付 Lambda、S3、SQS、処理 Lambda、CloudWatch Logs、VPC とする。

- アップロードは受付 Lambda が S3 の `incoming/` へ直接書く。
- 処理 Lambda だけを private subnet（1a と 1c）に置く。出口は S3 gateway endpoint と、SQS および CloudWatch Logs の interface endpoint とする。
- EC2、ALB、RDS、ECS は作らない。`modules/ec2` と `modules/ecs` は空のまま残す。
- 通信要件とリソースの一覧は [docs/dev-upload-pipeline.md](../dev-upload-pipeline.md) に書き、構成が変わったらそこを更新する。

## 結果

`curl` で `POST /uploads` を叩き、S3 のオブジェクト、SQS のイベント、処理 Lambda のログまで確認できる。VPC、サブネット、セキュリティグループ、VPC endpoint は apply されるが、パケットの到達と AZ への実配置は確認対象外になる。Hobby ではコンテナ停止時にリソースが消える。
