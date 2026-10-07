import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { randomUUID } from "node:crypto";
import path from "node:path";

const s3 = new S3Client({
  endpoint: process.env.AWS_ENDPOINT_URL,
  forcePathStyle: true,
  region: process.env.AWS_REGION ?? "ap-northeast-1",
});

type ApiEvent = {
  headers?: Record<string, string | undefined>;
  body?: string | null;
  isBase64Encoded?: boolean;
};

export const handler = async (event: ApiEvent) => {
  const headers = Object.fromEntries(
    Object.entries(event.headers ?? {}).map(([key, value]) => [key.toLowerCase(), value ?? ""]),
  );
  const filename = path.posix.basename((headers["x-filename"] ?? "").replaceAll("\\", "/")) || randomUUID();
  const data = event.isBase64Encoded
    ? Buffer.from(event.body ?? "", "base64")
    : Buffer.from(event.body ?? "", "utf8");

  const bucket = process.env.BUCKET_NAME;
  if (!bucket) {
    throw new Error("BUCKET_NAME is not set");
  }

  const key = `incoming/${randomUUID()}-${filename}`;
  await s3.send(new PutObjectCommand({ Bucket: bucket, Key: key, Body: data }));

  console.log(JSON.stringify({ message: "stored", bucket, key, bytes: data.length }));
  return {
    statusCode: 201,
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ bucket, key, bytes: data.length }),
  };
};
