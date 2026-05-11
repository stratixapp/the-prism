/**
 * agents/agentOrchestrator.ts
 *
 * THE ENGINE ROOM OF THE PRISM.
 *
 * Responsibilities:
 *  1. Accept parsed file text + agent list
 *  2. Fire all non-Chen agents simultaneously via Promise.allSettled()
 *  3. Collect every token as it streams, emit SSE events to Flutter
 *  4. After all agents complete → run Chen with all outputs as context
 *  5. Track token usage and cost per agent
 *  6. Handle partial failures gracefully (one agent failing ≠ whole analysis fails)
 *
 * SSE Event Schema (every event sent to Flutter):
 *  - status        { status: 'parsing'|'running'|'synthesizing'|'complete', analysisId }
 *  - agent_start   { agentId, provider }
 *  - agent_token   { agentId, token, provider }
 *  - agent_complete{ agentId, fullText, tokensUsed, durationMs, provider }
 *  - agent_error   { agentId, error }
 *  - cost_update   { totalTokens, estimatedCostUsd }
 *  - error         { message, analysisId }
 */

import { AGENT_PERSONAS } from './agentPersonas';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface OrchestratorConfig {
  analysisId: string;
  fileContext: string;          // Parsed file text + metadata
  agentIds: string[];           // Ordered list — Chen must be last if present
  aiProvider: 'claude' | 'openai' | 'both';
  anthropicApiKey: string;
  openaiApiKey: string;
  sendEvent: SseEmitter;
}

export type SseEmitter = (event: string, data: unknown) => Promise<void>;

export interface AgentResult {
  agentId: string;
  fullText: string;
  tokensUsed: number;
  durationMs: number;
  provider: string;
  success: boolean;
  error?: string;
}

// ── Cost constants (USD per 1K tokens) ───────────────────────────────────────
const COST_PER_1K: Record<string, { input: number; output: number }> = {
  'claude-sonnet-4-20250514': { input: 0.003, output: 0.015 },
  'gpt-4o':                   { input: 0.005, output: 0.015 },
};

// ── Main Orchestrator ─────────────────────────────────────────────────────────

export async function runOrchestrator(config: OrchestratorConfig): Promise<void> {
  const {
    analysisId,
    fileContext,
    agentIds,
    aiProvider,
    anthropicApiKey,
    openaiApiKey,
    sendEvent,
  } = config;

  // Separate Chen from the specialist agents — Chen always runs last
  const chenId = 'chen';
  const specialistIds = agentIds.filter((id) => id !== chenId);
  const hasChen = agentIds.includes(chenId);

  let totalTokens = 0;
  const agentResults: AgentResult[] = [];

  // ── Phase A: Run all specialists in parallel ──────────────────────────────
  await sendEvent('status', { status: 'running', analysisId });

  const specialistPromises = specialistIds.map((agentId) =>
    runSingleAgent({
      agentId,
      fileContext,
      aiProvider: aiProvider === 'both' ? 'claude' : aiProvider, // specialists use primary
      anthropicApiKey,
      openaiApiKey,
      sendEvent,
    })
  );

  // Run all specialists simultaneously — allSettled so one failure doesn't kill others
  const settledResults = await Promise.allSettled(specialistPromises);

  settledResults.forEach((result, i) => {
    if (result.status === 'fulfilled') {
      agentResults.push(result.value);
      totalTokens += result.value.tokensUsed;
    } else {
      // Agent failed — send error event but continue
      const agentId = specialistIds[i];
      agentResults.push({
        agentId,
        fullText: '',
        tokensUsed: 0,
        durationMs: 0,
        provider: aiProvider,
        success: false,
        error: result.reason?.message || 'Agent failed',
      });
    }
  });

  // Emit running cost after specialists complete
  const estimatedCostUsd = calculateCost(totalTokens, aiProvider);
  await sendEvent('cost_update', {
    totalTokens,
    estimatedCostUsd: estimatedCostUsd.toFixed(4),
    agentsComplete: specialistIds.length,
  });

  // ── Phase B: If dual-engine (both), run OpenAI pass in parallel ───────────
  if (aiProvider === 'both' && specialistIds.length > 0) {
    await sendEvent('status', { status: 'running', analysisId, pass: 'openai' });

    const openaiPromises = specialistIds.map((agentId) =>
      runSingleAgent({
        agentId: `${agentId}_gpt`,   // suffix so Flutter shows separate stream
        fileContext,
        aiProvider: 'openai',
        anthropicApiKey,
        openaiApiKey,
        sendEvent,
        personaOverride: AGENT_PERSONAS[agentId], // same persona, different model
      })
    );

    const openaiResults = await Promise.allSettled(openaiPromises);
    openaiResults.forEach((result) => {
      if (result.status === 'fulfilled') {
        agentResults.push(result.value);
        totalTokens += result.value.tokensUsed;
      }
    });
  }

  // ── Phase C: Run Chen with all specialist outputs as context ──────────────
  if (hasChen && agentResults.some((r) => r.success && r.fullText.length > 0)) {
    await sendEvent('status', { status: 'synthesizing', analysisId });

    const chenContext = buildChenContext(fileContext, agentResults);

    const chenResult = await runSingleAgent({
      agentId: chenId,
      fileContext: chenContext,
      aiProvider: aiProvider === 'both' ? 'claude' : aiProvider,
      anthropicApiKey,
      openaiApiKey,
      sendEvent,
    });

    agentResults.push(chenResult);
    totalTokens += chenResult.tokensUsed;
  }

  // ── Phase D: Final cost update and completion ─────────────────────────────
  const finalCost = calculateCost(totalTokens, aiProvider);
  await sendEvent('cost_update', {
    totalTokens,
    estimatedCostUsd: finalCost.toFixed(4),
    agentsComplete: agentResults.length,
    final: true,
  });

  await sendEvent('status', { status: 'complete', analysisId });
}

