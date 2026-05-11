/**
 * middleware/auth.ts
 * Verifies Firebase JWT tokens on every protected API request.
 * The Flutter app sends its Firebase ID token in the Authorization header.
 */

import { Context, Next } from 'hono';
import { Env } from '../index';

interface FirebaseTokenPayload {
  iss: string;
  aud: string;
  auth_time: number;
  user_id: string;
  sub: string;
  iat: number;
  exp: number;
  email?: string;
  email_verified?: boolean;
  firebase: {
    identities: Record<string, unknown>;
    sign_in_provider: string;
  };
}

// Cache public keys to avoid fetching on every request
let cachedKeys: Record<string, CryptoKey> = {};
let keysExpiry = 0;

async function getFirebasePublicKeys(): Promise<Record<string, CryptoKey>> {
  const now = Date.now();
  if (now < keysExpiry && Object.keys(cachedKeys).length > 0) {
    return cachedKeys;
  }

  const response = await fetch(
    'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com'
  );

  // Parse cache-control for expiry
  const cacheControl = response.headers.get('cache-control') || '';
  const maxAgeMatch = cacheControl.match(/max-age=(\d+)/);
  const maxAge = maxAgeMatch ? parseInt(maxAgeMatch[1]) * 1000 : 3600000;
  keysExpiry = now + maxAge;

  const pemKeys: Record<string, string> = await response.json();
  const cryptoKeys: Record<string, CryptoKey> = {};

  for (const [kid, pem] of Object.entries(pemKeys)) {
    // Convert PEM to DER
    const pemBody = pem
      .replace(/-----BEGIN CERTIFICATE-----/g, '')
      .replace(/-----END CERTIFICATE-----/g, '')
      .replace(/\s/g, '');
    const der = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

    // Import as certificate (SubjectPublicKeyInfo)
    cryptoKeys[kid] = await crypto.subtle.importKey(
      'spki',
      der,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['verify']
    );
  }

  cachedKeys = cryptoKeys;
  return cryptoKeys;
}

function base64UrlDecode(str: string): Uint8Array {
  const base64 = str.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(base64.length + (4 - (base64.length % 4)) % 4, '=');
  return Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
}

export async function verifyFirebaseToken(
  c: Context<{ Bindings: Env }>,
  next: Next
): Promise<Response | void> {
  const authorization = c.req.header('Authorization');

  if (!authorization || !authorization.startsWith('Bearer ')) {
    return c.json({ error: 'Missing or invalid Authorization header' }, 401);
  }

  const token = authorization.slice(7);

  try {
    // Split JWT
    const parts = token.split('.');
    if (parts.length !== 3) throw new Error('Invalid JWT structure');

    const [headerB64, payloadB64, signatureB64] = parts;

    // Decode header to get kid
    const header = JSON.parse(
      new TextDecoder().decode(base64UrlDecode(headerB64))
    );

    if (header.alg !== 'RS256') throw new Error('Invalid algorithm');

    // Get public keys
    const keys = await getFirebasePublicKeys();
    const publicKey = keys[header.kid];
    if (!publicKey) throw new Error('Unknown key ID');

    // Verify signature
    const data = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
    const signature = base64UrlDecode(signatureB64);

    const isValid = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      publicKey,
      signature,
      data
    );

    if (!isValid) throw new Error('Invalid signature');

    // Decode and validate payload
    const payload: FirebaseTokenPayload = JSON.parse(
      new TextDecoder().decode(base64UrlDecode(payloadB64))
    );

    const now = Math.floor(Date.now() / 1000);

    if (payload.exp < now) throw new Error('Token expired');
    if (payload.iat > now + 300) throw new Error('Token issued in the future');
    if (payload.aud !== c.env.FIREBASE_PROJECT_ID) throw new Error('Invalid audience');
    if (payload.iss !== `https://securetoken.google.com/${c.env.FIREBASE_PROJECT_ID}`) {
      throw new Error('Invalid issuer');
    }

    // Attach user to context
    c.set('userId' as never, payload.user_id);
    c.set('userEmail' as never, payload.email || '');

    await next();
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Token verification failed';
    console.error('Auth error:', message);
    return c.json({ error: 'Unauthorized', detail: message }, 401);
  }
}
