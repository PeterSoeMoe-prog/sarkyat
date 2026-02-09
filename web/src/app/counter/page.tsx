"use client";

import Link from "next/link";
import { AnimatePresence, motion } from "framer-motion";
import { Suspense, useEffect, useMemo, useRef, useState, ReactNode } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { upsertVocabulary } from "@/lib/vocab/firestore";
import { generateThaiExplanation } from "@/lib/gemini";
import { getFirebaseAuth, getFirebaseDb } from "@/lib/firebase/client";
import { doc, updateDoc, serverTimestamp } from "firebase/firestore";

type TapParticle = {
  id: number;
  x: number;
  y: number;
  color: string;
};

function CounterPageInner() {
  const router = useRouter();
  const SOUND_LEVEL_KEY = "sar-kyat-sound-level";
  const TAP_TTS_MODE_KEY = "sar-kyat-tap-tts-mode";
  const GOOGLE_AI_API_KEY_STORAGE = "google_ai_studio_key";
  const AI_RATE_LIMIT_UNTIL_KEY = "sar-kyat-ai-rate-limit-until";
  const ghostBtn =
    "rounded-full bg-[var(--surface)]/50 px-4 py-2 text-[13px] font-semibold text-[color:var(--foreground)] backdrop-blur-xl border border-[color:var(--border)] shadow-sm hover:shadow-md transition-shadow";

  const { uid, isAnonymous, items, loading } = useVocabulary();
  const isAuthed = !!uid && !isAnonymous;
  const searchParams = useSearchParams();
  const selectedId = searchParams.get("id");

  const current = useMemo(() => {
    if (!isAuthed) return null;
    if (items.length === 0) return null;
    if (selectedId) {
      return items.find((it) => it.id === selectedId) ?? null;
    }
    return items[0] ?? null;
  }, [isAuthed, items, selectedId]);

  const [isEditing, setIsEditing] = useState(false);
  const [editThai, setEditThai] = useState("");
  const [editBurmese, setEditBurmese] = useState("");
  const [editCount, setEditCount] = useState(0);
  const [editStatus, setEditStatus] = useState<string>("learning");
  const [editCategory, setEditCategory] = useState("");

  useEffect(() => {
    if (current && isEditing) {
      setEditThai(current.thai?.toString() || "");
      setEditBurmese(current.burmese?.toString() || "");
      setEditCount(Number.isFinite(Number(current.count)) ? Number(current.count) : 0);
      setEditStatus(current.status?.toString() || "learning");
      setEditCategory(current.category?.toString() || "");
    }
  }, [current, isEditing]);

  const saveEdits = async () => {
    if (!uid || !current?.id) return;
    setStatusBusy(true);
    try {
      const db = getFirebaseDb();
      const docRef = doc(db, "users", uid, "vocabulary", current.id);
      await updateDoc(docRef, {
        thai: editThai,
        burmese: editBurmese,
        count: editCount,
        status: editStatus,
        category: editCategory,
        updatedAt: serverTimestamp(),
      });
      setIsEditing(false);
    } catch (err) {
      console.error("Error saving edits:", err);
    } finally {
      setStatusBusy(false);
    }
  };

  useEffect(() => {
    if (!current?.id) return;
    try {
      localStorage.setItem("sar-kyat-last-active-vocab-id", current.id);
    } catch {
      // ignore
    }
  }, [current?.id]);

  const categoryName = (current?.category?.toString().trim() || "Uncategorized").trim();
  const thai = current?.thai?.toString() || "";
  const burmese = current?.burmese?.toString() || "";
  const initialCount = Number.isFinite(Number(current?.count)) ? Number(current?.count) : 0;
  const status = (current?.status?.toString() || "").trim();

  const thaiLen = Array.from(thai.trim()).length;
  const thaiFontClass =
    thaiLen > 32 ? "text-[24px] sm:text-[28px]" : thaiLen > 20 ? "text-[32px] sm:text-[36px]" : "text-[42px] sm:text-[46px]";
  const [optimisticStatus, setOptimisticStatus] = useState<string | null>(null);
  const [statusBusy, setStatusBusy] = useState(false);
  const [incrementStep, setIncrementStep] = useState<1 | 2 | 5>(5);
  const [optimisticCount, setOptimisticCount] = useState<number | null>(null);
  const [count, setCount] = useState<number>(0);

  useEffect(() => {
    if (current) {
      setCount(Number.isFinite(Number(current.count)) ? Number(current.count) : 0);
    }
  }, [current]);

  const [countBusy, setCountBusy] = useState(false);
  const [soundLevel, setSoundLevel] = useState<0 | 1 | 2>(1);
  const [aiBusy, setAiBusy] = useState(false);
  const [aiError, setAiError] = useState<string | null>(null);
  const [aiDraft, setAiDraft] = useState<string | null>(null);
  const [aiForId, setAiForId] = useState<string | null>(null);
  const [aiDismissedId, setAiDismissedId] = useState<string | null>(null);
  const [aiSaving, setAiSaving] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const [ttsActive, setTtsActive] = useState<string | null>(null);
  const [ttsBusy, setTtsBusy] = useState(false);
  const lastAutoSpokenIdRef = useRef<string | null>(null);
  const [tapTtsMode, setTapTtsMode] = useState<"max" | "3" | "10" | "off">("off");
  const dogTapCountRef = useRef(0);
  const [dogHasWalked, setDogHasWalked] = useState(false);
  const [dogWalking, setDogWalking] = useState(false);
  const dogWalkTimeoutRef = useRef<number | null>(null);
  const [dogJump, setDogJump] = useState(false);
  const dogJumpTimeoutRef = useRef<number | null>(null);
  const [pulseKey, setPulseKey] = useState(0);
  const [particles, setParticles] = useState<TapParticle[]>([]);
  const particleIdRef = useRef(0);
  const particleTimeoutRef = useRef<number | null>(null);
  const [tapPopupText, setTapPopupText] = useState<string | null>(null);
  const [tapPopupKey, setTapPopupKey] = useState(0);
  const [streak, setStreak] = useState(0);
  const lastTapTimeRef = useRef<number | null>(null);
  const streakTimeoutRef = useRef<number | null>(null);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(SOUND_LEVEL_KEY);
      if (raw === "0" || raw === "1" || raw === "2") {
        setSoundLevel(Number(raw) as 0 | 1 | 2);
      }
    } catch {
      // ignore
    }
  }, []);

  useEffect(() => {
    try {
      const raw = (localStorage.getItem(TAP_TTS_MODE_KEY) ?? "").trim();
      if (raw === "max" || raw === "3" || raw === "10" || raw === "off") {
        setTapTtsMode(raw);
      }
    } catch {
      // ignore
    }
  }, []);

  useEffect(() => {
    dogTapCountRef.current = 0;
  }, [current?.id]);

  useEffect(() => {
    return () => {
      if (dogWalkTimeoutRef.current != null) window.clearTimeout(dogWalkTimeoutRef.current);
      if (dogJumpTimeoutRef.current != null) window.clearTimeout(dogJumpTimeoutRef.current);
      if (particleTimeoutRef.current != null) window.clearTimeout(particleTimeoutRef.current);
      if (streakTimeoutRef.current != null) window.clearTimeout(streakTimeoutRef.current);
    };
  }, []);

  const setTapMode = (mode: "max" | "3" | "10" | "off") => {
    setTapTtsMode(mode);
    try {
      localStorage.setItem(TAP_TTS_MODE_KEY, mode);
    } catch {}

    if (mode === "off") {
      setSoundLevel(0);
      try {
        localStorage.setItem(SOUND_LEVEL_KEY, "0");
      } catch {}
    } else if (soundLevel === 0) {
      setSoundLevel(1);
      try {
        localStorage.setItem(SOUND_LEVEL_KEY, "1");
      } catch {}
    }
  };

  const triggerParticles = () => {
    if (!thai.trim()) return;
    const colors = ["#60A5FA", "#49D2FF", "#2CE08B", "#FFB020", "#FF4D6D", "#B36BFF"];
    const count = 18;
    const next: TapParticle[] = [];
    for (let i = 0; i < count; i++) {
      const baseAngle = (Math.PI * 2 * i) / count;
      const jitter = (Math.random() - 0.5) * 0.6;
      const angle = baseAngle + jitter;
      const distance = 80 + Math.random() * 80;
      next.push({
        id: particleIdRef.current++,
        x: Math.cos(angle) * distance,
        y: Math.sin(angle) * distance,
        color: colors[i % colors.length],
      });
    }
    setParticles(next);
    if (particleTimeoutRef.current != null) window.clearTimeout(particleTimeoutRef.current);
    particleTimeoutRef.current = window.setTimeout(() => setParticles([]), 700);
  };

  const handleCircleTap = () => {
    if (!isAuthed || !uid || !current || countBusy) return;
    void incrementCount();

    const now = Date.now();
    setStreak((prev) => {
      const last = lastTapTimeRef.current ?? 0;
      const withinCombo = now - last < 800;
      const next = withinCombo ? (prev || 0) + 1 : 1;
      lastTapTimeRef.current = now;
      return next;
    });

    setTapPopupText("+" + incrementStep);
    setTapPopupKey((k) => k + 1);
    if (streakTimeoutRef.current != null) window.clearTimeout(streakTimeoutRef.current);
    streakTimeoutRef.current = window.setTimeout(() => {
      setStreak(0);
      setTapPopupText(null);
    }, 1400);

    triggerParticles();
    setPulseKey((k) => k + 1);
    
    if (tapTtsMode === "off" || soundLevel === 0) return;
    const every = tapTtsMode === "max" ? 1 : tapTtsMode === "3" ? 3 : 10;
    if (dogTapCountRef.current % every === 0) {
      void playThaiTts(thai, current?.id ? "main-" + current.id + "-" + dogTapCountRef.current : "main");
    }
  };

  const openGoogleImages = () => {
    const q = thai.trim();
    if (!q) return;
    if (typeof window !== "undefined") window.open("https://www.google.com/search?tbm=isch&q=" + encodeURIComponent(q), "_blank", "noopener,noreferrer");
  };

  const openGoogleTranslate = () => {
    const q = thai.trim();
    if (!q) return;
    if (typeof window !== "undefined") window.open("https://translate.google.com/?sl=th&tl=my&text=" + encodeURIComponent(q) + "&op=translate", "_blank", "noopener,noreferrer");
  };

  const tapTtsIcon = tapTtsMode === "max" ? "🔊" : tapTtsMode === "3" ? "🔉" : tapTtsMode === "10" ? "🔈" : "🔇";
  const tapTtsBadge = tapTtsMode === "3" ? "3" : tapTtsMode === "10" ? "10" : null;
  const cycleTapMode = () => {
    const order: Array<"max" | "3" | "10" | "off"> = ["max", "3", "10", "off"];
    const idx = order.indexOf(tapTtsMode);
    setTapMode(order[(idx + 1) % order.length] ?? "off");
  };

  useEffect(() => {
    setOptimisticCount(null);
    setCountBusy(false);
    setAiBusy(false);
    setAiError(null);
    setAiDraft(null);
    setAiForId(null);
    setAiDismissedId(null);
    setAiSaving(false);
    setTtsActive(null);
    setTtsBusy(false);
  }, [current?.id]);

  const effectiveCount = optimisticCount ?? count;
  const statusIcon = status === "ready" ? "💎" : status === "queue" ? "😮" : "🔥";

  const cycleStatus = async () => {
    if (!isAuthed || !uid || !current || statusBusy) return;
    const cur = (current.status ?? "queue").toString();
    const next = cur === "drill" ? "queue" : cur === "queue" ? "ready" : "drill";
    setOptimisticStatus(next);
    setStatusBusy(true);
    try {
      await upsertVocabulary(uid, { ...current, status: next as any });
    } finally {
      setStatusBusy(false);
      setOptimisticStatus(null);
    }
  };

  const cycleStep = () => {
    const order: Array<1 | 2 | 5> = [1, 2, 5];
    setIncrementStep((prev) => order[(order.indexOf(prev) + 1) % order.length] ?? 5);
  };

  const incrementCount = async () => {
    if (!isAuthed || !uid || !current || countBusy) return;
    const base = Number.isFinite(Number(current.count)) ? Number(current.count) : 0;
    const next = base + incrementStep;
    setOptimisticCount(next);
    setCountBusy(true);
    try {
      await upsertVocabulary(uid, { ...current, count: next });
    } finally {
      setCountBusy(false);
    }
  };

  const decrementCount = async () => {
    if (!isAuthed || !uid || !current || countBusy) return;
    const base = Number.isFinite(Number(current.count)) ? Number(current.count) : 0;
    const next = Math.max(0, base - incrementStep);
    setOptimisticCount(next);
    setCountBusy(true);
    try {
      await upsertVocabulary(uid, { ...current, count: next });
    } finally {
      setCountBusy(false);
    }
  };

  const categoryTotals = useMemo(() => {
    if (!isAuthed || !current) return { notReady: 0, total: 0 };
    const cat = categoryName;
    const inCat = items.filter((it) => (it.category?.toString().trim() || "Uncategorized").trim() === cat);
    return { notReady: inCat.filter((it) => it.status !== "ready").length, total: inCat.length };
  }, [isAuthed, items, current, categoryName]);

  const allCategories = useMemo(() => Array.from(new Set(items.map((it) => (it.category?.toString().trim() || "Uncategorized").trim()))).sort(), [items]);

  const thaiColors = ["#49D2FF", "#B36BFF", "#FF4D6D", "#FFB000", "#22C55E", "#60A5FA"];

  const readGoogleAiKey = () => { try { return (localStorage.getItem(GOOGLE_AI_API_KEY_STORAGE) ?? "").trim(); } catch { return ""; } };
  const readAiRateLimitUntil = () => { try { const raw = (localStorage.getItem(AI_RATE_LIMIT_UNTIL_KEY) ?? "").trim(); const ms = Number(raw); return Number.isFinite(ms) ? ms : 0; } catch { return 0; } };
  const writeAiRateLimitUntil = (ms: number) => { try { localStorage.setItem(AI_RATE_LIMIT_UNTIL_KEY, String(ms)); } catch {} };

  const playThaiTts = async (text: string, activeKey?: string) => {
    const cleaned = String(text ?? "").trim();
    if (!cleaned || !isAuthed || soundLevel === 0 || ttsBusy) return;
    const key = activeKey ?? cleaned;
    setTtsActive(key);
    setTtsBusy(true);
    try {
      const auth = getFirebaseAuth();
      const token = await auth.currentUser?.getIdToken();
      if (!token) throw new Error("Not signed in");
      if (audioRef.current) try { audioRef.current.pause(); } catch {}
      audioRef.current = null;
      const res = await fetch("/api/tts", { method: "POST", headers: { "Content-Type": "application/json", Authorization: "Bearer " + token }, body: JSON.stringify({ text: cleaned }) });
      if (!res.ok) throw new Error("TTS failed");
      const buf = await res.arrayBuffer();
      const url = URL.createObjectURL(new Blob([buf], { type: "audio/mpeg" }));
      const audio = new Audio(url);
      audio.volume = soundLevel === 2 ? 1 : 0.65;
      audioRef.current = audio;
      audio.onended = () => { try { URL.revokeObjectURL(url); } catch {} };
      await audio.play();
    } catch {} finally {
      setTimeout(() => setTtsActive((prev) => prev === key ? null : prev), 160);
      setTtsBusy(false);
    }
  };

  const renderExplainLine = (line: string, lineKey: string) => {
    const trimmed = String(line ?? "");
    if (!trimmed) return null;
    if (trimmed.startsWith("ဝါကျ -")) {
      const rest = trimmed.slice("ဝါကျ -".length).trim();
      const sep = rest.indexOf(" (");
      const thaiSentence = (sep >= 0 ? rest.slice(0, sep) : rest).trim();
      const burmesePart = sep >= 0 ? rest.slice(sep).trim() : "";
      return (
        <div key={lineKey} className="text-[13px] leading-6 font-semibold text-white/80">
          <span className="text-white/80">ဝါကျ - </span>
          <button type="button" onClick={() => void playThaiTts(thaiSentence, lineKey + "-thai")} disabled={!isAuthed || ttsBusy} className={"bg-transparent text-inherit text-left transition-opacity " + (ttsActive === lineKey + "-thai" ? "opacity-70" : "opacity-100")}>{thaiSentence}</button>
          {burmesePart ? <span className="text-white/70"> {burmesePart}</span> : null}
        </div>
      );
    }
    if (trimmed.startsWith("ဖွဲ့စည်းပုံ -")) {
      const parts: ReactNode[] = [];
      const bracketRe = /\[([^\]]+)\]/g;
      let last = 0, m;
      while ((m = bracketRe.exec(trimmed)) !== null) {
        const before = trimmed.slice(last, m.index);
        if (before) parts.push(<span key={lineKey + "-b-" + last}>{before}</span>);
        const inside = String(m[1] ?? ""), speak = (inside.match(/[\u0E00-\u0E7F]+/g) ?? []).join("").trim() || inside.trim();
        const thisKey = lineKey + "-br-" + m.index;
        parts.push(<button key={thisKey} type="button" onClick={() => void playThaiTts(speak, thisKey)} disabled={!isAuthed || ttsBusy} className={"bg-transparent text-inherit text-left transition-opacity " + (ttsActive === thisKey ? "opacity-70" : "opacity-100")}>[{inside}]</button>);
        last = m.index + m[0].length;
      }
      const after = trimmed.slice(last);
      if (after) parts.push(<span key={lineKey + "-a-" + last}>{after}</span>);
      return <div key={lineKey} className="text-[13px] leading-6 font-semibold text-white/80">{parts}</div>;
    }
    const thaiMatch = trimmed.match(/[\u0E00-\u0E7F]+/);
    if (thaiMatch?.index != null) {
      const i = thaiMatch.index, thaiWord = thaiMatch[0], before = trimmed.slice(0, i), after = trimmed.slice(i + thaiWord.length), thisKey = lineKey + "-thaiword";
      return (
        <div key={lineKey} className="text-[13px] leading-6 font-semibold text-white/80">
          {before ? <span>{before}</span> : null}
          <button type="button" onClick={() => void playThaiTts(thaiWord, thisKey)} disabled={!isAuthed || ttsBusy} className={"bg-transparent text-inherit text-left transition-opacity " + (ttsActive === thisKey ? "opacity-70" : "opacity-100")}>{thaiWord}</button>
          {after ? <span>{after}</span> : null}
        </div>
      );
    }
    return <div key={lineKey} className="text-[13px] leading-6 font-semibold text-white/80">{trimmed}</div>;
  };

  const renderAiExplain = (text: string) => {
    const lines = String(text ?? "").split(/\r?\n/).map((l) => l.trim()).filter((l) => l.length > 0);
    return <div className="space-y-2">{lines.map((line, idx) => renderExplainLine(line, "ai-" + idx))}</div>;
  };

  const startAutoExplain = async () => {
    if (!isAuthed || !uid || !current || (current.ai_explanation && String(current.ai_explanation).trim().length > 0) || aiDismissedId === current.id || aiBusy || aiSaving || (aiForId === current.id && (aiDraft || aiError))) return;
    const until = readAiRateLimitUntil(), now = Date.now();
    if (until > now) {
      const secs = Math.max(1, Math.ceil((until - now) / 1000));
      setAiError("ယနေ့ Limit ပြည့်သွားပါ၍ " + secs + " စက္ကန့်မှ ပြန်ကြည့်ပေးပါ။");
      setAiForId(current.id);
      return;
    }
    const apiKey = readGoogleAiKey();
    if (!apiKey) {
      setAiError("Missing API key. Add it in Settings.");
      setAiDraft(null); setAiForId(current.id);
      return;
    }
    setAiBusy(true); setAiError(null); setAiDraft(null); setAiForId(current.id);
    try {
      const text = await generateThaiExplanation(apiKey, thai, burmese);
      setAiDraft(text);
    } catch (e: any) {
      const raw = (e?.message ? String(e.message) : "AI request failed").trim();
      if (raw.startsWith("RATE_LIMIT:")) {
        const m = raw.match(/retry_after=(\d+)s/i), seconds = m?.[1] ? Number(m[1]) : 60;
        writeAiRateLimitUntil(Date.now() + seconds * 1000);
        setAiError("ယနေ့ Limit ပြည့်သွားပါ၍ " + seconds + " စက္ကန့်မှ ပြန်ကြည့်ပေးပါ။");
      } else setAiError(raw);
    } finally { setAiBusy(false); }
  };

  const confirmAndSaveAi = async () => {
    if (!isAuthed || !uid || !current || !aiDraft || !aiDraft.trim().length || aiSaving) return;
    setAiSaving(true);
    try {
      await upsertVocabulary(uid, { ...current, ai_explanation: aiDraft.trim() });
      setAiDraft(null); setAiError(null);
    } catch (e: any) {
      setAiError((e?.message ? String(e.message) : "Save failed").trim());
    } finally { setAiSaving(false); }
  };

  useEffect(() => { void startAutoExplain(); }, [current?.id, isAuthed]);
  useEffect(() => {
    if (!current?.id || !thai.trim() || !isAuthed || soundLevel === 0 || lastAutoSpokenIdRef.current === current.id) return;
    lastAutoSpokenIdRef.current = current.id;
    void playThaiTts(thai, "main-" + current.id);
  }, [current?.id, isAuthed, soundLevel]);

  const showAiExplain = current?.ai_explanation || (current?.id && aiDismissedId !== current.id && (aiBusy || aiError || aiDraft));

  return (
    <div className="min-h-screen bg-[#0A0B0F] text-white">
      <div className="min-h-screen">
        <div className="mx-auto w-full max-w-md px-4 pt-4 pb-4 min-h-[100dvh] flex flex-col">
          <div className="origin-top flex-1 min-h-0 flex flex-col">
            <header className="grid grid-cols-3 items-center">
              <div className="justify-self-start">
                <button type="button" disabled={!isAuthed || !current} onClick={() => { if (isAuthed && current) router.push("/category?cat=" + encodeURIComponent(categoryName) + "&from=counter&id=" + encodeURIComponent(current.id)); }} className={"text-[16px] font-semibold text-white/85 " + (!isAuthed || !current ? "opacity-60" : "opacity-100")}>{categoryName} {isAuthed && <span className="text-white/70">({categoryTotals.notReady}/{Math.max(1, categoryTotals.total)})</span>}</button>
              </div>
              <div className="justify-self-center">
                <div className="flex items-center gap-2">
                  <button type="button" onClick={openGoogleImages} className="h-[34px] w-[34px] rounded-full border-2 border-white/80 bg-[#2CE08B] flex items-center justify-center text-[12px] font-semibold active:scale-95 transition-transform">G</button>
                  <button type="button" onClick={openGoogleTranslate} className="h-[34px] w-[34px] rounded-full border-2 border-white/80 bg-[#FF4D94] flex items-center justify-center text-[12px] font-semibold active:scale-95 transition-transform">T</button>
                </div>
              </div>
              <div className="justify-self-end flex items-center gap-3">
                <button onClick={() => setIsEditing(!isEditing)} className="text-[16px] font-semibold text-[#4FD2FF]">{isEditing ? "Cancel" : "Edit"}</button>
                {!isEditing && <Link href="/" className="text-[20px] font-medium text-white/60">✕</Link>}
              </div>
            </header>

            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="mt-4 flex-1 flex flex-col">
              {!isAuthed ? <div className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3">Sign in required</div> : loading ? <div className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3">Loading…</div> : isEditing ? (
                <div className="flex-1 flex flex-col gap-4 mt-2">
                  <div className="space-y-4 px-2 overflow-y-auto pb-4">
                    <div className="space-y-1"><label className="text-[11px] font-bold uppercase text-white/40 ml-1">Thai</label><textarea value={editThai} onChange={(e) => setEditThai(e.target.value)} className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3 text-[16px] min-h-[80px] resize-none" /></div>
                    <div className="space-y-1"><label className="text-[11px] font-bold uppercase text-white/40 ml-1">Burmese</label><textarea value={editBurmese} onChange={(e) => setEditBurmese(e.target.value)} className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3 text-[16px] min-h-[80px] resize-none" /></div>
                    <div className="grid grid-cols-2 gap-3">
                      <div className="space-y-1"><label className="text-[11px] font-bold uppercase text-white/40 ml-1">Category</label><input value={editCategory} onChange={(e) => setEditCategory(e.target.value)} list="category-suggestions" className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3 text-[15px]" /><datalist id="category-suggestions">{allCategories.map(c => <option key={c} value={c} />)}</datalist></div>
                      <div className="space-y-1"><label className="text-[11px] font-bold uppercase text-white/40 ml-1">Count</label><input type="number" value={editCount} onChange={(e) => setEditCount(Number(e.target.value))} className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3 text-[15px]" /></div>
                    </div>
                    <div className="space-y-1"><label className="text-[11px] font-bold uppercase text-white/40 ml-1">Status</label><div className="flex gap-2 mb-2">{(["ready", "queue", "drill"] as const).map(s => <button key={s} onClick={() => setEditStatus(s)} className={"flex-1 py-3 rounded-xl border " + (editStatus === s ? "bg-white/20 border-white/40" : "bg-white/5 border-white/10")}><span className="text-[28px]">{s === "ready" ? "💎" : s === "queue" ? "😮" : "🔥"}</span></button>)}</div></div>
                    <button onClick={saveEdits} disabled={statusBusy} className="w-full py-4 rounded-2xl bg-gradient-to-r from-[#60A5FA] to-[#B36BFF] text-white font-black text-[16px]">{statusBusy ? "Saving..." : "Save Changes"}</button>
                  </div>
                </div>
              ) : !current ? <div className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3">{items.length ? "Word not found" : "No words yet"}</div> : (
                <>
                  <div className="mx-auto w-full max-w-[90%] px-3 text-center -mt-[20px]">
                    <AnimatePresence mode="wait" initial={false}>
                      <motion.button key={current.id} type="button" onClick={() => void playThaiTts(thai, "main-" + current.id)} disabled={ttsBusy} className={"bg-transparent font-semibold tracking-[-0.02em] transition-opacity whitespace-normal break-words leading-snug " + thaiFontClass + (ttsActive === "main-" + current.id ? " opacity-75" : " opacity-100")} initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -12 }}>
                        {Array.from(thai).map((ch, i) => <span key={i} style={{ color: thaiColors[i % thaiColors.length] }}>{ch}</span>)}
                      </motion.button>
                    </AnimatePresence>
                    {burmese && <div className="mt-1 text-[18px] sm:text-[20px] font-semibold text-[#F5C542]">{burmese}</div>}
                  </div>
                  <div className="mt-3">
                    <div className="flex items-start justify-between">
                      <button type="button" onClick={() => void cycleStatus()} disabled={statusBusy} className={"flex h-[72px] w-[72px] items-center justify-center text-[53px] " + (statusBusy ? "opacity-55" : "opacity-100")}>{statusIcon}</button>
                      <div className="flex-1 text-center -mt-[20px]"><div className="inline-flex items-start gap-2"><motion.div key={effectiveCount} initial={{ scale: 1 }} animate={pulseKey > 0 ? { scale: [1, 1.15, 1] } : {}} className="bg-gradient-to-r from-[#60A5FA] via-[#B36BFF] to-[#FF4D6D] bg-clip-text text-transparent text-[65px] sm:text-[76px] font-black leading-none mt-[10px]">{effectiveCount.toLocaleString()}{tapPopupText && <div className="pointer-events-none absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-50"><AnimatePresence mode="wait"><motion.div key={tapPopupKey} initial={{ opacity: 0, y: 140, scale: 0.5 }} animate={{ opacity: 1, x: 140, y: -50, scale: 2.5, rotate: 15 }} exit={{ opacity: 0, x: 180, y: -110, scale: 1.5 }} className="font-black text-white drop-shadow-[0_0_15px_rgba(255,122,0,0.8)] text-[24px]"><span className="text-[14px] mt-1 mr-0.5 font-black">+</span>{tapPopupText.replace('+', '')}</motion.div></AnimatePresence></div>}</motion.div></div></div>
                      <div className="flex w-[74px] flex-col items-center gap-3">
                        <button type="button" onClick={cycleStep} className="h-[68px] w-[68px] rounded-full p-[3px] bg-white/20"><div className="h-full w-full rounded-full border-[3px] border-white/90 bg-gradient-to-br from-[#FF4D6D] to-[#FF7A00] flex items-center justify-center relative"><span className="absolute top-[10px] left-[12px] text-[14px] font-black">+</span><span className="text-[34px] font-black">{incrementStep}</span></div></button>
                        <button type="button" onClick={cycleTapMode} className="relative h-[42px] w-[42px] rounded-full border bg-white/10 flex items-center justify-center text-[16px]">{tapTtsIcon}{tapTtsBadge && <div className="absolute -right-1 -bottom-1 h-[16px] min-w-[16px] rounded-full bg-white/90 text-[10px] font-semibold text-black">{tapTtsBadge}</div>}</button>
                      </div>
                    </div>
                    <div className="relative -mt-9 sm:-mt-10 flex items-center justify-center">
                      <div className="relative w-full max-w-[300px]">
                        <motion.div className="relative w-full aspect-square rounded-full border-[6px] border-white/90 overflow-hidden shadow-[0_0_80px_rgba(96,165,250,0.5)]" onClick={handleCircleTap} style={{ background: "conic-gradient(from 0deg, #00F2FF, #006AFF, #7000FF, #FF00C8, #FF0032, #FF8A00, #00F2FF)" }} whileTap={{ scale: 0.94 }}>
                          <motion.div className="absolute inset-0" animate={{ rotate: [0, 360] }} transition={{ duration: 4, repeat: Infinity, ease: "linear" }} style={{ background: "conic-gradient(from 0deg, transparent, rgba(255,255,255,0.5), transparent)" }} />
                          <div className="absolute inset-0 rounded-full bg-black/10 backdrop-blur-[2px]" />
                          <div className="absolute inset-0 overflow-visible pointer-events-none">{particles.map(p => <AnimatePresence key={p.id}><motion.span className="absolute h-[12px] w-[12px] rounded-full" style={{ backgroundColor: p.color, boxShadow: "0 0 25px " + p.color }} initial={{ x: 0, y: 0, opacity: 1 }} animate={{ x: p.x * 2.8, y: p.y * 2.8, opacity: 0, scale: 0.3 }} transition={{ duration: 0.9 }} /></AnimatePresence>)}</div>
                        </motion.div>
                        <div className="absolute bottom-[5px] right-[5px] z-30"><button type="button" onClick={(e) => { e.stopPropagation(); if (isAuthed && current && !countBusy) decrementCount(); }} className="h-[72px] w-[72px] sm:h-[82px] sm:w-[82px] rounded-full border-4 border-white/90 bg-gradient-to-br from-[#FF4D6D] to-[#FF7A00] flex items-center justify-center text-[30px] sm:text-[36px] font-black text-white">↓</button></div>
                      </div>
                    </div>
                    <div className="mt-auto pt-5"><div className="w-full rounded-2xl border border-white/20 bg-black/40 px-4 py-3 flex items-center justify-between text-[11px] font-semibold h-[60px] relative"><div className="z-10 text-white/60">To Hit</div><div className="z-10 text-white/45">For Apr 7, 2025</div><div className="absolute inset-0 flex items-center justify-center text-[50px] font-semibold bg-gradient-to-r from-[#60A5FA] to-[#FF4D6D] bg-clip-text text-transparent">240</div></div></div>
                    {showAiExplain && (
                      <div className="mt-6 w-full flex flex-col">
                        <div className="px-1 mb-2"><h3 className="text-[14px] font-bold text-white/90">ရှင်းလင်းချက်</h3></div>
                        <div className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-4 flex flex-col max-h-[70vh]">
                          <div className="flex items-center justify-between">
                            <button onClick={() => setIsEditing(!isEditing)} className="text-[14px] font-semibold text-[#60A5FA]">Edit</button>
                            {!current.ai_explanation && <button type="button" onClick={() => { setAiDraft(null); setAiError(null); setAiDismissedId(current.id); }} className={ghostBtn}>Close</button>}
                          </div>
                          <div className="mt-3 flex-1 overflow-y-auto pb-[100px]">
                            {current.ai_explanation ? <div>{renderAiExplain(String(current.ai_explanation))}</div> : aiBusy ? <div className="text-white/60">Generating…</div> : aiError ? <div className="text-red-200">{aiError} <button onClick={() => void startAutoExplain()} className="underline">Retry</button></div> : aiDraft ? <div className="space-y-4"><div>{renderAiExplain(aiDraft)}</div><div className="flex gap-3"><button onClick={() => setAiDraft(null)} className={ghostBtn}>Discard</button><button onClick={confirmAndSaveAi} disabled={aiSaving} className="flex-1 py-3 rounded-xl bg-[#2CE08B] text-black font-black">Keep this Explanation</button></div></div> : null}
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                </>
              )}
            </motion.div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function CounterPage() { return <Suspense fallback={<div className="min-h-screen bg-[#0A0B0F] text-white" />}><CounterPageInner /></Suspense>; }
