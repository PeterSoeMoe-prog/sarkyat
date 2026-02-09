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
  burmese?: string | null,
  logic?: { consonants?: string; vowels?: string; tones?: string }
): Promise<string> {
  const key = (apiKey ?? "").trim();
  if (!key) throw new Error("Missing API key");

  const genAI = new GoogleGenerativeAI(key);
  const model = genAI.getGenerativeModel({ model: "gemini-flash-latest" });

  let logicContext = "";
  if (logic) {
    if (logic.consonants) logicContext += `USER-DEFINED CONSONANT NAMES/MAPPINGS (use these when analyzing ဗျည်း and အသတ်ဗျည်း):\n${logic.consonants}\n\n`;
    if (logic.vowels) logicContext += `USER-DEFINED VOWEL NAMES/MAPPINGS (use these when analyzing သရ):\n${logic.vowels}\n\n`;
    if (logic.tones) logicContext += `USER-DEFINED TONE NAMES/MAPPINGS (use these when analyzing Tone):\n${logic.tones}\n\n`;
  }

  const prompt =
    `You must respond in Burmese (Myanmar) language and follow the STRICT output format below.\n` +
    `Output MUST be plain text with XML-like tags for separation.\n\n` +
    (logicContext ? `STRICT REQUIREMENT: USE THE FOLLOWING USER-DEFINED VOCAB LOGIC. If a Thai character exists in these lists, you MUST use the corresponding Burmese name provided below:\n${logicContext}` : "") +
    `STRICT FORMAT (copy this structure exactly):\n\n` +
    `<composition>\n` +
    `[Sound] [ThaiChar Type (BurmeseName) + ThaiChar Type (BurmeseName) + ...]\n` +
    `...\n` +
    `</composition>\n` +
    `<sentence>\n` +
    `[Thai Sentence]\n` +
    `[Burmese Translation]\n` +
    `</sentence>\n\n` +
    `TARGET WORD:\n` +
    `Thai word: ${(thai ?? "").trim()}\n` +
    `Burmese meaning: ${(burmese ?? "").trim()}\n` +
    `\n` +
    `IMPORTANT RULES:\n` +
    `1) DO NOT show any section headers. Start directly with the <composition> tag.\n` +
    `2) Break the word into its individual sounds/syllables.\n` +
    `3) For EACH sound, show its composition in ONE LINE following this exact pattern:\n` +
    `   Sound [ThaiChar Type (BurmeseName) + ThaiChar Type (BurmeseName) + ...]\n` +
    `   Example for "ดอกจำပာ": \n` +
    `   ดอก [ဒ ဗျည်း (ဒေါ-ဒေက်) + အ သရ (အော-) + က အသတ်ဗျည်း (ကော-ကိုင်)]\n` +
    `   จำ [จ ဗျည်း (ကျော-ကျန်) + -ำ သရ (အမ်)]\n` +
    `   ပာ [ပ ဗျည်း (ပော-ပား) + -ာ သရ (အာ)]\n` +
    `4) Types to use in Burmese: ဗျည်း, သရ, Tone, အသတ်ဗျည်း.\n` +
    `5) Use Thai script for characters and Burmese names from the USER-DEFINED logic.\n` +
    `6) Provide exactly ONE simple example sentence inside the <sentence> tag on TWO LINES. \n` +
    `   Line 1: Thai Sentence\n` +
    `   Line 2: Burmese Translation (DO NOT USE PARENTHESES OR BRACES)\n` +
    `   STRICT RULE: DO NOT include "ဝါကျ -" prefix or any other labels inside the <sentence> tag.\n` +
    `7) No extra sections, no extra commentary.\n`;

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
