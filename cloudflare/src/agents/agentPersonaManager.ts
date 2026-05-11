/**
 * agents/agentPersonaManager.ts
 * Phase 7 — Agent Persona Library
 *
 * Responsibilities:
 *  - Serves the authoritative 10 agent system prompts
 *  - Caches personas in Cloudflare KV so they can be updated without redeployment
 *  - Supports per-user custom agents (Pro feature — Phase 19)
 *  - Validates persona structure before use
 *  - Tracks persona version for A/B testing and rollback
 *
 * KV Schema:
 *  persona:v:{version}:{agentId}     → system prompt string
 *  persona:active_version            → current version string (e.g. "v2")
 *  persona:custom:{userId}:{agentId} → custom agent system prompt
 */

import { AGENT_PERSONAS } from './agentPersonas';

// ── Persona Version ───────────────────────────────────────────────────────────
export const PERSONA_VERSION = 'v1';

// ── Persona Metadata ──────────────────────────────────────────────────────────
// Rich metadata about each agent — used by Flutter UI and analytics
export interface AgentMeta {
  id: string;
  name: string;
  role: string;
  initials: string;
  colorHex: string;       // Agent spectrum color
  bgColorHex: string;     // Dark background tint
  shortDesc: string;
  outputFocus: string[];  // What this agent produces
  isProOnly: boolean;
  version: string;
}

export const AGENT_META: Record<string, AgentMeta> = {
  priya: {
    id: 'priya',
    name: 'Dr. Priya',
    role: 'Deep Research Analyst',
    initials: 'DR',
    colorHex: '#7F77DD',
    bgColorHex: '#1A1830',
    shortDesc: 'Core themes, methodology, factual foundations',
    outputFocus: ['thesis', 'evidence', 'methodology', 'credibility'],
    isProOnly: false,
    version: PERSONA_VERSION,
  },
  marcus: {
    id: 'marcus',
    name: 'Marcus',
    role: 'Gap & Blind-Spot Finder',
    initials: 'MA',
    colorHex: '#1D9E75',
    bgColorHex: '#0D2420',
    shortDesc: 'What is missing, overlooked, and unanswered',
    outputFocus: ['gaps', 'blind spots', 'missing data', 'assumptions'],
    isProOnly: false,
    version: PERSONA_VERSION,
  },
  zara: {
    id: 'zara',
    name: 'Zara',
    role: 'Future Strategist',
    initials: 'ZA',
    colorHex: '#BA7517',
    bgColorHex: '#251A0A',
    shortDesc: 'Future opportunities, trends, predictions',
    outputFocus: ['opportunities', 'trends', 'scenarios', 'timing'],
    isProOnly: false,
    version: PERSONA_VERSION,
  },
  leon: {
    id: 'leon',
    name: 'Leon',
    role: 'Risk Evaluator',
    initials: 'LE',
    colorHex: '#D85A30',
    bgColorHex: '#251208',
    shortDesc: 'Risks, threats, weaknesses, vulnerabilities',
    outputFocus: ['risks', 'threats', 'mitigations', 'severity'],
    isProOnly: false,
    version: PERSONA_VERSION,
  },
  aiko: {
    id: 'aiko',
    name: 'Aiko',
    role: 'Pattern & Anomaly Reader',
    initials: 'AI',
    colorHex: '#378ADD',
    bgColorHex: '#0C1E30',
    shortDesc: 'Hidden patterns, anomalies, structural insights',
    outputFocus: ['patterns', 'anomalies', 'structure', 'contradictions'],
    isProOnly: false,
    version: PERSONA_VERSION,
  },
  sofia: {
    id: 'sofia',
    name: 'Sofia',
    role: 'Innovation Scout',
    initials: 'SO',
    colorHex: '#D4537E',
    bgColorHex: '#2A101C',
    shortDesc: 'Innovation opportunities, new products and services',
    outputFocus: ['products', 'services', 'markets', 'platforms'],
    isProOnly: true,
    version: PERSONA_VERSION,
  },
  ravi: {
    id: 'ravi',
    name: 'Ravi',
    role: 'Domain & Industry Expert',
    initials: 'RA',
    colorHex: '#639922',
    bgColorHex: '#131F06',
    shortDesc: 'Industry benchmarks, domain best practices',
    outputFocus: ['benchmarks', 'standards', 'best practices', 'comparisons'],
    isProOnly: true,
    version: PERSONA_VERSION,
  },
  vex: {
    id: 'vex',
    name: 'Vex',
    role: 'Competitor Intelligence',
    initials: 'VX',
    colorHex: '#E24B4A',
    bgColorHex: '#2A0C0C',
    shortDesc: 'Competitive landscape, market positioning',
    outputFocus: ['competitors', 'positioning', 'moats', 'threats'],
    isProOnly: true,
    version: PERSONA_VERSION,
  },
  morgan: {
    id: 'morgan',
    name: 'Morgan',
    role: 'Monetisation Architect',
    initials: 'MO',
    colorHex: '#888780',
    bgColorHex: '#1C1C1C',
    shortDesc: 'Revenue models, pricing, monetisation strategy',
    outputFocus: ['revenue streams', 'pricing', 'upsells', 'value capture'],
    isProOnly: true,
    version: PERSONA_VERSION,
  },
  chen: {
    id: 'chen',
    name: 'Chen',
    role: 'Master Synthesizer',
    initials: 'CH',
    colorHex: '#3C3489',
    bgColorHex: '#130F2A',
    shortDesc: 'Final verdict — #1 insight, gap, opportunity',
    outputFocus: ['synthesis', 'verdict', 'top insight', 'top opportunity'],
    isProOnly: false,
    version: PERSONA_VERSION,
  },
};

