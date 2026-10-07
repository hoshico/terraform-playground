# terraform-playground

LocalStack の無料プラン（Hobby）で、dev 環境のファイル受付パイプラインを Terraform で作る。

設計と通信要件は [docs/dev-upload-pipeline.md](docs/dev-upload-pipeline.md)、この構成にした理由は [docs/adr/0001-upload-pipeline.md](docs/adr/0001-upload-pipeline.md) に置く。図は後から `docs/diagrams/dev-upload-pipeline.drawio` に追加する。

## 動かし方

受付 Lambda と処理 Lambda は TypeScript で書き、apply の前に JavaScript へビルドして Node.js 20 で動かす。Node.js が必要。

LocalStack Hobby を `localhost:4566` で起動してから、`environments/dev` で `terraform init` と `terraform apply` する。初回の plan / apply で依存のインストールとビルドも走る。

受付 URL は output の `upload_url`。ファイルは `application/octet-stream` で渡す。

```bash
curl -sS -X POST "$UPLOAD_URL" \
  -H 'content-type: application/octet-stream' \
  -H 'x-filename: hello.txt' \
  --data-binary @hello.txt
```

受付 Lambda のログは `/aws/lambda/request-upload`、処理 Lambda のログは `/aws/lambda/process-upload`。
