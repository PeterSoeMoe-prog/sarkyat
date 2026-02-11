"use client";

import { useEffect, useState, useMemo, useRef, useCallback } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { motion } from "framer-motion";
import {
  LucideChevronLeft,
  LucideSave,
  LucidePencil,
  LucideLayers,
  LucideMinus,
  LucidePlus,
  LucideFlame,
  LucideGem,
} from "lucide-react";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { fetchSession, updateSession, fetchBook } from "@/lib/vocab/firestore";
import type { BookEntry, BookSession, SessionStatus } from "@/lib/vocab/types";

export default function SessionDetailClient() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const bookId = searchParams.get("bookId") ?? "";
  const sessionId = searchParams.get("sessionId") ?? "";
  const { uid } = useVocabulary();

  const [book, setBook] = useState<BookEntry | null>(null);
  const [session, setSession] = useState<BookSession | null>(null);
  const [note, setNote] = useState("");
  const [name, setName] = useState("");
  const [order, setOrder] = useState<number>(1);
  const [status, setStatus] = useState<SessionStatus>("drill");
  const [saving, setSaving] = useState(false);
  const [orderSaving, setOrderSaving] = useState(false);
  const noteRef = useRef<HTMLTextAreaElement | null>(null);
  const isReady = status === "ready";

  const autoSizeNote = useCallback(() => {
    const el = noteRef.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${Math.min(el.scrollHeight, 2000)}px`;
  }, []);

  useEffect(() => {
    if (!uid || !bookId || !sessionId) return;
    fetchBook(uid, bookId).then(setBook);
    fetchSession(uid, bookId, sessionId).then((s) => {
      setSession(s);
      setName(s?.name ?? "");
      setNote(s?.note ?? "");
      setOrder(Number.isFinite(s?.order) ? (s?.order as number) : 1);
      setStatus(s?.status === "ready" ? "ready" : "drill");
      requestAnimationFrame(autoSizeNote);
    });
  }, [uid, bookId, sessionId, autoSizeNote]);

  useEffect(() => {
    autoSizeNote();
  }, [note, autoSizeNote]);

  const isDirty = useMemo(() => {
    return (
      (session?.note ?? "") !== note ||
      (session?.name ?? "") !== name ||
      (session?.order ?? 1) !== order ||
      (session?.status ?? "drill") !== status
    );
  }, [session, note, name, order, status]);

  const persistOrder = async (next: number) => {
    if (!uid || !bookId || !sessionId) return;
    const clamped = Math.max(0, Math.min(9999, Math.round(next)));
    setOrder(clamped);
    setOrderSaving(true);
    try {
      await updateSession(uid, bookId, sessionId, { order: clamped });
      setSession((prev) => (prev ? { ...prev, order: clamped } : prev));
    } catch (e) {
      console.error(e);
      alert("Failed to save order. Please try again.");
    } finally {
      setOrderSaving(false);
    }
  };

  const handleSave = async () => {
    if (!uid || !bookId || !sessionId) return;
    setSaving(true);
    try {
      await updateSession(uid, bookId, sessionId, {
        name: name.trim() || "Untitled Session",
        note: note.slice(0, 1000),
        order,
        status,
      });
      setSession((prev) =>
        prev
          ? { ...prev, name: name.trim() || "Untitled Session", note: note.slice(0, 1000), order, status }
          : prev
      );
    } catch (e) {
      console.error(e);
      alert("Failed to save session. Please try again.");
    } finally {
      setSaving(false);
    }
  };

  const toggleStatus = () => {
    setStatus((prev) => (prev === "ready" ? "drill" : "ready"));
  };

  if (!bookId || !sessionId) {
    return (
      <div className="min-h-screen bg-[#0A0B0F] text-white flex items-center justify-center">
        <p className="text-white/40 font-bold">Missing book/session id.</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0A0B0F] text-white">
      <header className="px-4 pt-[calc(env(safe-area-inset-top)+10px)] pb-4 border-b border-white/5 bg-black/20 backdrop-blur-xl sticky top-0 z-50">
        <div className="max-w-md mx-auto flex items-center justify-between w-full">
          <button
            onClick={() => router.push(`/pages/detail/?id=${encodeURIComponent(bookId)}`)}
            className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 active:scale-95 transition-all"
            type="button"
          >
            <LucideChevronLeft size={20} />
          </button>
          <div className="flex flex-col items-center flex-1 px-4 min-w-0">
            <h1 className="text-[16px] font-black tracking-tight truncate w-full text-center">
              {book?.name || "Session"}
            </h1>
            <p className="text-[11px] font-bold text-white/40 truncate w-full text-center">
              {session?.name || "Vocabulary List"}
            </p>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => {
                const next = prompt("Edit session name", name);
                if (next !== null) setName(next);
              }}
              className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 active:scale-95 transition-all"
              type="button"
              aria-label="Edit session name"
            >
              <LucidePencil size={18} />
            </button>
            <button
              onClick={handleSave}
              disabled={!isDirty || saving}
              className="h-10 w-10 flex items-center justify-center rounded-full bg-[#10B981]/20 text-[#10B981] active:scale-95 transition-all disabled:opacity-40"
              type="button"
              aria-label="Save"
            >
              <LucideSave size={18} />
            </button>
          </div>
        </div>
      </header>

      <main className="p-4 max-w-md mx-auto pb-32 space-y-4">
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-[#1A1B23] border border-white/5 rounded-[24px] p-5"
        >
          <div className="flex items-center gap-3 mb-4">
            <div className="h-12 w-12 rounded-xl bg-gradient-to-br from-[#10B981]/20 to-[#3B82F6]/20 flex items-center justify-center border border-white/5">
              <LucideLayers size={22} className="text-[#10B981]" />
            </div>
            <div className="min-w-0">
              <p className="text-[12px] font-bold text-white/40 uppercase tracking-widest mb-1">Session</p>
              <p className="text-[16px] font-black text-white truncate">{name || "Untitled Session"}</p>
            </div>
            <button
              type="button"
              onClick={toggleStatus}
              className={`h-10 w-10 flex items-center justify-center rounded-xl border transition-all active:scale-95 ${
                isReady
                  ? "bg-[#10B981]/20 border-[#10B981]/35 text-[#34D399]"
                  : "bg-[#F59E0B]/20 border-[#F59E0B]/35 text-[#FCD34D]"
              }`}
              aria-label={`Toggle status. Current: ${isReady ? "ready" : "drill"}`}
              title={`Tap to change status (${isReady ? "ready" : "drill"})`}
            >
              {isReady ? <LucideGem size={16} /> : <LucideFlame size={16} />}
            </button>
            <div className="ml-auto flex items-center gap-2 bg-white/5 border border-white/10 rounded-2xl px-3 py-2">
              <button
                onClick={() => persistOrder(order - 1)}
                className="h-8 w-8 flex items-center justify-center rounded-xl bg-white/5 active:scale-95 transition-all disabled:opacity-40"
                type="button"
                aria-label="Decrease order"
                disabled={orderSaving}
              >
                <LucideMinus size={16} />
              </button>
              <div className="min-w-[36px] text-center">
                <span className="text-[16px] font-black text-white">{order}</span>
              </div>
              <button
                onClick={() => persistOrder(order + 1)}
                className="h-8 w-8 flex items-center justify-center rounded-xl bg-white/5 active:scale-95 transition-all disabled:opacity-40"
                type="button"
                aria-label="Increase order"
                disabled={orderSaving}
              >
                <LucidePlus size={16} />
              </button>
            </div>
          </div>

          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <label className="text-[12px] font-bold uppercase text-white/40">Notes</label>
              <span className="text-[11px] font-bold text-white/30">{note.length}/1000</span>
            </div>
            <textarea
              ref={noteRef}
              value={note}
              onChange={(e) => setNote(e.target.value.slice(0, 1000))}
              placeholder="Add up to 1000 characters..."
              className="w-full rounded-2xl bg-white/5 border border-white/10 px-4 py-3 text-[15px] outline-none focus:border-white/20 transition-colors resize-none"
              style={{ minHeight: 320, overflow: "hidden" }}
            />
            <p className="text-[11px] text-white/30">
              Tap save to sync changes. Notes are stored securely with your session.
            </p>
          </div>
        </motion.div>
      </main>
    </div>
  );
}
