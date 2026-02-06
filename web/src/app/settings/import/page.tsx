"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { motion } from "framer-motion";

import {
  clearVocabulary,
  fetchVocabularyEntryFromServer,
  importVocabularyRows,
  type ImportVocabularyRow,
} from "@/lib/vocab/firestore";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import type { VocabularyStatus } from "@/lib/vocab/types";

function normalizeHeader(s: string) {
  return s
    .trim()
    .toLowerCase()
    .replaceAll("_", " ")
    .replaceAll("-", " ")
    .replaceAll(/\s+/g, " ");
}

function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let inQuotes = false;

  const pushField = () => {
    row.push(field);
    field = "";
  };

  const pushRow = () => {
    rows.push(row);
    row = [];
  };

  for (let i = 0; i < text.length; i++) {
    const c = text[i];

    if (inQuotes) {
      if (c === '"') {
        const next = text[i + 1];
        if (next === '"') {
          field += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field += c;
      }
      continue;
    }

    if (c === '"') {
      inQuotes = true;
      continue;
    }

    if (c === ",") {
      pushField();
      continue;
    }

    if (c === "\n") {
      pushField();
      pushRow();
      continue;
    }

    if (c === "\r") {
      const next = text[i + 1];
      if (next === "\n") {
        i++;
      }
      pushField();
      pushRow();
      continue;
    }

    field += c;
  }

  if (inQuotes) {
    inQuotes = false;
  }

  if (field.length > 0 || row.length > 0) {
    pushField();
    pushRow();
  }

  return rows
    .map((r) => r.map((v) => v.trim()))
    .filter((r) => r.some((v) => v.length > 0));
}

function guessColumn(headers: string[], candidates: string[]) {
  const normalized = headers.map(normalizeHeader);
  const set = new Map<string, number>();
  normalized.forEach((h, idx) => set.set(h, idx));

  for (const cand of candidates) {
    const idx = set.get(normalizeHeader(cand));
    if (typeof idx === "number") return idx;
  }

  for (let i = 0; i < normalized.length; i++) {
    const h = normalized[i];
    if (candidates.some((c) => h.includes(normalizeHeader(c)))) return i;
  }

  return null;
}

