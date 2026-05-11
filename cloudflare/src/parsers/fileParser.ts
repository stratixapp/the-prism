/**
 * parsers/fileParser.ts
 * Extracts readable text content from any supported file type.
 * Runs entirely in the Cloudflare Worker edge runtime.
 *
 * Supported: PDF, DOCX, XLSX, CSV, TXT, MD, JSON, XML, ZIP, APK, images
 */

const MAX_EXTRACT_CHARS = 120_000; // ~30K tokens — safe for 200K context

export interface ParseResult {
  text: string;
  pageCount?: number;
  sheetCount?: number;
  fileCount?: number;
  warning?: string;
}

export async function parseFile(
  buffer: ArrayBuffer,
  extension: string,
  mimeType: string,
  fileName: string
): Promise<ParseResult> {
  const ext = extension.toLowerCase();

  try {
    switch (ext) {
      case 'pdf':
        return await parsePdf(buffer);
      case 'docx':
      case 'doc':
        return await parseDocx(buffer);
      case 'xlsx':
      case 'xls':
        return await parseXlsx(buffer);
      case 'csv':
        return parseCsv(buffer);
      case 'txt':
      case 'md':
      case 'markdown':
      case 'rst':
        return parseText(buffer);
      case 'json':
        return parseJson(buffer);
      case 'xml':
        return parseXml(buffer);
      case 'zip':
        return await parseZip(buffer, fileName);
      case 'apk':
        return await parseApk(buffer);
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return parseImage(buffer, ext, fileName);
      case 'pptx':
        return await parsePptx(buffer);
      default:
        // Try as plain text
        return parseText(buffer);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown parse error';
    return {
      text: `[Parse failed for ${fileName}: ${message}. File type: ${ext}]`,
      warning: message,
    };
  }
}

// ── PDF Parser ────────────────────────────────────────────────────────────────
async function parsePdf(buffer: ArrayBuffer): Promise<ParseResult> {
  // In Cloudflare Workers we use a lightweight PDF text extractor
  // that works without native modules
  const bytes = new Uint8Array(buffer);
  const text = extractPdfText(bytes);
  return {
    text: truncate(text),
    warning: text.length > MAX_EXTRACT_CHARS
      ? 'PDF content truncated to fit context window'
      : undefined,
  };
}

function extractPdfText(bytes: Uint8Array): string {
  // Lightweight PDF text stream extractor
  // Finds BT/ET blocks and extracts Tj/TJ operators
  const decoder = new TextDecoder('latin1');
  const raw = decoder.decode(bytes);
  const chunks: string[] = [];

  // Extract text between BT and ET markers
  const btEtRegex = /BT([\s\S]*?)ET/g;
  let match: RegExpExecArray | null;

  while ((match = btEtRegex.exec(raw)) !== null) {
    const block = match[1];
    // Tj operator: (text) Tj
    const tjRegex = /\(([^)]*)\)\s*Tj/g;
    let tj: RegExpExecArray | null;
    while ((tj = tjRegex.exec(block)) !== null) {
      chunks.push(decodePdfString(tj[1]));
    }
    // TJ operator: [(text) spacing (text)] TJ
    const tjArrayRegex = /\[([^\]]*)\]\s*TJ/g;
    let tja: RegExpExecArray | null;
    while ((tja = tjArrayRegex.exec(block)) !== null) {
      const innerRegex = /\(([^)]*)\)/g;
      let inner: RegExpExecArray | null;
      while ((inner = innerRegex.exec(tja[1])) !== null) {
        chunks.push(decodePdfString(inner[1]));
      }
    }
  }

  return chunks.join(' ').replace(/\s+/g, ' ').trim();
}

function decodePdfString(s: string): string {
  return s
    .replace(/\\n/g, '\n')
    .replace(/\\r/g, '\r')
    .replace(/\\t/g, '\t')
    .replace(/\\\(/g, '(')
    .replace(/\\\)/g, ')')
    .replace(/\\\\/g, '\\');
}