// ── Single Agent Runner ───────────────────────────────────────────────────────

interface SingleAgentConfig {
  agentId: string;
  fileContext: string;
  aiProvider: 'claude' | 'openai';
  anthropicApiKey: string;
  openaiApiKey: string;
  sendEvent: SseEmitter;
  personaOverride?: string;
}

async function runSingleAgent(config: SingleAgentConfig): Promise<AgentResult> {
  const {
    agentId,
    fileContext,
    aiProvider,
    anthropicApiKey,
    openaiApiKey,
    sendEvent,
    personaOverride,
  } = config;

  // Strip _gpt suffix to look up persona
  const baseAgentId = agentId.replace('_gpt', '');
  const systemPrompt = personaOverride || AGENT_PERSONAS[baseAgentId];

  if (!systemPrompt) {
    await sendEvent('agent_error', { agentId, error: `No persona for agent: ${baseAgentId}` });
    return { agentId, fullText: '', tokensUsed: 0, durationMs: 0, provider: aiProvider, success: false, error: 'No persona' };
  }

  const startMs = Date.now();
  await sendEvent('agent_start', { agentId, provider: aiProvider });

  try {
    let fullText = '';
    let tokensUsed = 0;

    if (aiProvider === 'claude') {
      const result = await streamClaude({
        apiKey: anthropicApiKey,
        systemPrompt,
        userMessage: fileContext,
        onToken: async (token) => {
          fullText += token;
          await sendEvent('agent_token', { agentId, token, provider: 'claude' });
        },
      });
      tokensUsed = result.tokensUsed;
    } else {
      const result = await streamOpenAI({
        apiKey: openaiApiKey,
        systemPrompt,
        userMessage: fileContext,
        onToken: async (token) => {
          fullText += token;
          await sendEvent('agent_token', { agentId, token, provider: 'openai' });
        },
      });
      tokensUsed = result.tokensUsed;
    }

    const durationMs = Date.now() - startMs;

    await sendEvent('agent_complete', {
      agentId,
      fullText,
      tokensUsed,
      durationMs,
      provider: aiProvider,
    });

    return { agentId, fullText, tokensUsed, durationMs, provider: aiProvider, success: true };
  } catch (err: unknown) {
    const error = err instanceof Error ? err.message : 'Unknown error';
    await sendEvent('agent_error', { agentId, error });
    return { agentId, fullText: '', tokensUsed: 0, durationMs: Date.now() - startMs, provider: aiProvider, success: false, error };
  }
}

