/**
 * routes/analyze.ts
 * THE CORE ENGINE — runs all 10 agents in parallel, streams results via SSE.
 * This is the heart of The Prism.
 */

import { Hono } from 'hono';
import { Env } from '../index';
import { parseFile } from '../parsers/fileParser';
import { AGENT_PERSONAS } from '../agents/agentPersonas';

export const analyzeRoute = new Hono<{ Bindings: Env }>();

export interface AnalyzeRequest {
  analysisId: string;    // Firestore document ID
  r2Key: string;         // Key in R2 bucket
  fileName: string;
  fileExtension: string;
  mimeType: string;
  focusQuestion?: string;
  aiProvider: 'claude' | 'openai' | 'both';
  agentIds: string[];    // Which agents to run (3 for free, 10 for pro)
}

// POST /api/analyze — starts analysis, returns SSE stream
analyzeRoute.post('/', async (c) => {
  const userId = (c as unknown as { get: (k: string) => string }).get('userId');

  let body: AnalyzeRequest;
  try {
    body = await c.req.json<AnalyzeRequest>();
  } catch {
    return c.json({ error: 'Invalid JSON body' }, 400);
  }

  const {
    analysisId,
    r2Key,
    fileName,
    fileExtension,
    mimeType,
    focusQuestion,
    aiProvider,
    agentIds,
  } = body;

  if (!r2Key || !analysisId) {
    return c.json({ error: 'r2Key and analysisId are required' }, 400);
  }

  // ── Fetch file from R2 ────────────────────────────────────────────────
  const r2Object = await c.env.PRISM_FILES.get(r2Key);
  if (!r2Object) {
    return c.json({ error: 'File not found. Please re-upload.' }, 404);
  }

  // Security: verify file belongs to this user
  const meta = r2Object.customMetadata || {};
  if (meta.userId !== userId) {
    return c.json({ error: 'Forbidden' }, 403);
  }

  const fileBuffer = await r2Object.arrayBuffer();

  // ── Parse file to text ────────────────────────────────────────────────
  let parseResult;
  try {
    parseResult = await parseFile(fileBuffer, fileExtension, mimeType, fileName);
  } catch (err) {
    return c.json({ error: 'Failed to parse file content' }, 422);
  }

  const fileContext = `
FILE NAME: ${fileName}
FILE TYPE: ${fileExtension.toUpperCase()}
FILE SIZE: ${(fileBuffer.byteLength / 1024).toFixed(1)} KB
${parseResult.pageCount ? `PAGES: ${parseResult.pageCount}` : ''}
${parseResult.fileCount ? `FILES INSIDE: ${parseResult.fileCount}` : ''}
${parseResult.warning ? `NOTE: ${parseResult.warning}` : ''}

===== FILE CONTENT =====
${parseResult.text}
===== END CONTENT =====

USER FOCUS QUESTION: ${focusQuestion || 'Perform a comprehensive deep analysis. Identify key insights, gaps, future opportunities, risks, and patterns.'}
  `.trim();

  // ── Stream SSE response ───────────────────────────────────────────────
  const { readable, writable } = new TransformStream();
  const writer = writable.getWriter();
  const encoder = new TextEncoder();

  const sendEvent = async (event: string, data: unknown) => {
    const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
    await writer.write(encoder.encode(payload));
  };

  // Run agents in background (non-blocking)
  const runAgents = async () => {
    try {
      await sendEvent('status', { status: 'parsing', analysisId });

      // Run all selected agents in parallel
      const agentPromises = agentIds.map(async (agentId) => {
        const persona = AGENT_PERSONAS[agentId];
        if (!persona) {
          await sendEvent('agent_error', {
            agentId,
            error: `Unknown agent: ${agentId}`,
          });
          return;
        }

        await sendEvent('agent_start', { agentId });

        try {
          if (aiProvider === 'claude' || aiProvider === 'both') {
            await streamAgentClaude(
              c.env.ANTHROPIC_API_KEY,
              agentId,
              persona,
              fileContext,
              sendEvent
            );
          } else if (aiProvider === 'openai') {
            await streamAgentOpenAI(
              c.env.OPENAI_API_KEY,
              agentId,
              persona,
              fileContext,
              sendEvent
            );
          }
        } catch (err) {
          const msg = err instanceof Error ? err.message : 'Agent failed';
          await sendEvent('agent_error', { agentId, error: msg });
        }
      });

      await sendEvent('status', { status: 'running', analysisId });

      // Wait for all agents (Chen runs last, after all others)
      const nonChenAgents = agentPromises.filter((_, i) => agentIds[i] !== 'chen');
      const chenIndex = agentIds.indexOf('chen');

      await Promise.allSettled(nonChenAgents);

      // Now run Chen with all previous outputs
      if (chenIndex >= 0) {
        await sendEvent('status', { status: 'synthesizing', analysisId });
        await agentPromises[chenIndex];
      }

      await sendEvent('status', { status: 'complete', analysisId });
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Analysis failed';
      await sendEvent('error', { message: msg, analysisId });
    } finally {
      await writer.close();
    }
  };

  // Execute agents (using waitUntil in production for long-running tasks)
  c.executionCtx.waitUntil(runAgents());

  return new Response(readable, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'X-Analysis-Id': analysisId,
    },
  });
});

// ── Claude Agent Streaming ────────────────────────────────────────────────────
async function streamAgentClaude(
  apiKey: string,
  agentId: string,
  systemPrompt: string,
  fileContext: string,
  sendEvent: (event: string, data: unknown) => Promise<void>
): Promise<void> {
  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'anthropic-beta': 'messages-2023-12-15',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1200,
      stream: true,
      system: systemPrompt,
      messages: [
        {
          role: 'user',
          content: fileContext,
        },
      ],
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Claude API error ${response.status}: ${error}`);
  }

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();
  let fullText = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    const chunk = decoder.decode(value, { stream: true });
    const lines = chunk.split('\n');

    for (const line of lines) {
      if (!line.startsWith('data: ')) continue;
      const data = line.slice(6);
      if (data === '[DONE]') continue;

      try {
        const event = JSON.parse(data);
        if (event.type === 'content_block_delta' && event.delta?.text) {
          fullText += event.delta.text;
          await sendEvent('agent_token', {
            agentId,
            token: event.delta.text,
          });
        }
      } catch {
        // Skip malformed SSE lines
      }
    }
  }

  await sendEvent('agent_complete', {
    agentId,
    fullText,
    provider: 'claude',
  });
}

// ── OpenAI Agent Streaming ────────────────────────────────────────────────────
async function streamAgentOpenAI(
  apiKey: string,
  agentId: string,
  systemPrompt: string,
  fileContext: string,
  sendEvent: (event: string, data: unknown) => Promise<void>
): Promise<void> {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      max_tokens: 1200,
      stream: true,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: fileContext },
      ],
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OpenAI API error ${response.status}: ${error}`);
  }

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();
  let fullText = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    const chunk = decoder.decode(value, { stream: true });
    const lines = chunk.split('\n');

    for (const line of lines) {
      if (!line.startsWith('data: ')) continue;
      const data = line.slice(6).trim();
      if (data === '[DONE]') continue;

      try {
        const event = JSON.parse(data);
        const token = event.choices?.[0]?.delta?.content;
        if (token) {
          fullText += token;
          await sendEvent('agent_token', { agentId, token });
        }
      } catch {
        // Skip malformed lines
      }
    }
  }

  await sendEvent('agent_complete', {
    agentId,
    fullText,
    provider: 'openai',
  });
}