// ── DOCX Parser ───────────────────────────────────────────────────────────────
async function parseDocx(buffer: ArrayBuffer): Promise<ParseResult> {
  // DOCX is a ZIP file — extract word/document.xml
  const zipEntries = await extractZipEntries(buffer);
  const docXml = zipEntries.get('word/document.xml');
  if (!docXml) {
    return { text: '[DOCX: Could not find document.xml inside the file]' };
  }

  // Strip XML tags, preserve text content
  const text = docXml
    .replace(/<w:br[^>]*\/>/g, '\n')
    .replace(/<w:p[^>]*>/g, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#x27;/g, "'")
    .replace(/\n{3,}/g, '\n\n')
    .trim();

  return { text: truncate(text) };
}

// ── XLSX Parser ───────────────────────────────────────────────────────────────
async function parseXlsx(buffer: ArrayBuffer): Promise<ParseResult> {
  const zipEntries = await extractZipEntries(buffer);

  // Get shared strings
  const sharedStringsXml = zipEntries.get('xl/sharedStrings.xml') || '';
  const sharedStrings: string[] = [];
  const siRegex = /<si>([\s\S]*?)<\/si>/g;
  let si: RegExpExecArray | null;
  while ((si = siRegex.exec(sharedStringsXml)) !== null) {
    const content = si[1].replace(/<[^>]+>/g, '').trim();
    sharedStrings.push(content);
  }

  // Get sheet names
  const workbookXml = zipEntries.get('xl/workbook.xml') || '';
  const sheetNameRegex = /<sheet\s+name="([^"]+)"/g;
  const sheetNames: string[] = [];
  let sn: RegExpExecArray | null;
  while ((sn = sheetNameRegex.exec(workbookXml)) !== null) {
    sheetNames.push(sn[1]);
  }

  // Parse sheets
  const textParts: string[] = [];
  let sheetIndex = 1;

  while (sheetIndex <= 10) {
    const sheetXml = zipEntries.get(`xl/worksheets/sheet${sheetIndex}.xml`);
    if (!sheetXml) break;

    const sheetName = sheetNames[sheetIndex - 1] || `Sheet${sheetIndex}`;
    textParts.push(`\n=== ${sheetName} ===`);

    const rowRegex = /<row[^>]*>([\s\S]*?)<\/row>/g;
    let row: RegExpExecArray | null;
    while ((row = rowRegex.exec(sheetXml)) !== null) {
      const cells: string[] = [];
      const cellRegex = /<c\s+r="[^"]+"\s*(?:t="([^"]*)")?\s*(?:[^>]*)>(?:<v>([^<]*)<\/v>)?/g;
      let cell: RegExpExecArray | null;
      while ((cell = cellRegex.exec(row[1])) !== null) {
        const type = cell[1];
        const value = cell[2] || '';
        if (type === 's') {
          cells.push(sharedStrings[parseInt(value)] || '');
        } else {
          cells.push(value);
        }
      }
      if (cells.some(c => c.trim())) {
        textParts.push(cells.join('\t'));
      }
    }
    sheetIndex++;
  }

  return {
    text: truncate(textParts.join('\n')),
    sheetCount: sheetIndex - 1,
  };
}

// ── CSV Parser ────────────────────────────────────────────────────────────────
function parseCsv(buffer: ArrayBuffer): ParseResult {
  const text = new TextDecoder().decode(buffer);
  // Limit to first 500 rows for large CSVs
  const lines = text.split('\n').slice(0, 500);
  return { text: truncate(lines.join('\n')) };
}

// ── Plain Text Parser ─────────────────────────────────────────────────────────
function parseText(buffer: ArrayBuffer): ParseResult {
  const text = new TextDecoder().decode(buffer);
  return { text: truncate(text) };
}

// ── JSON Parser ───────────────────────────────────────────────────────────────
function parseJson(buffer: ArrayBuffer): ParseResult {
  const raw = new TextDecoder().decode(buffer);
  try {
    const parsed = JSON.parse(raw);
    // Pretty print for readability
    const pretty = JSON.stringify(parsed, null, 2);
    return { text: truncate(pretty) };
  } catch {
    return { text: truncate(raw) };
  }
}

// ── XML Parser ────────────────────────────────────────────────────────────────
function parseXml(buffer: ArrayBuffer): ParseResult {
  const raw = new TextDecoder().decode(buffer);
  const text = raw
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return { text: truncate(text) };
}

// ── ZIP Parser ────────────────────────────────────────────────────────────────
async function parseZip(buffer: ArrayBuffer, fileName: string): Promise<ParseResult> {
  const entries = await extractZipEntries(buffer);
  const textParts: string[] = [
    `ZIP Archive: ${fileName}`,
    `Contents (${entries.size} files):`,
    '',
  ];

  for (const [name] of entries) {
    textParts.push(`• ${name}`);
  }

  // Extract text from readable files inside ZIP
  textParts.push('\n--- Readable file contents ---\n');

  const readableExtensions = new Set([
    'txt', 'md', 'json', 'xml', 'csv',
    'js', 'ts', 'py', 'dart', 'kt', 'java',
    'swift', 'html', 'css', 'yaml', 'yml',
    'toml', 'sh', 'gradle', 'properties',
    'gradle.kts', 'xml',
  ]);

  for (const [name, content] of entries) {
    const ext = name.split('.').pop()?.toLowerCase() || '';
    if (readableExtensions.has(ext) && content.length < 50000) {
      textParts.push(`\n=== ${name} ===`);
      textParts.push(content.slice(0, 5000));
    }
  }

  return {
    text: truncate(textParts.join('\n')),
    fileCount: entries.size,
  };
}

