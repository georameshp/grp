import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

/**
 * Cloudflare R2 presigning (local SigV4 — no network, Spark-safe).
 * Credentials come from plain env vars:
 * - emulator: `functions/.env` (gitignored)
 * - deployed: `.env.globalrp-df55a` style dotenv files also deploy, but on
 *   the no-card plan production uploads go through the Worker instead
 *   (workers/grp), which holds the keys in free Worker secrets.
 */

const ALLOWED_MIME = /^(image\/.*|application\/pdf|video\/.*|audio\/.*)$/;

function env(name: string): string {
  return (process.env[name] ?? '').trim();
}

export function r2Configured(): boolean {
  return Boolean(
    env('R2_ACCOUNT_ID') &&
      env('R2_ACCESS_KEY_ID') &&
      env('R2_SECRET_ACCESS_KEY') &&
      env('R2_BUCKET') &&
      env('R2_PUBLIC_URL'),
  );
}

function client(): S3Client {
  return new S3Client({
    region: 'auto',
    endpoint: `https://${env('R2_ACCOUNT_ID')}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: env('R2_ACCESS_KEY_ID'),
      secretAccessKey: env('R2_SECRET_ACCESS_KEY'),
    },
  });
}

export function sanitizeFilename(name: string): string {
  return name
    .split('/')
    .pop()!
    .replace(/[^a-zA-Z0-9._-]+/g, '_')
    .slice(0, 120);
}

export interface PresignResult {
  uploadUrl: string;
  publicUrl: string;
  key: string;
}

/**
 * Creates a 5-minute presigned PUT URL. Pure local SigV4 signing —
 * no outbound network call, so it works on the Firebase Spark (free) plan.
 */
export async function presignPut(
  key: string,
  contentType: string,
): Promise<PresignResult> {
  if (!ALLOWED_MIME.test(contentType)) {
    throw new Error(`Unsupported file type: ${contentType}`);
  }
  const bucket = env('R2_BUCKET');
  const url = await getSignedUrl(
    client(),
    new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      ContentType: contentType,
    }),
    { expiresIn: 300 },
  );
  const base = env('R2_PUBLIC_URL').replace(/\/$/, '');
  return { uploadUrl: url, publicUrl: `${base}/${key}`, key };
}
