import { GetObjectCommand, S3Client } from "@aws-sdk/client-s3";

const s3 = new S3Client({
  endpoint: process.env.AWS_ENDPOINT_URL,
  forcePathStyle: true,
  region: process.env.AWS_REGION ?? "ap-northeast-1",
});

type SqsEvent = {
  Records?: Array<{ body: string }>;
};

type S3Message = {
  Event?: string;
  Records?: Array<{
    s3: {
      bucket: { name: string };
      object: { key: string };
    };
  }>;
};

export const handler = async (event: SqsEvent) => {
  for (const record of event.Records ?? []) {
    const body = JSON.parse(record.body) as S3Message;
    if (body.Event === "s3:TestEvent") {
      console.log(JSON.stringify({ message: "ignored s3 test event" }));
      continue;
    }

    for (const item of body.Records ?? []) {
      const bucket = item.s3.bucket.name;
      const key = decodeURIComponent(item.s3.object.key.replaceAll("+", " "));
      const response = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
      if (!response.Body) {
        throw new Error(`empty object: ${bucket}/${key}`);
      }
      const payload = Buffer.from(await response.Body.transformToByteArray());
      console.log(JSON.stringify({
        message: "processed",
        bucket,
        key,
        bytes: payload.length,
      }));
    }
  }
};
