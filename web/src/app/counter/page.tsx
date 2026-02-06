"use client";

import Link from "next/link";
import { AnimatePresence, motion } from "framer-motion";
import { Suspense, useEffect, useMemo, useRef, useState, ReactNode } from "react";
import { useRouter } from "next/navigation";
import { useSearchParams } from "next/navigation";
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
  const GOOGLE_AI_API_KEY_STORAGE = "sar-kyat-google-ai-api-key";
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
      if (dogWalkTimeoutRef.current != null) {
        window.clearTimeout(dogWalkTimeoutRef.current);
      }
      if (dogJumpTimeoutRef.current != null) {
        window.clearTimeout(dogJumpTimeoutRef.current);
      }
      if (particleTimeoutRef.current != null) {
        window.clearTimeout(particleTimeoutRef.current);
      }
      if (streakTimeoutRef.current != null) {
        window.clearTimeout(streakTimeoutRef.current);
      }
    };
  }, []);

  const setTapMode = (mode: "max" | "3" | "10" | "off") => {
    setTapTtsMode(mode);
    try {
      localStorage.setItem(TAP_TTS_MODE_KEY, mode);
    } catch {
      // ignore
    }

    if (mode === "off") {
      setSoundLevel(0);
      try {
        localStorage.setItem(SOUND_LEVEL_KEY, "0");
      } catch {
        // ignore
      }
    } else if (soundLevel === 0) {
      setSoundLevel(1);
      try {
        localStorage.setItem(SOUND_LEVEL_KEY, "1");
      } catch {
        // ignore
      }
    }
  };

  const triggerDogWalk = () => {
    if (dogHasWalked) return;
    setDogHasWalked(true);
    setDogWalking(true);
    if (dogWalkTimeoutRef.current != null) {
      window.clearTimeout(dogWalkTimeoutRef.current);
    }
    dogWalkTimeoutRef.current = window.setTimeout(() => {
      setDogWalking(false);
    }, 1200);
  };

  const triggerDogJump = () => {
    if (dogJumpTimeoutRef.current != null) {
      window.clearTimeout(dogJumpTimeoutRef.current);
    }
    setDogJump(true);
    dogJumpTimeoutRef.current = window.setTimeout(() => {
      setDogJump(false);
    }, 260);
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
    if (particleTimeoutRef.current != null) {
      window.clearTimeout(particleTimeoutRef.current);
    }
    particleTimeoutRef.current = window.setTimeout(() => {
      setParticles([]);
    }, 700);
  };

  const playTapFeedback = () => {
    if (typeof window === "undefined") return;
    try {
      if ("vibrate" in navigator) {
        // Light haptic tap on supported devices
        navigator.vibrate(10);
      }
    } catch {
      // ignore
    }
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

    setTapPopupText(`+${incrementStep}`);
    setTapPopupKey((k) => k + 1);
    if (streakTimeoutRef.current != null) {
      window.clearTimeout(streakTimeoutRef.current);
    }
    streakTimeoutRef.current = window.setTimeout(() => {
      setStreak(0);
      setTapPopupText(null);
    }, 1400);

    triggerParticles();
    setPulseKey((k) => k + 1);
    playTapFeedback();

    if (tapTtsMode === "off") return;
    if (soundLevel === 0) return;

    const every = tapTtsMode === "max" ? 1 : tapTtsMode === "3" ? 3 : 10;
    if (dogTapCountRef.current % every !== 0) return;

    void playThaiTts(thai, current?.id ? `main-${current.id}-${dogTapCountRef.current}` : "main");
  };

  const openGoogleImages = () => {
    const q = thai.trim();
    if (!q) return;
    const url = `https://www.google.com/search?tbm=isch&q=${encodeURIComponent(q)}`;
    if (typeof window !== "undefined") {
      window.open(url, "_blank", "noopener,noreferrer");
    }
  };

  const openGoogleTranslate = () => {
    const q = thai.trim();
    if (!q) return;
    const url = `https://translate.google.com/?sl=th&tl=my&text=${encodeURIComponent(q)}&op=translate`;
    if (typeof window !== "undefined") {
      window.open(url, "_blank", "noopener,noreferrer");
    }
  };

  const tapTtsIcon = tapTtsMode === "max" ? "🔊" : tapTtsMode === "3" ? "🔉" : tapTtsMode === "10" ? "🔈" : "🔇";
  const tapTtsBadge = tapTtsMode === "3" ? "3" : tapTtsMode === "10" ? "10" : null;
  const cycleTapMode = () => {
    const order: Array<"max" | "3" | "10" | "off"> = ["max", "3", "10", "off"];
    const idx = order.indexOf(tapTtsMode);
    const next = order[(idx + 1) % order.length] ?? "off";
    setTapMode(next);
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

  useEffect(() => {
    if (optimisticCount == null) return;
    if (count === optimisticCount) setOptimisticCount(null);
  }, [optimisticCount]);

  const effectiveStatus = optimisticStatus ?? status;
  const effectiveCount = optimisticCount ?? count;
  const statusIcon =
    effectiveStatus === "ready"
      ? "💎"
      : effectiveStatus === "queue"
        ? "😮"
        : effectiveStatus === "drill"
          ? "🔥"
          : "🔥";

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
    setIncrementStep((prev) => {
      const idx = order.indexOf(prev);
      return order[(idx + 1) % order.length] ?? 5;
    });
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

  const updateFirestoreCount = async (val: number) => {
    if (!isAuthed || !uid || !current) return;
    setCountBusy(true);
    try {
      await upsertVocabulary(uid, { ...current, count: val });
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

  const setEffectiveCount = (val: number) => {
    setOptimisticCount(val);
  };

  const categoryTotals = useMemo(() => {
    if (!isAuthed || !current) return { notReady: 0, total: 0 };
    const cat = categoryName;
    const inCat = items.filter((it) => {
      const name = (it.category?.toString().trim() || "Uncategorized").trim();
      return name === cat;
    });
    const total = inCat.length;
    const notReady = inCat.filter((it) => it.status !== "ready").length;
    return { notReady, total };
  }, [isAuthed, items, current, categoryName]);

  const allCategories = useMemo(() => {
    const cats = new Set<string>();
    items.forEach((it) => {
      const name = (it.category?.toString().trim() || "Uncategorized").trim();
      cats.add(name);
    });
    return Array.from(cats).sort();
  }, [items]);


  const thaiColors = [
    "#49D2FF",
    "#B36BFF",
    "#FF4D6D",
    "#FFB000",
    "#22C55E",
    "#60A5FA",
  ];

  const readGoogleAiKey = () => {
    try {
      return (localStorage.getItem(GOOGLE_AI_API_KEY_STORAGE) ?? "").trim();
    } catch {
      return "";
    }
  };

  const readAiRateLimitUntil = () => {
    try {
      const raw = (localStorage.getItem(AI_RATE_LIMIT_UNTIL_KEY) ?? "").trim();
      const ms = Number(raw);
      return Number.isFinite(ms) ? ms : 0;
    } catch {
      return 0;
    }
  };

  const writeAiRateLimitUntil = (ms: number) => {
    try {
      localStorage.setItem(AI_RATE_LIMIT_UNTIL_KEY, String(ms));
    } catch {
      // ignore
    }
  };

  const playThaiTts = async (text: string, activeKey?: string) => {
    const cleaned = String(text ?? "").trim();
    if (!cleaned) return;
    if (!isAuthed) return;
    if (soundLevel === 0) return;
    if (ttsBusy) return;

    const key = activeKey ?? cleaned;
    setTtsActive(key);
    setTtsBusy(true);

    try {
      const auth = getFirebaseAuth();
      const token = await auth.currentUser?.getIdToken();
      if (!token) throw new Error("Not signed in");

      try {
        audioRef.current?.pause();
      } catch {
        // ignore
      }
      audioRef.current = null;

      const res = await fetch("/api/tts", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ text: cleaned }),
      });

      if (!res.ok) {
        const t = await res.text();
        throw new Error(`${res.status} ${res.statusText}${t ? `: ${t}` : ""}`);
      }

      const buf = await res.arrayBuffer();
      const blob = new Blob([buf], { type: "audio/mpeg" });
      const url = URL.createObjectURL(blob);
      const audio = new Audio(url);
      audio.volume = soundLevel === 2 ? 1 : 0.65;
      audioRef.current = audio;
      audio.onended = () => {
        try {
          URL.revokeObjectURL(url);
        } catch {
          // ignore
        }
      };

      await audio.play();
    } catch {
      // ignore
    } finally {
      setTimeout(() => setTtsActive((prev) => (prev === key ? null : prev)), 160);
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
          <button
            type="button"
            onClick={() => void playThaiTts(thaiSentence, `${lineKey}-thai`)}
            disabled={!isAuthed || ttsBusy}
            className={
              "bg-transparent text-inherit text-left transition-opacity " +
              (ttsActive === `${lineKey}-thai` ? "opacity-70" : "opacity-100")
            }
          >
            {thaiSentence}
          </button>
          {burmesePart ? <span className="text-white/70"> {burmesePart}</span> : null}
        </div>
      );
    }

    if (trimmed.startsWith("ဖွဲ့စည်းပုံ -")) {
      const parts: ReactNode[] = [];
      const bracketRe = /\[([^\]]+)\]/g;
      let last = 0;
      let m: RegExpExecArray | null;
      while ((m = bracketRe.exec(trimmed)) !== null) {
        const before = trimmed.slice(last, m.index);
        if (before) parts.push(<span key={`${lineKey}-b-${last}`}>{before}</span>);
        const inside = String(m[1] ?? "");
        const thaiChars = (inside.match(/[\u0E00-\u0E7F]+/g) ?? []).join("");
        const speak = thaiChars.trim() || inside.trim();
        const thisKey = `${lineKey}-br-${m.index}`;
        parts.push(
          <button
            key={thisKey}
            type="button"
            onClick={() => void playThaiTts(speak, thisKey)}
            disabled={!isAuthed || ttsBusy}
            className={
              "bg-transparent text-inherit text-left transition-opacity " +
              (ttsActive === thisKey ? "opacity-70" : "opacity-100")
            }
          >
            [{inside}]
          </button>
        );
        last = m.index + m[0].length;
      }
      const after = trimmed.slice(last);
      if (after) parts.push(<span key={`${lineKey}-a-${last}`}>{after}</span>);

      return (
        <div key={lineKey} className="text-[13px] leading-6 font-semibold text-white/80">
          {parts}
        </div>
      );
    }

    const thaiMatch = trimmed.match(/[\u0E00-\u0E7F]+/);
    if (thaiMatch?.index != null) {
      const i = thaiMatch.index;
      const thaiWord = thaiMatch[0];
      const before = trimmed.slice(0, i);
      const after = trimmed.slice(i + thaiWord.length);
      const thisKey = `${lineKey}-thaiword`;
      return (
        <div key={lineKey} className="text-[13px] leading-6 font-semibold text-white/80">
          {before ? <span>{before}</span> : null}
          <button
            type="button"
            onClick={() => void playThaiTts(thaiWord, thisKey)}
            disabled={!isAuthed || ttsBusy}
            className={
              "bg-transparent text-inherit text-left transition-opacity " +
              (ttsActive === thisKey ? "opacity-70" : "opacity-100")
            }
          >
            {thaiWord}
          </button>
          {after ? <span>{after}</span> : null}
        </div>
      );
    }

    return (
      <div key={lineKey} className="text-[13px] leading-6 font-semibold text-white/80">
        {trimmed}
      </div>
    );
  };

  const renderAiExplain = (text: string) => {
    const lines = String(text ?? "")
      .split(/\r?\n/)
      .map((l) => l.trim())
      .filter((l) => l.length > 0);

    return (
      <div className="space-y-2">
        {lines.map((line, idx) => renderExplainLine(line, `ai-${idx}`))}
      </div>
    );
  };

  const startAutoExplain = async () => {
    if (!isAuthed || !uid || !current) return;
    if (current.ai_explanation && String(current.ai_explanation).trim().length > 0) return;
    if (aiDismissedId === current.id) return;
    if (aiBusy || aiSaving) return;
    if (aiForId === current.id && (aiDraft || aiError)) return;

    const until = readAiRateLimitUntil();
    const now = Date.now();
    if (until > now) {
      const secs = Math.max(1, Math.ceil((until - now) / 1000));
      setAiError(`ယနေ့ Limit ပြည့်သွားပါ၍ ${secs} စက္ကန့်မှ ပြန်ကြည့်ပေးပါ။`);
      setAiForId(current.id);
      return;
    }

    const apiKey = readGoogleAiKey();
    if (!apiKey) {
      setAiError("Missing API key. Add it in Settings.");
      setAiDraft(null);
      setAiForId(current.id);
      return;
    }

    setAiBusy(true);
    setAiError(null);
    setAiDraft(null);
    setAiForId(current.id);

    try {
      const text = await generateThaiExplanation(apiKey, thai, burmese);
      setAiDraft(text);
    } catch (e: unknown) {
      const err = e as { message?: string };
      const raw = (err?.message ? String(err.message) : "AI request failed").trim();
      if (raw.startsWith("RATE_LIMIT:")) {
        const m = raw.match(/retry_after=(\d+)s/i);
        const retryAfter = m?.[1] ? Number(m[1]) : null;
        const seconds = retryAfter && Number.isFinite(retryAfter) ? Math.max(1, retryAfter) : 60;
        writeAiRateLimitUntil(Date.now() + seconds * 1000);
        setAiError(`ယနေ့ Limit ပြည့်သွားပါ၍ ${seconds} စက္ကန့်မှ ပြန်ကြည့်ပေးပါ။`);
      } else {
        setAiError(raw);
      }
    } finally {
      setAiBusy(false);
    }
  };

  const confirmAndSaveAi = async () => {
    if (!isAuthed || !uid || !current) return;
    if (!aiDraft || !aiDraft.trim().length) return;
    if (aiSaving) return;
    setAiSaving(true);
    try {
      await upsertVocabulary(uid, { ...current, ai_explanation: aiDraft.trim() });
      setAiDraft(null);
      setAiError(null);
    } catch (e: unknown) {
      const err = e as { message?: string };
      setAiError((err?.message ? String(err.message) : "Save failed").trim());
    } finally {
      setAiSaving(false);
    }
  };

  useEffect(() => {
    void startAutoExplain();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [current?.id, isAuthed]);

  useEffect(() => {
    if (!current?.id) return;
    if (!thai.trim()) return;
    if (!isAuthed) return;
    if (soundLevel === 0) return;
    if (lastAutoSpokenIdRef.current === current.id) return;
    lastAutoSpokenIdRef.current = current.id;
    void playThaiTts(thai, `main-${current.id}`);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [current?.id, isAuthed, soundLevel]);

  const showAiExplain = current?.ai_explanation ||
    (current?.id && aiDismissedId !== current.id && (aiBusy || aiError || aiDraft));

  // Temporarily removed AI Explain section to fix build

  return (
    <div className="min-h-screen bg-[#0A0B0F] text-white">
      <div
        className="min-h-screen"
      >
        <div className="mx-auto w-full max-w-md px-4 pt-4 pb-4 min-h-[100dvh] flex flex-col">
          <div className="origin-top flex-1 min-h-0 flex flex-col">
            <header className="grid grid-cols-3 items-center">
              <div className="justify-self-start">
                <button
                  type="button"
                  disabled={!isAuthed || !current}
                  onClick={() => {
                    if (!isAuthed || !current) return;
                    router.push(
                      `/category?cat=${encodeURIComponent(categoryName)}&from=counter&id=${encodeURIComponent(
                        current.id
                      )}`
                    );
                  }}
                  className={
                    "text-[16px] font-semibold text-white/85 " +
                    (!isAuthed || !current ? "opacity-60" : "opacity-100")
                  }
                >
                  {categoryName}{" "}
                  {isAuthed ? (
                    <span className="text-white/70">
                      ({categoryTotals.notReady}/{Math.max(1, categoryTotals.total)})
                    </span>
                  ) : null}
                </button>
              </div>

              <div className="justify-self-center">
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={openGoogleImages}
                    className="h-[34px] w-[34px] rounded-full border-2 border-white/80 bg-[#2CE08B] shadow-[0_12px_40px_rgba(0,255,160,0.25)] flex items-center justify-center text-[12px] font-semibold focus:outline-none active:scale-95 transition-transform"
                    aria-label="Open Google Images"
                  >
                    G
                  </button>
                  <button
                    type="button"
                    onClick={openGoogleTranslate}
                    className="h-[34px] w-[34px] rounded-full border-2 border-white/80 bg-[#FF4D94] shadow-[0_12px_40px_rgba(255,70,160,0.25)] flex items-center justify-center text-[12px] font-semibold focus:outline-none active:scale-95 transition-transform"
                    aria-label="Open Google Translate"
                  >
                    T
                  </button>
                </div>
              </div>

              <div className="justify-self-end flex items-center gap-3">
                <button
                  onClick={() => setIsEditing(!isEditing)}
                  className="text-[16px] font-semibold text-[#4FD2FF] active:opacity-60"
                >
                  {isEditing ? "Cancel" : "Edit"}
                </button>
                {!isEditing && (
                  <Link href="/" className="text-[20px] font-medium text-white/60 hover:text-white active:opacity-60">
                    ✕
                  </Link>
                )}
              </div>
            </header>

            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.18 }}
              className="mt-4 flex-1 flex flex-col"
            >
              {!isAuthed ? (
                <div className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-[13px] font-semibold text-white/70 backdrop-blur-xl">
                  Sign in required
                </div>
              ) : loading ? (
                <div className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-[13px] font-semibold text-white/70 backdrop-blur-xl">
                  Loading…
                </div>
              ) : isEditing ? (
                <div className="flex-1 flex flex-col gap-4 mt-2">
                  <div className="space-y-4 px-2 overflow-y-auto pb-4">
                    <div className="space-y-1">
                      <label className="text-[11px] font-bold uppercase tracking-wider text-white/40 ml-1">Thai</label>
                      <textarea
                        value={editThai}
                        onChange={(e) => setEditThai(e.target.value)}
                        className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3 text-[16px] font-medium text-white focus:outline-none focus:border-[#60A5FA]/50 transition-colors min-h-[80px] resize-none"
                        placeholder="Thai text"
                      />
                    </div>
                    <div className="space-y-1">
                      <label className="text-[11px] font-bold uppercase tracking-wider text-white/40 ml-1">Burmese</label>
                      <textarea
                        value={editBurmese}
                        onChange={(e) => setEditBurmese(e.target.value)}
                        className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3 text-[16px] font-medium text-white focus:outline-none focus:border-[#60A5FA]/50 transition-colors min-h-[80px] resize-none"
                        placeholder="Burmese translation"
                      />
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div className="space-y-1">
                        <label className="text-[11px] font-bold uppercase tracking-wider text-white/40 ml-1">Category</label>
                        <input
                          value={editCategory}
                          onChange={(e) => setEditCategory(e.target.value)}
                          list="category-suggestions"
                          className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3 text-[15px] font-medium text-white focus:outline-none focus:border-[#60A5FA]/50 transition-colors"
                          placeholder="Category"
                        />
                        <datalist id="category-suggestions">
                          {allCategories.map((cat) => (
                            <option key={cat} value={cat} />
                          ))}
                        </datalist>
                      </div>
                      <div className="space-y-1">
                        <label className="text-[11px] font-bold uppercase tracking-wider text-white/40 ml-1">Count</label>
                        <input
                          type="number"
                          value={editCount}
                          onChange={(e) => setEditCount(Number(e.target.value))}
                          className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3 text-[15px] font-medium text-white focus:outline-none focus:border-[#60A5FA]/50 transition-colors"
                        />
                      </div>
                    </div>
                    <div className="space-y-1">
                      <label className="text-[11px] font-bold uppercase tracking-wider text-white/40 ml-1">Status</label>
                      <div className="flex gap-2 mb-2">
                        {(["ready", "queue", "drill"] as const).map((s) => (
                          <button
                            key={s}
                            onClick={() => setEditStatus(s)}
                            className={`flex-1 py-3 rounded-xl border transition-all flex items-center justify-center ${
                              editStatus === s
                                ? "bg-white/20 border-white/40 shadow-[0_0_15px_rgba(255,255,255,0.15)]"
                                : "bg-white/5 border-white/10"
                            }`}
                          >
                            <span className="text-[28px]">
                              {s === "ready" ? "💎" : s === "queue" ? "😮" : "🔥"}
                            </span>
                          </button>
                        ))}
                      </div>
                    </div>
                    <button
                      onClick={saveEdits}
                      disabled={statusBusy}
                      className="w-full py-4 rounded-2xl bg-gradient-to-r from-[#60A5FA] to-[#B36BFF] text-white font-black text-[16px] shadow-[0_12px_40px_rgba(96,165,250,0.3)] active:scale-[0.98] transition-all disabled:opacity-50"
                    >
                      {statusBusy ? "Saving..." : "Save Changes"}
                    </button>
                  </div>
                </div>
              ) : !current ? (
                <div className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-[13px] font-semibold text-white/70 backdrop-blur-xl">
                  {items.length ? "Word not found" : "No words yet"}
                </div>
              ) : (
                <>
                  <div className="mx-auto w-full max-w-[90%] px-3 text-center -mt-[20px]">
                    <AnimatePresence mode="wait" initial={false}>
                      <motion.button
                        key={current?.id ?? thai}
                        type="button"
                        onClick={() => void playThaiTts(thai, current?.id ? `main-${current.id}` : "main")}
                        disabled={!isAuthed || !current || ttsBusy}
                        className={
                          "bg-transparent font-semibold tracking-[-0.02em] transition-opacity whitespace-normal break-words leading-snug " +
                          thaiFontClass +
                          " " +
                          (ttsActive === (current?.id ? `main-${current.id}` : "main")
                            ? "opacity-75"
                            : "opacity-100") +
                          (!isAuthed || !current ? " opacity-60" : "")
                        }
                        initial={{ opacity: 0, y: 16 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -12 }}
                        transition={{ type: "spring", stiffness: 260, damping: 22, mass: 0.9 }}
                      >
                        {Array.from(thai).map((ch, i) => (
                          <span key={`${ch}-${i}`} style={{ color: thaiColors[i % thaiColors.length] }}>
                            {ch}
                          </span>
                        ))}
                      </motion.button>
                    </AnimatePresence>
                    {burmese ? (
                      <div className="mt-1 text-[18px] sm:text-[20px] leading-relaxed font-semibold text-[#F5C542] whitespace-normal break-words">
                        {burmese}
                      </div>
                    ) : null}
                  </div>

                  <div className="mt-3">
                    <div className="flex items-start justify-between">
                      <button
                        type="button"
                        onClick={() => void cycleStatus()}
                        disabled={!isAuthed || !current || statusBusy}
                        aria-label="Change status"
                        className={
                          "flex h-[72px] w-[72px] items-center justify-center text-[53px] transition-opacity " +
                          (!isAuthed || !current ? "opacity-35" : statusBusy ? "opacity-55" : "opacity-100")
                        }
                      >
                        {statusIcon}
                      </button>

                      <div className="flex-1 text-center -mt-[20px]">
                        <div className="inline-flex items-start gap-2">
                          <motion.div
                            key={effectiveCount}
                            initial={{ scale: 1, filter: "brightness(1)" }}
                            animate={pulseKey > 0 ? { 
                              scale: [1, 1.15, 1],
                              filter: ["brightness(1)", "brightness(1.5)", "brightness(1)"],
                              textShadow: [
                                "0 0 0px rgba(255,255,255,0)",
                                "0 0 20px rgba(255,255,255,0.8)",
                                "0 0 0px rgba(255,255,255,0)"
                              ]
                            } : {}}
                            transition={{ duration: 0.3 }}
                            className="bg-gradient-to-r from-[#60A5FA] via-[#B36BFF] to-[#FF4D6D] bg-clip-text text-transparent text-[65px] sm:text-[76px] font-black leading-none tracking-[-0.04em] relative mt-[10px]"
                            style={{ 
                              fontFamily: 'system-ui, -apple-system, sans-serif',
                            }}
                          >
                            {effectiveCount.toLocaleString()}
                            {tapPopupText && (
                              <div className="pointer-events-none absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-50">
                                <AnimatePresence mode="wait">
                                  <motion.div
                                    key={tapPopupKey}
                                    initial={{ opacity: 0, x: 0, y: 140, scale: 0.5, rotate: 0 }}
                                    animate={{ opacity: 1, x: 140, y: -50, scale: 2.5, rotate: 15 }}
                                    exit={{ opacity: 0, x: 180, y: -110, scale: 1.5, rotate: 25 }}
                                    transition={{ duration: 1.2, ease: [0.22, 1, 0.36, 1] }}
                                    className="font-black text-white drop-shadow-[0_0_15px_rgba(255,122,0,0.8)] whitespace-nowrap flex items-start"
                                    style={{ 
                                      fontSize: "24px",
                                    }}
                                  >
                                    <span className="text-[14px] mt-1 mr-0.5 font-black">+</span>
                                    <span>{tapPopupText.replace('+', '')}</span>
                                  </motion.div>
                                </AnimatePresence>
                              </div>
                            )}
                          </motion.div>
                          <div className="pt-4 sm:pt-5 text-[20px] sm:text-[22px] font-semibold text-[#E6C24A]" />
                        </div>
                      </div>

                      <div className="flex w-[74px] flex-col items-center gap-3 mt-[0px]">
                        <button
                          type="button"
                          aria-label="Plus"
                          onClick={cycleStep}
                          className="h-[68px] w-[68px] rounded-full p-[3px] bg-white/20 backdrop-blur-sm shadow-[0_0_25px_rgba(255,122,0,0.3)] transition-transform active:scale-95 group"
                        >
                          <div className="h-full w-full rounded-full border-[3px] border-white/90 bg-gradient-to-br from-[#FF4D6D] via-[#FFB020] to-[#FF7A00] flex items-center justify-center relative overflow-hidden">
                            <span className="absolute top-[10px] left-[12px] text-[14px] font-black text-white/90">+</span>
                            <span className="text-[34px] font-black text-white leading-none tracking-tight translate-x-[2px]">{incrementStep}</span>
                            {/* Subtle inner highlight */}
                            <div className="absolute inset-0 bg-gradient-to-tr from-transparent via-white/10 to-transparent pointer-events-none" />
                          </div>
                        </button>
                        <button
                          type="button"
                          aria-label="Tap speak mode"
                          onClick={(e) => {
                            e.stopPropagation();
                            cycleTapMode();
                          }}
                          className={
                            "relative h-[42px] w-[42px] rounded-full border backdrop-blur-xl shadow-[0_18px_50px_rgba(0,0,0,0.25)] transition-all active:scale-90 z-40 " +
                            (tapTtsMode === "off" ? "border-white/20 bg-white/10" : "border-white/45 bg-white/20")
                          }
                        >
                          <div className="flex h-full w-full items-center justify-center text-[16px] text-white/80">
                            {tapTtsIcon}
                          </div>
                          {tapTtsBadge ? (
                            <div className="absolute -right-1 -bottom-1 h-[16px] min-w-[16px] rounded-full bg-white/90 px-1 text-[10px] font-semibold leading-[16px] text-black">
                              {tapTtsBadge}
                            </div>
                          ) : null}
                        </button>
                      </div>
                    </div>

                    <div className="relative -mt-9 sm:-mt-10 flex items-center justify-center">
                      <div className="relative w-full max-w-[300px]">
                        <motion.div
                          className="relative w-full aspect-square rounded-full border-[6px] border-white/90 overflow-hidden shadow-[0_0_80px_rgba(96,165,250,0.5)]"
                          role="button"
                          tabIndex={0}
                          aria-label="Increment count"
                          onClick={handleCircleTap}
                          onKeyDown={(e) => {
                            if (e.key === "Enter" || e.key === " ") {
                              e.preventDefault();
                              handleCircleTap();
                            }
                          }}
                          style={{
                            background: "conic-gradient(from 0deg, #00F2FF, #006AFF, #7000FF, #FF00C8, #FF0032, #FF8A00, #00F2FF)",
                          }}
                          whileTap={{ scale: 0.94 }}
                          animate={pulseKey > 0 ? {
                            boxShadow: [
                              "0 0 80px rgba(96,165,250,0.5)",
                              "0 0 120px rgba(255,255,255,0.8)",
                              "0 0 80px rgba(96,165,250,0.5)"
                            ],
                            filter: ["brightness(1)", "brightness(1.3)", "brightness(1)"],
                          } : {}}
                          transition={{ duration: 0.4 }}
                        >
                          <motion.div
                            className="absolute inset-0"
                            animate={{
                              rotate: [0, 360],
                            }}
                            transition={{
                              duration: 4,
                              repeat: Infinity,
                              ease: "linear",
                            }}
                            style={{
                              background: "conic-gradient(from 0deg, transparent, rgba(255,255,255,0.5), transparent)",
                            }}
                          />
                          <div className="absolute inset-0 rounded-full bg-black/10 backdrop-blur-[2px]" />
                          <div className="absolute inset-0 rounded-full bg-gradient-to-br from-white/10 to-transparent" />
                          
                          {pulseKey > 0 && (
                            <AnimatePresence>
                              <motion.div
                                key={pulseKey}
                                className="absolute inset-0 rounded-full border-4 border-white/40"
                                initial={{ scale: 0.9, opacity: 0.8 }}
                                animate={{ scale: 2.2, opacity: 0 }}
                                transition={{ duration: 0.5, ease: "easeOut" }}
                              />
                            </AnimatePresence>
                          )}
                          <div className="absolute inset-0 overflow-visible pointer-events-none">
                            {particles.map((p) => (
                              <AnimatePresence key={p.id}>
                                <motion.span
                                  className="absolute h-[12px] w-[12px] rounded-full"
                                  style={{ 
                                    backgroundColor: p.color,
                                    boxShadow: `0 0 25px ${p.color}`,
                                    filter: "blur(1px)",
                                  }}
                                  initial={{ x: 0, y: 0, opacity: 1, scale: 1 }}
                                  animate={{ x: p.x * 2.8, y: p.y * 2.8, opacity: 0, scale: 0.3 }}
                                  transition={{ duration: 0.9, ease: "easeOut" }}
                                />
                              </AnimatePresence>
                            ))}
                          </div>
                        </motion.div>

                        {/* Deduct button overlapping the circle */}
                        <div className="absolute bottom-[5px] right-[5px] z-30">
                          <button
                            type="button"
                            aria-label="Minus"
                            onClick={(e) => {
                              e.stopPropagation();
                              if (!isAuthed || !current || countBusy) return;
                              const newCount = Math.max(0, count - incrementStep);
                              setCount(newCount);
                              setEffectiveCount(newCount);
                              void updateFirestoreCount(newCount);
                            }}
                            disabled={!isAuthed || !current || countBusy}
                            className="h-[72px] w-[72px] sm:h-[82px] sm:w-[82px] rounded-full border-4 border-white/90 bg-gradient-to-br from-[#FF4D6D] via-[#FFB020] to-[#FF7A00] shadow-[0_0_25px_rgba(255,77,109,0.5)] active:scale-90 transition-transform flex items-center justify-center"
                          >
                            <div className="text-[30px] sm:text-[36px] font-black text-white leading-none">
                              ↓
                            </div>
                          </button>
                        </div>
                      </div>
                    </div>

                    {/* Popup removed from here and moved near count number */}
                    {/* Deduct button moved inside circle container above */}

                    <div className="mt-auto pt-5">
                      <div className="w-full rounded-2xl border border-white/20 bg-black/40 px-4 py-3 backdrop-blur-2xl shadow-[0_18px_50px_rgba(0,0,0,0.50)]">
                        <div className="relative flex items-center justify-between text-[11px] font-semibold h-[60px] sm:h-[68px]">
                          <div className="z-10 text-white/60">To Hit</div>
                          <div className="z-10 text-white/45">For Apr 7, 2025</div>
                          <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
                            <div className="text-[50px] sm:text-[60px] leading-none font-semibold bg-gradient-to-r from-[#60A5FA] via-[#B36BFF] to-[#FF4D6D] bg-clip-text text-transparent">
                              240
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>

                    {showAiExplain && (
                      <div className="mt-4 w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-4 backdrop-blur-xl shadow-[0_18px_50px_rgba(0,0,0,0.30)] flex flex-col max-h-[70vh]">
                        <div className="flex items-center justify-between shrink-0">
                          <button
                            onClick={() => setIsEditing(!isEditing)}
                            className="text-[14px] font-semibold text-[#60A5FA] active:opacity-60"
                          >
                            {isEditing ? "Cancel" : "Edit"}
                          </button>
                          {!current?.ai_explanation && current?.id ? (
                            <button
                              type="button"
                              onClick={() => {
                                setAiDraft(null);
                                setAiError(null);
                                setAiDismissedId(current.id);
                              }}
                              className={ghostBtn}
                            >
                              Close
                            </button>
                          ) : (
                            <div className="w-[72px]" />
                          )}
                        </div>

                        <div className="mt-3 flex-1 overflow-y-auto pb-[100px]">
                          {current?.ai_explanation ? (
                            <div>{renderAiExplain(String(current.ai_explanation))}</div>
                          ) : aiBusy ? (
                            <div className="flex items-center gap-2 py-2">
                              <div className="h-2 w-2 rounded-full bg-white/50 animate-pulse" />
                              <div className="h-2 w-2 rounded-full bg-white/50 animate-pulse [animation-delay:120ms]" />
                              <div className="h-2 w-2 rounded-full bg-white/50 animate-pulse [animation-delay:240ms]" />
                              <div className="ml-2 text-[13px] font-semibold text-white/60">Generating…</div>
                            </div>
                          ) : aiError ? (
                            <div className="rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-[13px] font-semibold text-red-200">
                              {aiError}
                              {current?.id ? (
                                <button
                                  type="button"
                                  onClick={() => {
                                    setAiDismissedId(null);
                                    void startAutoExplain();
                                  }}
                                  className={"mt-3 " + ghostBtn}
                                >
                                  Retry
                                </button>
                              ) : null}
                            </div>
                          ) : aiDraft ? (
                            <div className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3">
                              {renderAiExplain(aiDraft)}
                            </div>
                          ) : null}
                        </div>

                        {!current?.ai_explanation && !aiBusy && !aiError && aiDraft ? (
                          <div className="mt-3 flex items-center justify-end gap-2 shrink-0">
                            <button
                              type="button"
                              onClick={() => {
                                if (current?.id) setAiDismissedId(current.id);
                                setAiDraft(null);
                                setAiError(null);
                              }}
                              className={ghostBtn}
                            >
                              Discard
                            </button>
                            <button
                              type="button"
                              onClick={() => void confirmAndSaveAi()}
                              disabled={aiSaving}
                              className={ghostBtn + " bg-white/10 " + (aiSaving ? "opacity-60" : "opacity-100")}
                            >
                              {aiSaving ? "Saving…" : "Confirm & Save"}
                            </button>
                          </div>
                        ) : null}
                      </div>
                    )}
                  </div>
                </>
              )}
            </motion.div>

            <div className="mt-6 hidden">
              <Link href="/" className={ghostBtn}>
                Back
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function CounterPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-[#0A0B0F] text-white">
          <div
            className="min-h-screen"
            style={{
              background:
                "radial-gradient(1200px 800px at 50% 10%, rgba(255,255,255,0.08), rgba(0,0,0,0) 55%), radial-gradient(900px 600px at 50% 60%, rgba(255,83,145,0.09), rgba(0,0,0,0) 60%), #0A0B0F",
            }}
          />
        </div>
      }
    >
      <CounterPageInner />
    </Suspense>
  );
}