// ── Claude Streaming ──────────────────────────────────────────────────────────

interface StreamConfig {
  apiKey: string;
  systemPrompt: string;
  userMessage: string;
  onToken: (token: string) => Promise<void>;
}

interface StreamResult {
  tokensUsed: number;
}

async function streamClaude(config: StreamConfig): Promise<StreamResult> {
  const { apiKey, systemPrompt, userMessage, onToken } = config;

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1200,
      stream: true,
      system: systemPrompt,
      messages: [{ role: 'user', content: userMessage }],
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Claude ${response.status}: ${body.slice(0, 200)}`);
  }

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();
  let inputTokens = 0;
  let outputTokens = 0;
  let buffer = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    // Keep last incomplete line in buffer
    buffer = lines.pop() ?? '';

    for (const line of lines) {
      if (!line.startsWith('data: ')) continue;
      const raw = line.slice(6).trim();
      if (!raw || raw === '[DONE]') continue;

      try {
        const evt = JSON.parse(raw);

        switch (evt.type) {
          case 'message_start':
            inputTokens = evt.message?.usage?.input_tokens ?? 0;
            break;
          case 'content_block_delta':
            if (evt.delta?.type === 'text_delta' && evt.delta?.text) {
              await onToken(evt.delta.text);
            }
            break;
          case 'message_delta':
            outputTokens = evt.usage?.output_tokens ?? 0;
            break;
        }
      } catch {
        // Malformed SSE line — skip
      }
    }
  }

  return { tokensUsed: inputTokens + outputTokens };
}

// ── OpenAI Streaming ──────────────────────────────────────────────────────────

async function streamOpenAI(config: StreamConfig): Promise<StreamResult> {
  const { apiKey, systemPrompt, userMessage, onToken } = config;

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
      stream_options: { include_usage: true },
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user',   content: userMessage },
      ],
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenAI ${response.status}: ${body.slice(0, 200)}`);
  }

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();
  let totalTokens = 0;
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
        const token = evt.choices?.[0]?.delta?.content;
        if (token) await onToken(token);

        // usage comes in the final chunk when stream_options.include_usage = true
        if (evt.usage?.total_tokens) {
          totalTokens = evt.usage.total_tokens;
        }
      } catch {
        // skip
      }
    }
  }

  return { tokensUsed: totalTokens };
}

// ── Chen Context Builder ──────────────────────────────────────────────────────
// Builds a rich context block for Chen containing all specialist outputs

function buildChenContext(
  originalFileContext: string,
  results: AgentResult[]
): string {
  const successfulResults = results.filter((r) => r.success && r.fullText.length > 50);

  const agentSections = successfulResults
    .map((r) => {
      const baseId = r.agentId.replace('_gpt', '');
      return `<agent id="${baseId}" provider="${r.provider}">
${r.fullText.trim()}
</agent>`;
    })
    .join('\n\n');

  return `You are about to synthesize the outputs of ${successfulResults.length} specialist agents.

ORIGINAL FILE CONTEXT (summary):
${originalFileContext.slice(0, 2000)}
[... file context truncated for synthesis ...]

SPECIALIST AGENT OUTPUTS:
${agentSections}

Now deliver your synthesis verdict as Chen. Follow your instructions precisely.`;
}

// ── Cost Calculator ───────────────────────────────────────────────────────────

function calculateCost(totalTokens: number, provider: string): number {
  const model =
    provider === 'openai' ? 'gpt-4o' : 'claude-sonnet-4-20250514';
  const rates = COST_PER_1K[model] ?? { input: 0.003, output: 0.015 };
  // Assume 40% input / 60% output split
  const inputTokens = totalTokens * 0.4;
  const outputTokens = totalTokens * 0.6;
  return (inputTokens * rates.input + outputTokens * rates.output) / 1000;
}

// ── Stream-to-client helper (used by analyze route) ──────────────────────────

export async function streamToClient(
  writer: WritableStreamDefaultWriter<Uint8Array>,
  encoder: TextEncoder,
  event: string,
  data: unknown
): Promise<void> {
  const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
  await writer.write(encoder.encode(payload));
}