// ── Canonical agent order (free tier gets first 3, pro gets all 10) ───────────
export const AGENT_ORDER = [
  'priya', 'marcus', 'zara',           // Free tier
  'leon', 'aiko', 'sofia',             // Pro
  'ravi', 'vex', 'morgan',             // Pro
  'chen',                               // Always last (synthesizer)
];

export const FREE_AGENT_IDS = ['priya', 'marcus', 'zara', 'chen'];
export const PRO_AGENT_IDS  = AGENT_ORDER;

// ── KV-backed Persona Manager ─────────────────────────────────────────────────

export class PersonaManager {
  private kv: KVNamespace;
  private localCache: Map<string, string> = new Map();

  constructor(kv: KVNamespace) {
    this.kv = kv;
  }

  /**
   * Get system prompt for an agent.
   * Priority: KV override → built-in default
   */
  async getPersona(agentId: string): Promise<string | null> {
    // Check local in-memory cache first (per-request)
    const cacheKey = `${PERSONA_VERSION}:${agentId}`;
    if (this.localCache.has(cacheKey)) {
      return this.localCache.get(cacheKey)!;
    }

    // Try KV override (allows hot-update without redeployment)
    const kvKey = `persona:v:${PERSONA_VERSION}:${agentId}`;
    try {
      const kvPersona = await this.kv.get(kvKey);
      if (kvPersona) {
        this.localCache.set(cacheKey, kvPersona);
        return kvPersona;
      }
    } catch {
      // KV unavailable — fall through to default
    }

    // Fall back to built-in defaults
    const defaultPersona = AGENT_PERSONAS[agentId];
    if (defaultPersona) {
      this.localCache.set(cacheKey, defaultPersona);
      return defaultPersona;
    }

    return null;
  }

  /**
   * Get custom agent persona for a Pro user.
   * Custom agents are stored in KV by userId.
   */
  async getCustomPersona(userId: string, agentId: string): Promise<string | null> {
    const key = `persona:custom:${userId}:${agentId}`;
    try {
      return await this.kv.get(key);
    } catch {
      return null;
    }
  }

  /**
   * Save a custom agent persona (Pro feature — Phase 19).
   */
  async saveCustomPersona(
    userId: string,
    agentId: string,
    systemPrompt: string
  ): Promise<void> {
    this.validatePersona(systemPrompt);
    const key = `persona:custom:${userId}:${agentId}`;
    await this.kv.put(key, systemPrompt, {
      expirationTtl: 365 * 24 * 60 * 60, // 1 year
    });
  }

  /**
   * Hot-update a built-in agent persona without redeployment.
   * Used by Stratix admin for prompt tuning.
   */
  async updatePersona(agentId: string, newPrompt: string): Promise<void> {
    this.validatePersona(newPrompt);
    const key = `persona:v:${PERSONA_VERSION}:${agentId}`;
    await this.kv.put(key, newPrompt);
    // Clear local cache so next request picks up new version
    this.localCache.delete(`${PERSONA_VERSION}:${agentId}`);
  }

  /**
   * Resolve the final agent list for a given user and plan.
   * Merges built-in agents with any custom agents the user has created.
   */
  async resolveAgentList(
    userId: string,
    isPro: boolean,
    requestedAgentIds?: string[]
  ): Promise<string[]> {
    const allowedIds = isPro ? PRO_AGENT_IDS : FREE_AGENT_IDS;

    if (requestedAgentIds && requestedAgentIds.length > 0) {
      // Filter requested agents to only allowed ones, preserve order
      return requestedAgentIds.filter((id) => allowedIds.includes(id));
    }

    return allowedIds;
  }

  /**
   * Return agent metadata for the Flutter UI.
   */
  getAgentMeta(agentId: string): AgentMeta | null {
    return AGENT_META[agentId] ?? null;
  }

  getAllAgentMeta(isPro: boolean): AgentMeta[] {
    const ids = isPro ? PRO_AGENT_IDS : FREE_AGENT_IDS;
    return ids.map((id) => AGENT_META[id]).filter(Boolean);
  }

  /**
   * Basic persona validation — ensures prompt meets minimum quality bar.
   */
  private validatePersona(prompt: string): void {
    if (!prompt || typeof prompt !== 'string') {
      throw new Error('Persona must be a non-empty string');
    }
    if (prompt.length < 100) {
      throw new Error('Persona is too short (minimum 100 characters)');
    }
    if (prompt.length > 8000) {
      throw new Error('Persona exceeds maximum length of 8000 characters');
    }
  }
}

// ── API endpoint for agent metadata (GET /api/agents) ─────────────────────────
// Flutter calls this on first load to get current agent colors, names, metadata

import { Hono } from 'hono';
import { Env } from '../index';

export const agentsRoute = new Hono<{ Bindings: Env }>();

agentsRoute.get('/', async (c) => {
  const userId = (c as unknown as { get: (k: string) => string }).get('userId');

  // Determine plan from KV
  const plan = await c.env.PRISM_KV.get(`plan:${userId}`) || 'free';
  const isPro = plan === 'pro' || plan === 'team';

  const manager = new PersonaManager(c.env.PRISM_KV);
  const agents = manager.getAllAgentMeta(isPro);

  return c.json({
    agents,
    plan,
    totalAgents: agents.length,
    personaVersion: PERSONA_VERSION,
  });
});

agentsRoute.get('/meta/:agentId', async (c) => {
  const agentId = c.req.param('agentId');
  const manager = new PersonaManager(c.env.PRISM_KV);
  const meta = manager.getAgentMeta(agentId);

  if (!meta) return c.json({ error: 'Agent not found' }, 404);
  return c.json(meta);
});
