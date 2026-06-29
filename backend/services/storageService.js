/**
 * Storage Service — Cloudflare R2 via AWS SDK v3
 * Handles uploading/deleting files to/from Cloudflare R2.
 */

const { S3Client, PutObjectCommand, DeleteObjectCommand, DeleteObjectsCommand } = require('@aws-sdk/client-s3');

const s3 = new S3Client({
  endpoint: process.env.CLOUDFLARE_R2_ENDPOINT,
  region: 'auto',
  credentials: {
    accessKeyId: process.env.CLOUDFLARE_R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.CLOUDFLARE_R2_SECRET_ACCESS_KEY,
  },
});

/**
 * Upload a file buffer to R2.
 * @param {Buffer} buffer - File bytes.
 * @param {string} key - R2 object key (path inside bucket).
 * @param {string} contentType - MIME type.
 * @returns {Promise<string>} Public URL of the uploaded file.
 */
async function uploadFile(buffer, key, contentType) {
  const command = new PutObjectCommand({
    Bucket: process.env.CLOUDFLARE_R2_BUCKET_NAME,
    Key: key,
    Body: buffer,
    ContentType: contentType,
  });

  await s3.send(command);
  const url = `${process.env.CLOUDFLARE_R2_PUBLIC_URL}/${key}`;
  console.log(`[Storage] Uploaded: ${url} (${buffer.length} bytes)`);
  return url;
}

/**
 * Delete a single file from R2.
 * @param {string} key - R2 object key.
 */
async function deleteFile(key) {
  const command = new DeleteObjectCommand({
    Bucket: process.env.CLOUDFLARE_R2_BUCKET_NAME,
    Key: key,
  });
  await s3.send(command);
  console.log(`[Storage] Deleted: ${key}`);
}

/**
 * Delete multiple files from R2 in one batch request.
 * @param {string[]} keys - Array of R2 object keys.
 */
async function deleteFiles(keys) {
  if (!keys || keys.length === 0) return;

  const command = new DeleteObjectsCommand({
    Bucket: process.env.CLOUDFLARE_R2_BUCKET_NAME,
    Delete: {
      Objects: keys.map((k) => ({ Key: k })),
    },
  });
  await s3.send(command);
  console.log(`[Storage] Deleted batch of ${keys.length} files.`);
}

/**
 * Get the public URL for a given key without uploading.
 * @param {string} key
 * @returns {string}
 */
function getPublicUrl(key) {
  return `${process.env.CLOUDFLARE_R2_PUBLIC_URL}/${key}`;
}

module.exports = { uploadFile, deleteFile, deleteFiles, getPublicUrl };
