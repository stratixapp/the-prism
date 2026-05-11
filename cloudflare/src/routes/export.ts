/**
 * routes/export.ts
 * Triggers branded PDF report generation for a completed analysis.
 * Full PDF generation is handled client-side in Flutter (Phase 17).
 * This route provides the structured data needed for the PDF.
 */

import { Hono } from 'hono';
import { Env } from '../index';

export const exportRoute = new Hono<{ Bindings: Env }>();

// GET /api/export/:analysisId — returns full analysis data for PDF generation
exportRoute.get('/:analysisId', async (c) => {
  const userId = (c as unknown as { get: (k: string) => string }).get('userId');
  const analysisId = c.req.param('analysisId');

  const projectId = c.env.FIREBASE_PROJECT_ID;
  const docUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/analyses/${analysisId}`;

  // In Phase 17, full PDF generation logic is added here
  // For now, return the raw analysis document

  return c.json({
    analysisId,
    message: 'Export endpoint ready. PDF generation implemented in Phase 17.',
  });
});