export default function SettingsImportPage() {
  const { uid, isAnonymous } = useVocabulary();
  const [fileName, setFileName] = useState<string | null>(null);
  const [rawText, setRawText] = useState<string | null>(null);
  const [hasHeader, setHasHeader] = useState(true);

  const [thaiCol, setThaiCol] = useState<number | null>(null);
  const [burmeseCol, setBurmeseCol] = useState<number | null>(null);
  const [countCol, setCountCol] = useState<number | null>(null);
  const [categoryCol, setCategoryCol] = useState<number | null>(null);
  const [statusCol, setStatusCol] = useState<number | null>(null);

  const normalizeStatus = (raw: string): VocabularyStatus => {
    const v = raw.trim().toLowerCase();
    if (v === "drill") return "drill";
    if (v === "ready") return "ready";
    return "queue";
  };

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const parsed = useMemo(() => {
    if (!rawText) return null;
    try {
      return parseCsv(rawText);
    } catch {
      return null;
    }
  }, [rawText]);

  const headers = useMemo(() => {
    if (!parsed || parsed.length === 0) return null;
    return hasHeader ? parsed[0] : null;
  }, [parsed, hasHeader]);

  const dataRows = useMemo(() => {
    if (!parsed) return [];
    if (!hasHeader) return parsed;
    return parsed.slice(1);
  }, [parsed, hasHeader]);

  const columnCount = useMemo(() => {
    if (headers) return headers.length;
    return dataRows.reduce((max, r) => Math.max(max, r.length), 0);
  }, [headers, dataRows]);

  const columnLabels = useMemo(() => {
    const cols: string[] = [];
    for (let i = 0; i < columnCount; i++) {
      cols.push(headers?.[i]?.trim() || `Column ${i + 1}`);
    }
    return cols;
  }, [columnCount, headers]);

  const preview = useMemo(() => {
    if (!dataRows.length) return [];

    const idxThai =
      thaiCol ??
      (hasHeader && headers
        ? guessColumn(headers, ["thai", "thai word", "word", "term"])
        : 0);
    const idxBurmese =
      burmeseCol ??
      (hasHeader && headers
        ? guessColumn(headers, [
            "burmese",
            "meaning",
            "burmese meaning",
            "translation",
            "myanmar",
          ])
        : 1);
    const idxCount =
      countCol ??
      (hasHeader && headers
        ? guessColumn(headers, ["count", "hit", "hits", "recite", "recited"])
        : null);
    const idxCategory =
      categoryCol ??
      (hasHeader && headers
        ? guessColumn(headers, ["category", "cat", "group"])
        : null);
    const idxStatus =
      statusCol ??
      (hasHeader && headers
        ? guessColumn(headers, ["status", "state"])
        : null);

    const take = dataRows.slice(0, 8);
    return take
      .map((r) => {
        const thai = (typeof idxThai === "number" ? r[idxThai] : "") ?? "";
        const burmese =
          typeof idxBurmese === "number" ? (r[idxBurmese] ?? "") : "";
        const countRaw =
          typeof idxCount === "number" ? (r[idxCount] ?? "") : "";
        const count = Number.isFinite(Number(countRaw)) ? Number(countRaw) : 0;
        const categoryRaw =
          typeof idxCategory === "number" ? (r[idxCategory] ?? "") : "";
        const category = categoryRaw.toString().trim();
        const statusRaw =
          typeof idxStatus === "number" ? (r[idxStatus] ?? "") : "";
        const status = normalizeStatus(statusRaw.toString());
        return {
          thai: thai.trim(),
          burmese: burmese.trim(),
          count,
          category,
          status,
        };
      })
      .filter((r) => r.thai.length > 0);
  }, [
    dataRows,
    thaiCol,
    burmeseCol,
    countCol,
    categoryCol,
    statusCol,
    hasHeader,
    headers,
  ]);

  const onPickFile = async (file: File | null) => {
    setError(null);
    setSuccess(null);

    if (!file) {
      setFileName(null);
      setRawText(null);
      return;
    }

    setFileName(file.name);
    const text = await file.text();
    setRawText(text);

    setThaiCol(null);
    setBurmeseCol(null);
    setCountCol(null);
    setCategoryCol(null);
    setStatusCol(null);
  };

  const runImport = async () => {
    setError(null);
    setSuccess(null);

    if (!uid || isAnonymous) {
      setError("Sign in with Google first.");
      return;
    }

    if (!parsed || parsed.length === 0) {
      setError("No CSV loaded.");
      return;
    }

    const resolvedHeaders = hasHeader ? parsed[0] : null;
    const rows = hasHeader ? parsed.slice(1) : parsed;

    const idxThai =
      typeof thaiCol === "number"
        ? thaiCol
        : resolvedHeaders
          ? guessColumn(resolvedHeaders, ["thai", "thai word", "word", "term"]) ??
            0
          : 0;

    const idxBurmese =
      typeof burmeseCol === "number"
        ? burmeseCol
        : resolvedHeaders
          ? guessColumn(resolvedHeaders, [
              "burmese",
              "meaning",
              "burmese meaning",
              "translation",
              "myanmar",
            ]) ?? 1
          : 1;

    const idxCount =
      typeof countCol === "number"
        ? countCol
        : resolvedHeaders
          ? guessColumn(resolvedHeaders, [
              "count",
              "hit",
              "hits",
              "recite",
              "recited",
            ]) ?? null
          : null;

    if (typeof idxCount !== "number") {
      setError(
        "Could not detect the CSV 'count' column. Please select the Count Column manually."
      );
      return;
    }

    const idxCategory =
      typeof categoryCol === "number"
        ? categoryCol
        : resolvedHeaders
          ? guessColumn(resolvedHeaders, ["category", "cat", "group"]) ?? null
          : null;

    const idxStatus =
      typeof statusCol === "number"
        ? statusCol
        : resolvedHeaders
          ? guessColumn(resolvedHeaders, ["status", "state"]) ?? null
          : null;

    const payload: ImportVocabularyRow[] = rows
      .map((r) => {
        const thai = (r[idxThai] ?? "").trim();
        const burmese = (r[idxBurmese] ?? "").trim();
        const countRaw =
          typeof idxCount === "number" ? (r[idxCount] ?? "") : "";
        const count = Number.isFinite(Number(countRaw)) ? Number(countRaw) : 0;
        const categoryRaw =
          typeof idxCategory === "number" ? (r[idxCategory] ?? "") : "";
        const category = categoryRaw.toString().trim();
        const statusRaw =
          typeof idxStatus === "number" ? (r[idxStatus] ?? "") : "";
        const status = normalizeStatus(statusRaw.toString());

        return {
          thai,
          burmese: burmese.length ? burmese : null,
          count,
          category: category.length ? category : null,
          status,
        };
      })
      .filter((r) => r.thai.length > 0);

    if (payload.length === 0) {
      setError("No valid rows found (missing Thai words).");
      return;
    }

    const nonZeroCount = payload.filter((r) => Number(r.count ?? 0) > 0).length;
    if (payload.length >= 20 && nonZeroCount === 0) {
      setError(
        "All imported counts are 0. This usually means the Count Column is mapped to the wrong CSV column. Please select the Count Column manually and try again."
      );
      return;
    }

    console.log("[import] resolved columns", {
      idxThai,
      idxBurmese,
      idxCount,
      idxCategory,
      idxStatus,
    });
    console.log("[import] first payload row", payload[0]);

    setBusy(true);
    try {
      const result = await importVocabularyRows(uid, payload);
      console.log("[import] import result", result);

      const firstId = result?.firstId ?? null;
      if (!firstId) {
        throw new Error("Import completed but no document id was returned.");
      }

      const firstImported = await fetchVocabularyEntryFromServer(uid, firstId);
      console.log("[import] first imported doc (server)", firstImported);

      if (!firstImported) {
        throw new Error("Import completed but verification read returned null.");
      }

      const expected = payload[0];
      if (
        firstImported.thai !== expected.thai ||
        firstImported.count !== expected.count ||
        firstImported.status !== expected.status ||
        (firstImported.category ?? null) !== (expected.category ?? null)
      ) {
        throw new Error(
          `Import verification failed. expected=${JSON.stringify(expected)} actual=${JSON.stringify(
            firstImported
          )}`
        );
      }

      setSuccess(`Imported ${payload.length} words.`);
    } catch (e: unknown) {
      const err = e as { code?: string; message?: string };
      const code = err?.code ? String(err.code) : "unknown";
      const msg = err?.message ? String(err.message) : "Unknown error";
      setError(`Import failed (${code}). ${msg}`);
    } finally {
      setBusy(false);
    }
  };

  const runCleanReimport = async () => {
    setError(null);
    setSuccess(null);

    if (!uid || isAnonymous) {
      setError("Sign in with Google first.");
      return;
    }

    if (!parsed || parsed.length === 0) {
      setError("No CSV loaded.");
      return;
    }

    const ok = window.confirm(
      "This will delete ALL existing words and re-import from the CSV. Continue?"
    );
    if (!ok) return;

    setBusy(true);
    try {
      await clearVocabulary(uid);
      await runImport();
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#0A0B0F] text-white">
      <div
        className="min-h-screen"
        style={{
          background:
            "radial-gradient(1200px 800px at 50% 10%, rgba(255,255,255,0.08), rgba(0,0,0,0) 55%), radial-gradient(900px 600px at 50% 60%, rgba(255,83,145,0.09), rgba(0,0,0,0) 60%), #0A0B0F",
        }}
      >
        <div className="mx-auto w-full max-w-md px-4 pt-[calc(env(safe-area-inset-top)+20px)] pb-[calc(env(safe-area-inset-bottom)+118px)]">
        <header className="flex items-center justify-between">
          <Link
            href="/settings"
            className="rounded-full bg-[var(--surface)]/80 px-4 py-2 text-[13px] font-semibold text-[color:var(--foreground)] backdrop-blur-xl shadow-sm hover:shadow-md transition-shadow border border-[color:var(--border)]"
          >
            Back
          </Link>
          <div className="text-right">
            <div className="text-[17px] font-semibold tracking-[-0.01em]">
              Import CSV
            </div>
          </div>
          <div className="w-[68px]" />
        </header>

        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.18 }}
          className="mt-5 rounded-2xl bg-[var(--card)] p-4 shadow-[0_10px_28px_rgba(0,0,0,0.20)] border border-[color:var(--border)] backdrop-blur-xl"
        >
          <div className="text-[15px] font-semibold">Upload your CSV</div>
          <div className="mt-1 text-[13px] font-medium text-[color:var(--muted)]">
            Columns will be mapped to Thai + Burmese.
          </div>

          <div className="mt-4">
            <input
              type="file"
              accept=".csv,text/csv"
              onChange={(e) => {
                const f = e.target.files?.[0] ?? null;
                void onPickFile(f);
              }}
              className="block w-full text-[13px] file:mr-4 file:rounded-full file:border file:border-[color:var(--border)] file:bg-[var(--surface)] file:px-4 file:py-2 file:text-[13px] file:font-semibold file:text-[color:var(--foreground)]"
            />
            <div className="mt-2 text-[12px] font-medium text-[color:var(--muted)]">
              {fileName ? fileName : "No file selected"}
            </div>
          </div>

          <div className="mt-4 flex items-center justify-between rounded-xl bg-[var(--background)] px-3 py-2 border border-[color:var(--border)]">
            <div className="text-[13px] font-semibold text-[color:var(--muted-strong)]">
              First row is header
            </div>
            <button
              type="button"
              onClick={() => setHasHeader((v) => !v)}
              className="rounded-full bg-[var(--surface)] px-3 py-1.5 text-[12px] font-semibold text-[color:var(--foreground)] shadow-sm border border-[color:var(--border)]"
            >
              {hasHeader ? "Yes" : "No"}
            </button>
          </div>

          {parsed ? (
            <div className="mt-4 space-y-3">
              <div className="grid grid-cols-1 gap-3">
                <div>
                  <div className="text-[12px] font-semibold text-[color:var(--muted)]">
                    Thai Column
                  </div>
                  <select
                    value={thaiCol ?? ""}
                    onChange={(e) =>
                      setThaiCol(
                        e.target.value === "" ? null : Number(e.target.value)
                      )
                    }
                    className="mt-1 w-full rounded-xl bg-[var(--surface)] px-3 py-2 text-[13px] font-semibold border border-[color:var(--border)]"
                  >
                    <option value="">Auto-detect</option>
                    {columnLabels.map((label, idx) => (
                      <option key={`thai-${idx}`} value={idx}>
                        {label}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <div className="text-[12px] font-semibold text-[color:var(--muted)]">
                    Burmese Column
                  </div>
                  <select
                    value={burmeseCol ?? ""}
                    onChange={(e) =>
                      setBurmeseCol(
                        e.target.value === "" ? null : Number(e.target.value)
                      )
                    }
                    className="mt-1 w-full rounded-xl bg-[var(--surface)] px-3 py-2 text-[13px] font-semibold border border-[color:var(--border)]"
                  >
                    <option value="">Auto-detect</option>
                    {columnLabels.map((label, idx) => (
                      <option key={`burmese-${idx}`} value={idx}>
                        {label}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <div className="text-[12px] font-semibold text-[color:var(--muted)]">
                    Count Column
                  </div>
                  <select
                    value={countCol ?? ""}
                    onChange={(e) =>
                      setCountCol(
                        e.target.value === "" ? null : Number(e.target.value)
                      )
                    }
                    className="mt-1 w-full rounded-xl bg-[var(--surface)] px-3 py-2 text-[13px] font-semibold border border-[color:var(--border)]"
                  >
                    <option value="">Auto-detect</option>
                    {columnLabels.map((label, idx) => (
                      <option key={`count-${idx}`} value={idx}>
                        {label}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <div className="text-[12px] font-semibold text-[color:var(--muted)]">
                    Category Column
                  </div>
                  <select
                    value={categoryCol ?? ""}
                    onChange={(e) =>
                      setCategoryCol(
                        e.target.value === "" ? null : Number(e.target.value)
                      )
                    }
                    className="mt-1 w-full rounded-xl bg-[var(--surface)] px-3 py-2 text-[13px] font-semibold border border-[color:var(--border)]"
                  >
                    <option value="">Auto-detect</option>
                    {columnLabels.map((label, idx) => (
                      <option key={`cat-${idx}`} value={idx}>
                        {label}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <div className="text-[12px] font-semibold text-[color:var(--muted)]">
                    Status Column
                  </div>
                  <select
                    value={statusCol ?? ""}
                    onChange={(e) =>
                      setStatusCol(
                        e.target.value === "" ? null : Number(e.target.value)
                      )
                    }
                    className="mt-1 w-full rounded-xl bg-[var(--surface)] px-3 py-2 text-[13px] font-semibold border border-[color:var(--border)]"
                  >
                    <option value="">Auto-detect</option>
                    {columnLabels.map((label, idx) => (
                      <option key={`status-${idx}`} value={idx}>
                        {label}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="rounded-xl bg-[var(--background)] p-3 border border-[color:var(--border)]">
                <div className="text-[12px] font-semibold text-[color:var(--muted)]">
                  Preview
                </div>
                <div className="mt-2 space-y-2">
                  {preview.length ? (
                    preview.map((r, idx) => (
                      <div
                        key={`preview-${idx}`}
                        className="rounded-xl bg-[var(--surface)] px-3 py-2 border border-[color:var(--border)]"
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div className="min-w-0 flex-1">
                            <div className="text-[15px] font-semibold">{r.thai}</div>
                            {r.burmese ? (
                              <div className="mt-1 text-[13px] font-semibold text-[color:var(--muted-strong)]">
                                {r.burmese}
                              </div>
                            ) : null}
                            {r.category ? (
                              <div className="mt-2 text-[11px] font-semibold text-[color:var(--muted)]">
                                Category: {r.category}
                              </div>
                            ) : null}
                          </div>
                          <div className="shrink-0 text-right">
                            <div className="text-[16px] font-semibold tabular-nums">
                              {r.count}
                            </div>
                            <div className="text-[11px] font-semibold text-[color:var(--muted)]">
                              count
                            </div>
                            <div className="mt-2 text-[11px] font-semibold text-[color:var(--muted)]">
                              {r.status}
                            </div>
                          </div>
                        </div>
                      </div>
                    ))
                  ) : (
                    <div className="text-[13px] font-medium text-[color:var(--muted)]">
                      No preview rows yet.
                    </div>
                  )}
                </div>
              </div>
            </div>
          ) : null}

          {error ? (
            <div className="mt-4 rounded-xl bg-red-500/10 p-3 text-[13px] font-semibold text-red-600 ring-1 ring-red-500/20">
              {error}
            </div>
          ) : null}

          {success ? (
            <div className="mt-4 rounded-xl bg-green-500/10 p-3 text-[13px] font-semibold text-green-700 ring-1 ring-green-500/20">
              {success}
            </div>
          ) : null}

          <div className="mt-4 flex gap-3">
            <button
              type="button"
              onClick={runImport}
              disabled={!uid || isAnonymous || busy || !parsed}
              className="flex-1 rounded-xl bg-[color:var(--foreground)] px-4 py-3 text-[13px] font-semibold text-[color:var(--background)] shadow-sm hover:shadow-md transition-shadow disabled:opacity-40"
            >
              {busy ? "Importing…" : "Import into Firestore"}
            </button>

            <button
              type="button"
              onClick={runCleanReimport}
              disabled={!uid || isAnonymous || busy || !parsed}
              className="rounded-xl bg-[var(--surface)]/70 px-4 py-3 text-[13px] font-semibold text-[color:var(--foreground)] border border-[color:var(--border)] backdrop-blur-xl shadow-sm hover:shadow-md transition-shadow disabled:opacity-40"
            >
              Clean & Re-import
            </button>
          </div>

          {!uid || isAnonymous ? (
            <div className="mt-3 text-[12px] font-medium text-[color:var(--muted)]">
              Sign in required
            </div>
          ) : (
            <div className="mt-3 break-all text-[12px] font-medium text-[color:var(--muted)]">
              UID: {uid}
            </div>
          )}
        </motion.div>

        <div className="mt-4 text-center text-[12px] font-medium text-[color:var(--muted)]">
          After import, go back to Home to see your words.
        </div>
      </div>
      </div>
    </div>
  );
}
