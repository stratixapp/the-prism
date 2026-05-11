/**
 * middleware/rateLimiter.ts
 * Enforces per-user quota:
 *   Free tier  → 3 analyses / calendar month
 *   Pro / Team → unlimited
 * Uses Cloudflare KV for lightweight counters.
 */

import { Context, Next } from 'hono';
import { Env } from '../index';

const FREE_MONTHLY_LIMIT = 3;

function monthKey(userId: string): string {
  const now = new Date();
  return `quota:${userId}:${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

export async function rateLimiter(
  c: Context<{ Bindings: Env }>,
  next: Next
): Promise<Response | void> {
  // Only apply quota to /analyze POST requests
  if (!(c.req.method === 'POST' && c.req.path.startsWith('/api/analyze'))) {
    return next();
  }

  const userId = (c as unknown as { get: (k: string) => string }).get('userId');
  if (!userId) return c.json({ error: 'Unauthorized' }, 401);

  // Check user plan from KV cache (set by Firestore webhook or analysis completion)
  const planKey = `plan:${userId}`;
  const plan = await c.env.PRISM_KV.get(planKey) || 'free';

  // Pro / Team — unlimited
  if (plan === 'pro' || plan === 'team') {
    return next();
  }

  // Free tier — enforce monthly limit
  const key = monthKey(userId);
  const countStr = await c.env.PRISM_KV.get(key);
  const count = countStr ? parseInt(countStr, 10) : 0;

  if (count >= FREE_MONTHLY_LIMIT) {
    return c.json(
      {
        error: 'quota_exceeded',
        message: `Free tier allows ${FREE_MONTHLY_LIMIT} analyses per month. Upgrade to Pro for unlimited access.`,
        used: count,
        limit: FREE_MONTHLY_LIMIT,
        upgradeUrl: 'https://theprism.app/upgrade',
      },
      429
    );
  }

  // Increment counter (TTL: 35 days — safely covers a full month)
  await c.env.PRISM_KV.put(key, String(count + 1), {
    expirationTtl: 35 * 24 * 60 * 60,
  });

  // Attach remaining count to context for response headers
  c.header('X-Quota-Used', String(count + 1));
  c.header('X-Quota-Limit', String(FREE_MONTHLY_LIMIT));
  c.header('X-Quota-Remaining', String(FREE_MONTHLY_LIMIT - count - 1));

  return next();
}
