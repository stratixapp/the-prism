/**
 * routes/debate.ts
 * Phase 18 backend — Agent Debate Mode
 *
 * Receives: agentAId, agentBId, topic, fileContext
 * Runs 4 debate stages × 2 agents, streaming via SSE.
 * Stages: opening → arguments → rebuttal → closing
 */

import { Hono } from 'hono';
import { Env } from '../index';
import { AGENT_PERSONAS } from '../agents/agentPersonas';

export const debateRoute = new Hono<{ Bindings: Env }>();

const STAGES = ['opening', 'arguments', 'rebuttal', 'closing'] as const;
type Stage = typeof STAGES[number];

const STAGE_INSTRUCTIONS: Record<Stage, string> = {
  opening:
    'Give your opening position on this topic in 2-3 sentences. '
    + 'State your core argument clearly and boldly. No hedging.',
  arguments:
    'Present your 3 strongest arguments supporting your position. '
    + 'Each argument should be specific and grounded in the file context provided.',
  rebuttal:
    'Rebut the opposing position. Identify the weakest point in the other side\'s '
    + 'likely argument and dismantle it with specific evidence.',
  closing:
    'Give your closing statement in 2-3 sentences. '
    + 'Summarize why your position is correct and what the key takeaway is.',
};

debateRoute.post('/', async (c) => {
  const userId = (c as unknown as { get: (k: string) => string }).get('userId');

  const body = await c.req.json<{
    agentAId: string;
    agentBId: string;
    topic: string;
    fileContext: string;
    analysisId: string;
  }>();

  const { agentAId, agentBId, topic, fileContext } = body;

  if (!agentAId || !agentBId || !topic) {
    return c.json({ error: 'agentAId, agentBId, and topic are required' }, 400);
  }

  const personaA = AGENT_PERSONAS[agentAId];
  const personaB = AGENT_PERSONAS[agentBId];

  if (!personaA || !personaB) {
    return c.json({ error: 'Invalid agent IDs' }, 400);
  }

  const { readable, writable } = new TransformStream();
  const writer = writable.getWriter();
  const encoder = new TextEncoder();

  const send = async (event: string, data: unknown) => {
    const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
    await writer.write(encoder.encode(payload));
  };

  const runDebate = async () => {
    try {
      for (const stage of STAGES) {
        await send('stage_start', { stage });

        const stageInstruction = STAGE_INSTRUCTIONS[stage];

        // Build prompts for both agents
        const buildPrompt = (agentId: string, side: 'FOR' | 'AGAINST') =>
          `You are arguing ${side} the following topic based on the file context provided.

TOPIC: ${topic}
YOUR SIDE: ${side}
FILE CONTEXT: ${fileContext}

STAGE INSTRUCTION: ${stageInstruction}

Stay in character as your expert persona. Be decisive and specific.`;

        // Run both agents in parallel for this stage
        await Promise.all([
          streamDebateAgent(
            c.env.ANTHROPIC_API_KEY,
            agentAId,
            personaA,
            buildPrompt(agentAId, 'FOR'),
            stage,
            send
          ),
          streamDebateAgent(
            c.env.ANTHROPIC_API_KEY,
            agentBId,
            personaB,
            buildPrompt(agentBId, 'AGAINST'),
            stage,
            send
          ),
        ]);

        await send('stage_complete', { stage });
      }

      await send('debate_complete', { topic, agentAId, agentBId });
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Debate failed';
      await send('error', { message: msg });
    } finally {
      await writer.close();
    }
  };

  c.executionCtx.waitUntil(runDebate());

  return new Response(readable, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  });
});

async function streamDebateAgent(
  apiKey: string,
  agentId: string,
  systemPrompt: string,
  userMessage: string,
  stage: Stage,
  send: (event: string, data: unknown) => Promise<void>
): Promise<void> {
  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 400,
      stream: true,
      system: systemPrompt,
      messages: [{ role: 'user', content: userMessage }],
    }),
  });

  if (!response.ok) throw new Error(`Claude ${response.status}`);

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();
  let fullText = '';
  let buffer = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';

    for (const line of lines) {
      if (!line.startsWith('data: ')) continue;
      const raw = line.slice(6).trim();
      if (!raw || raw === '[DONE]') continue;
      try {
        const evt = JSON.parse(raw);
        if (evt.type === 'content_block_delta' && evt.delta?.text) {
          fullText += evt.delta.text;
          await send('token', {
            agentId,
            token: evt.delta.text,
            stage,
          });
        }
      } catch { /* skip */ }
    }
  }

  await send('stage_agent_complete', { agentId, stage, fullText });
}
