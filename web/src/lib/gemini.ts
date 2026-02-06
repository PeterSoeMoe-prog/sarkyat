"use client";

import { GoogleGenerativeAI } from "@google/generative-ai";

function parseRetryAfterSeconds(msg: string): number | null {
  const m1 = msg.match(/retry\s+in\s+([0-9.]+)s/i);
  if (m1?.[1]) {
    const v = Number(m1[1]);
    if (Number.isFinite(v) && v > 0) return v;
  }

  const m2 = msg.match(/retryDelay"\s*:\s*"(\d+)s"/i);
  if (m2?.[1]) {
    const v = Number(m2[1]);
    if (Number.isFinite(v) && v > 0) return v;
  }

  const m3 = msg.match(/retryDelay\s*:?\s*(\d+)s/i);
  if (m3?.[1]) {
    const v = Number(m3[1]);
    if (Number.isFinite(v) && v > 0) return v;
  }

  return null;
}

async function listModelsDiagnostic(apiKey: string): Promise<string> {
  try {
    const url = `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(
      apiKey
    )}`;
    const res = await fetch(url, { method: "GET" });
    if (!res.ok) return `ListModels failed: ${res.status} ${res.statusText}`;
    const data = (await res.json()) as any;
    const models = Array.isArray(data?.models) ? data.models : [];
    const summarized = models
      .map((m: any) => {
        const name = String(m?.name ?? "");
        const methods = Array.isArray(m?.supportedGenerationMethods)
          ? (m.supportedGenerationMethods as unknown[]).map((x) => String(x))
          : [];
        return { name, methods };
      })
      .filter((m: { name: string }) => m.name.length > 0);

    const canGenerate = summarized.filter((m: { methods: string[] }) =>
      m.methods.includes("generateContent")
    );

    const top = canGenerate.slice(0, 20);
    const lines = top.map((m: any) => `- ${m.name} (${m.methods.join(",")})`);
    const extra = canGenerate.length > top.length ? `\n… +${canGenerate.length - top.length} more` : "";
    return `Available models (first ${top.length}/${canGenerate.length} supporting generateContent):\n${lines.join("\n")}${extra}`;
  } catch (e: unknown) {
    const err = e as { message?: string };
    return `ListModels failed: ${err?.message ? String(err.message) : "unknown error"}`;
  }
}

export async function generateThaiExplanation(
  apiKey: string,
  thai: string,
  burmese?: string | null
): Promise<string> {
  const key = (apiKey ?? "").trim();
  if (!key) throw new Error("Missing API key");

  const genAI = new GoogleGenerativeAI(key);
  const model = genAI.getGenerativeModel({ model: "gemini-flash-latest" });

  const prompt =
    `You must respond in Burmese (Myanmar) language and follow the STRICT output format below.\n` +
    `Output MUST be plain text only (no markdown, no bullets other than the exact lines requested).\n\n` +
    `STRICT FORMAT (copy this structure exactly):\n\n` +
    `စာလုံး (အဓိပ္ပာယ်)\n\n` +
    `ဖွဲ့စည်းပုံ - ဗျည်း [Thai] + သရ [Thai] + အသတ် [Thai] (Tone - Burmese explanation)\n\n` +
    `ဝါကျ - [Thai Sentence] ([Burmese Translation])\n` +
    `ဝါကျ - [Thai Sentence] ([Burmese Translation])\n` +
    `ဝါကျ - [Thai Sentence] ([Burmese Translation])\n` +
    `ဝါကျ - [Thai Sentence] ([Burmese Translation])\n\n` +
    `TARGET WORD:\n` +
    `Thai word: ${(thai ?? "").trim() || "(empty)"}\n` +
    (burmese ? `Known Burmese meaning: ${(burmese ?? "").trim()}\n` : "") +
    `\n` +
    `IMPORTANT RULES:\n` +
    `1) In the structure line (ဖွဲ့စည်းပုံ), you MUST write Thai consonants/vowels/final markers in Thai script inside [brackets].\n` +
    `   - Do NOT replace Thai letters with Burmese character names.\n` +
    `   - You MAY add Burmese pronunciation in parentheses AFTER the Thai script, e.g. [ม (มอ - မော)].\n` +
    `2) Structure line must match exactly:\n` +
    `   ဖွဲ့စည်းပုံ - ဗျည်း [<Thai consonant(s)>] + သရ [<Thai vowel(s)>] + အသတ် [<Thai final/marker or none>] (Tone - <Burmese explanation>)\n` +
    `3) Provide exactly 4 example sentence lines. Each line MUST match exactly:\n` +
    `   ဝါကျ - <Thai Sentence> (<Burmese Translation>)\n` +
    `4) No extra sections, no extra commentary.\n`;

  try {
    const result = await model.generateContent(prompt);
    const text = result?.response?.text?.() ?? "";
    const cleaned = String(text ?? "").trim();
    if (!cleaned) throw new Error("Empty response");
    return cleaned;
  } catch (e: unknown) {
    const err = e as { message?: string };
    const msg = err?.message ? String(err.message) : "AI request failed";

    if (msg.includes("[429") || msg.includes(" 429 ") || msg.includes("429")) {
      const retryAfter = parseRetryAfterSeconds(msg);
      if (retryAfter != null) {
        throw new Error(`RATE_LIMIT: retry_after=${Math.ceil(retryAfter)}s`);
      }
      throw new Error("RATE_LIMIT: quota_exceeded");
    }

    if (msg.includes("[404") || msg.includes(" 404 ") || msg.includes("404")) {
      const diag = await listModelsDiagnostic(key);
      throw new Error(`${msg}\n\n${diag}`);
    }
    throw new Error(msg);
  }
}
