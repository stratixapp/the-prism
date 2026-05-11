/**
 * The Prism — Cloudflare Worker API
 * Built with Hono framework
 * All agent orchestration, file parsing, and AI calls happen here.
 * API keys are stored as Cloudflare Secrets — never in the Flutter app.
 */

import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';

import { analyzeRoute } from './routes/analyze';
import { uploadRoute } from './routes/upload';
import { historyRoute } from './routes/history';
import { exportRoute } from './routes/export';
import { debateRoute } from './routes/debate';
import { agentsRoute } from './agents/agentPersonaManager';
import { verifyFirebaseToken } from './middleware/auth';
import { rateLimiter } from './middleware/rateLimiter';

export interface Env {
  // Cloudflare Secrets (set via `wrangler secret put`)
  ANTHROPIC_API_KEY: string;
  OPENAI_API_KEY: string;
  FIREBASE_PROJECT_ID: string;
  FIREBASE_SERVICE_ACCOUNT_JSON: string;

  // Cloudflare R2 Bucket
  PRISM_FILES: R2Bucket;

  // Cloudflare KV (rate limiting + agent persona cache)
  PRISM_KV: KVNamespace;

  // Environment
  ENVIRONMENT: 'development' | 'staging' | 'production';
}

const app = new Hono<{ Bindings: Env }>();

// ── Global Middleware ──────────────────────────────────────────────────────────
app.use('*', logger());
app.use('*', cors({
  origin: ['*'], // Restrict to your app domain in production
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
  exposeHeaders: ['X-Request-Id'],
}));

// ── Health Check ───────────────────────────────────────────────────────────────
app.get('/health', (c) => c.json({
  status: 'ok',
  service: 'The Prism API',
  version: '1.0.0',
  timestamp: new Date().toISOString(),
}));

// ── Protected Routes (require Firebase JWT) ────────────────────────────────────
app.use('/api/*', verifyFirebaseToken);
app.use('/api/*', rateLimiter);

app.route('/api/upload', uploadRoute);
app.route('/api/analyze', analyzeRoute);
app.route('/api/history', historyRoute);
app.route('/api/export', exportRoute);
app.route('/api/debate', debateRoute);
app.route('/api/agents', agentsRoute);

// ── 404 Handler ────────────────────────────────────────────────────────────────
app.notFound((c) => c.json({ error: 'Route not found' }, 404));

// ── Error Handler ──────────────────────────────────────────────────────────────
app.onError((err, c) => {
  console.error('Unhandled error:', err);
  return c.json({
    error: 'Internal server error',
    message: c.env.ENVIRONMENT === 'development' ? err.message : undefined,
  }, 500);
});

export default app;
