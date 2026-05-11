/**
 * routes/history.ts
 * Returns paginated analysis history for the authenticated user.
 * Data lives in Firestore — this route proxies it via the Worker.
 */

import { Hono } from 'hono';
import { Env } from '../index';

export const historyRoute = new Hono<{ Bindings: Env }>();

// GET /api/history?limit=20&cursor=<lastDocId>
historyRoute.get('/', async (c) => {
  const userId = (c as unknown as { get: (k: string) => string }).get('userId');
  const limit = Math.min(parseInt(c.req.query('limit') || '20'), 50);
  const cursor = c.req.query('cursor');

  // Build Firestore REST API URL
  const projectId = c.env.FIREBASE_PROJECT_ID;
  const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

  // Query analyses for this user, ordered by createdAt descending
  const queryBody = {
    structuredQuery: {
      from: [{ collectionId: 'analyses' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'userId' },
          op: 'EQUAL',
          value: { stringValue: userId },
        },
      },
      orderBy: [{ field: { fieldPath: 'createdAt' }, direction: 'DESCENDING' }],
      limit: limit,
      ...(cursor ? { startAfter: { values: [{ stringValue: cursor }] } } : {}),
    },
  };

  const serviceAccount = JSON.parse(c.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  const accessToken = await getFirebaseAccessToken(serviceAccount);

  const response = await fetch(`${baseUrl}:runQuery`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(queryBody),
  });

  if (!response.ok) {
    return c.json({ error: 'Failed to fetch history' }, 500);
  }

  const data: unknown[] = await response.json();
  const analyses = (data as Array<{ document?: unknown }>)
    .filter((item) => item.document)
    .map((item) => item.document);

  return c.json({ analyses, count: analyses.length });
});

// ── Firebase Access Token (Service Account JWT) ───────────────────────────────
async function getFirebaseAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/datastore',
  };

  // Create JWT
  const header = { alg: 'RS256', typ: 'JWT' };
  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  const signingInput = `${encode(header)}.${encode(payload)}`;

  // Import private key
  const pkcs8 = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');

  const keyBuffer = Uint8Array.from(atob(pkcs8), (c) => c.charCodeAt(0));

  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBuffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    new TextEncoder().encode(signingInput)
  );

  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  const jwt = `${signingInput}.${signatureB64}`;

  // Exchange for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData: { access_token: string } = await tokenResponse.json();
  return tokenData.access_token;
}
