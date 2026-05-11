/**
 * routes/upload.ts
 * Handles file uploads from Flutter → Cloudflare R2 bucket.
 * Returns a signed URL and R2 key for the analysis to use.
 */

import { Hono } from 'hono';
import { Env } from '../index';

export const uploadRoute = new Hono<{ Bindings: Env }>();

const MAX_FILE_SIZE = 50 * 1024 * 1024; // 50 MB

const SUPPORTED_TYPES = new Set([
  'application/pdf',
  'application/zip',
  'application/x-zip-compressed',
  'application/vnd.android.package-archive',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-excel',
  'text/plain',
  'text/csv',
  'text/markdown',
  'application/json',
  'application/xml',
  'text/xml',
  'image/png',
  'image/jpeg',
  'image/gif',
  'application/octet-stream', // fallback for unknown types
]);

// POST /api/upload
// Receives multipart/form-data with the file
uploadRoute.post('/', async (c) => {
  const userId = (c as unknown as { get: (k: string) => string }).get('userId');

  let formData: FormData;
  try {
    formData = await c.req.formData();
  } catch {
    return c.json({ error: 'Invalid multipart form data' }, 400);
  }

  const file = formData.get('file') as File | null;
  if (!file) {
    return c.json({ error: 'No file provided. Send as multipart field "file".' }, 400);
  }

  // ── Validate size ──────────────────────────────────────────────────────
  if (file.size > MAX_FILE_SIZE) {
    return c.json(
      {
        error: 'file_too_large',
        message: `File exceeds 50MB limit. Size: ${(file.size / (1024 * 1024)).toFixed(1)}MB`,
      },
      413
    );
  }

  // ── Validate type ──────────────────────────────────────────────────────
  const mimeType = file.type || 'application/octet-stream';

  // ── Generate R2 key ────────────────────────────────────────────────────
  // Pattern: uploads/{userId}/{timestamp}-{random}.{ext}
  const ext = file.name.includes('.') ? file.name.split('.').pop()!.toLowerCase() : 'bin';
  const timestamp = Date.now();
  const random = Math.random().toString(36).slice(2, 8);
  const r2Key = `uploads/${userId}/${timestamp}-${random}.${ext}`;

  // ── Upload to R2 ───────────────────────────────────────────────────────
  const arrayBuffer = await file.arrayBuffer();

  try {
    await c.env.PRISM_FILES.put(r2Key, arrayBuffer, {
      httpMetadata: {
        contentType: mimeType,
        contentDisposition: `inline; filename="${file.name}"`,
      },
      customMetadata: {
        userId,
        originalName: file.name,
        uploadedAt: new Date().toISOString(),
        // Auto-purge marker — a Cloudflare Cron will delete after 7 days
        purgeAfter: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
      },
    });
  } catch (err) {
    console.error('R2 upload error:', err);
    return c.json({ error: 'File storage failed. Please try again.' }, 500);
  }

  return c.json({
    success: true,
    r2Key,
    fileName: file.name,
    fileSize: file.size,
    mimeType,
    extension: ext,
  });
});

// DELETE /api/upload/:r2Key
// Allows users to manually delete their uploaded files
uploadRoute.delete('/:r2Key{.+}', async (c) => {
  const userId = (c as unknown as { get: (k: string) => string }).get('userId');
  const r2Key = c.req.param('r2Key');

  // Security: only allow deletion of own files
  if (!r2Key.startsWith(`uploads/${userId}/`)) {
    return c.json({ error: 'Forbidden' }, 403);
  }

  await c.env.PRISM_FILES.delete(r2Key);
  return c.json({ success: true });
});