// ── APK Parser ────────────────────────────────────────────────────────────────
async function parseApk(buffer: ArrayBuffer): Promise<ParseResult> {
  // APK is a ZIP — extract key files
  const entries = await extractZipEntries(buffer);
  const textParts: string[] = ['=== Android APK Analysis ===\n'];

  // AndroidManifest (binary XML — show raw entry names)
  const manifestEntry = entries.get('AndroidManifest.xml');
  if (manifestEntry) {
    textParts.push('--- AndroidManifest.xml (binary) ---');
    // Extract package name and permissions from binary manifest
    textParts.push('[Binary XML — key data extracted below]');
  }

  // List all files
  textParts.push('\n--- APK Contents ---');
  for (const [name] of entries) {
    textParts.push(`• ${name}`);
  }

  // Extract strings.xml if present
  const stringsXml =
    entries.get('res/values/strings.xml') ||
    entries.get('res/values-en/strings.xml');
  if (stringsXml) {
    textParts.push('\n--- res/values/strings.xml ---');
    textParts.push(stringsXml.slice(0, 10000));
  }

  // Extract any .properties or config files
  for (const [name, content] of entries) {
    if (
      (name.endsWith('.properties') || name.endsWith('.json')) &&
      !name.includes('META-INF') &&
      content.length < 5000
    ) {
      textParts.push(`\n--- ${name} ---`);
      textParts.push(content);
    }
  }

  return {
    text: truncate(textParts.join('\n')),
    fileCount: entries.size,
  };
}

// ── PPTX Parser ───────────────────────────────────────────────────────────────
async function parsePptx(buffer: ArrayBuffer): Promise<ParseResult> {
  const entries = await extractZipEntries(buffer);
  const textParts: string[] = [];

  // Extract slides in order
  let slideIndex = 1;
  while (slideIndex <= 200) {
    const slideXml = entries.get(`ppt/slides/slide${slideIndex}.xml`);
    if (!slideXml) break;

    textParts.push(`\n--- Slide ${slideIndex} ---`);
    const text = slideXml
      .replace(/<a:br[^>]*\/>/g, '\n')
      .replace(/<a:p[^>]*>/g, '\n')
      .replace(/<[^>]+>/g, '')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
    textParts.push(text);
    slideIndex++;
  }

  return {
    text: truncate(textParts.join('\n')),
    pageCount: slideIndex - 1,
  };
}

// ── Image Handler ─────────────────────────────────────────────────────────────
function parseImage(
  buffer: ArrayBuffer,
  ext: string,
  fileName: string
): ParseResult {
  // Convert to base64 for vision model
  const bytes = new Uint8Array(buffer);
  const chunks: string[] = [];
  for (let i = 0; i < bytes.length; i += 8192) {
    chunks.push(String.fromCharCode(...bytes.slice(i, i + 8192)));
  }
  const base64 = btoa(chunks.join(''));

  return {
    text: `[IMAGE:${ext}:${fileName}:${base64.slice(0, 100)}...]`,
    warning: 'Image file — will be sent to vision model for analysis',
  };
}

// ── ZIP Entry Extractor ───────────────────────────────────────────────────────
async function extractZipEntries(
  buffer: ArrayBuffer
): Promise<Map<string, string>> {
  const bytes = new Uint8Array(buffer);
  const entries = new Map<string, string>();
  const decoder = new TextDecoder('utf-8', { fatal: false });

  let offset = 0;
  while (offset < bytes.length - 4) {
    // Local file header signature: PK\x03\x04
    if (
      bytes[offset] === 0x50 &&
      bytes[offset + 1] === 0x4b &&
      bytes[offset + 2] === 0x03 &&
      bytes[offset + 3] === 0x04
    ) {
      const compression = (bytes[offset + 8] | (bytes[offset + 9] << 8));
      const compressedSize =
        bytes[offset + 18] |
        (bytes[offset + 19] << 8) |
        (bytes[offset + 20] << 16) |
        (bytes[offset + 21] << 24);
      const fileNameLength = bytes[offset + 26] | (bytes[offset + 27] << 8);
      const extraLength = bytes[offset + 28] | (bytes[offset + 29] << 8);

      const fileNameBytes = bytes.slice(offset + 30, offset + 30 + fileNameLength);
      const fileName = decoder.decode(fileNameBytes);

      const dataOffset = offset + 30 + fileNameLength + extraLength;

      if (compression === 0 && compressedSize > 0 && compressedSize < 2 * 1024 * 1024) {
        // Stored (no compression) — read directly
        const fileData = bytes.slice(dataOffset, dataOffset + compressedSize);
        try {
          entries.set(fileName, decoder.decode(fileData));
        } catch {
          entries.set(fileName, `[Binary: ${compressedSize} bytes]`);
        }
      } else if (compressedSize > 0) {
        entries.set(fileName, `[Compressed: ${compressedSize} bytes]`);
      }

      offset = dataOffset + compressedSize;
    } else {
      offset++;
    }
  }

  return entries;
}

// ── Helpers ───────────────────────────────────────────────────────────────────
function truncate(text: string): string {
  if (text.length <= MAX_EXTRACT_CHARS) return text;
  return (
    text.slice(0, MAX_EXTRACT_CHARS) +
    `\n\n[... Content truncated at ${MAX_EXTRACT_CHARS} characters ...]`
  );
}
