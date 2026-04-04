import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getEnv } from '../config/env.js';

let _s3Client: S3Client | null = null;

function getS3Client(): S3Client {
  if (!_s3Client) {
    const env = getEnv();
    _s3Client = new S3Client({
      region: 'auto',
      endpoint: env.R2_ENDPOINT,
      credentials: {
        accessKeyId: env.R2_ACCESS_KEY,
        secretAccessKey: env.R2_SECRET_KEY,
      },
    });
  }
  return _s3Client;
}

export async function uploadFile(
  key: string,
  body: Buffer,
  contentType: string,
): Promise<string> {
  const env = getEnv();
  await getS3Client().send(
    new PutObjectCommand({
      Bucket: env.R2_BUCKET,
      Key: key,
      Body: body,
      ContentType: contentType,
    }),
  );
  return `${env.R2_ENDPOINT}/${env.R2_BUCKET}/${key}`;
}

export async function getFile(key: string): Promise<Buffer | null> {
  const env = getEnv();
  try {
    const response = await getS3Client().send(
      new GetObjectCommand({ Bucket: env.R2_BUCKET, Key: key }),
    );
    const chunks: Uint8Array[] = [];
    for await (const chunk of response.Body as AsyncIterable<Uint8Array>) {
      chunks.push(chunk);
    }
    return Buffer.concat(chunks);
  } catch {
    return null;
  }
}

export async function deleteFile(key: string): Promise<void> {
  const env = getEnv();
  await getS3Client().send(
    new DeleteObjectCommand({ Bucket: env.R2_BUCKET, Key: key }),
  );
}
