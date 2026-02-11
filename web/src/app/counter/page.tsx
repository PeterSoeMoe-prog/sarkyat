"use client";

import Link from "next/link";
import { AnimatePresence, motion } from "framer-motion";
import Lottie, { LottieRefCurrentProps } from "lottie-react";
// Import animation data directly to ensure it's bundled
import dogAnimationData from "../../../public/dog-walking.json";
import { ChevronLeft, Volume2, Plus, Minus, Info, Settings, List, Edit2, Check, X, RefreshCcw } from "lucide-react";
import confetti from "canvas-confetti";
import { Suspense, useEffect, useMemo, useRef, useState, ReactNode } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { fetchAiApiKey, upsertVocabulary } from "@/lib/vocab/firestore";
import type { VocabularyEntry } from "@/lib/vocab/types";
import { generateThaiExplanation } from "@/lib/gemini";
import { parseThaiWord, CharBreakdown } from "@/lib/vocab/thaiParser";
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

  const { uid, isAnonymous, items, loading, vocabLogic, backfillingState, totalVocabCounts, xDate, rule } = useVocabulary();
  const isAuthed = !!uid && !isAnonymous;
  const searchParams = useSearchParams();
  const selectedId = searchParams.get("id");

  const toHitCount = useMemo(() => {
    if (!backfillingState?.dailyTarget) return 0;
    return Math.max(0, backfillingState.dailyTarget - (backfillingState.currentDayProgress || 0));
  }, [backfillingState]);

  const daysDifference = useMemo(() => {
    if (!xDate || !rule) return 0;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const start = new Date(xDate);
    start.setHours(0, 0, 0, 0);
    const diffTime = today.getTime() - start.getTime();
    const currentDayIndex = Math.floor(diffTime / (1000 * 60 * 60 * 24));
    const targetItems = (currentDayIndex + 1) * rule;
    const diffItems = totalVocabCounts - targetItems;
    return Math.round(diffItems / rule);
  }, [totalVocabCounts, rule, xDate]);

  const currentTargetDate = useMemo(() => {
    if (!backfillingState?.currentTargetDate) return new Date();
    return new Date(backfillingState.currentTargetDate);
  }, [backfillingState]);

  const dateText = useMemo(() => {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const m = months[currentTargetDate.getMonth()] ?? "";
    return `${m} ${currentTargetDate.getDate()}, ${currentTargetDate.getFullYear()}`;
  }, [currentTargetDate]);

  const [activeTargetCard, setActiveTargetCard] = useState(0);
  const [showCongrats, setShowCongrats] = useState(false);
  const hasShownCongratsTodayRef = useRef(false);

  useEffect(() => {
    if (toHitCount === 0 && !hasShownCongratsTodayRef.current && items.length > 0) {
      setShowCongrats(true);
      hasShownCongratsTodayRef.current = true;
      confetti({
        particleCount: 150,
        spread: 70,
        origin: { y: 0.6 }
      });
    }
  }, [toHitCount, items.length]);

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
      // Delay dismiss for 1s
      setTimeout(() => {
        setIsEditing(false);
      }, 1000);
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
  const [isDogPlaying, setIsDogPlaying] = useState(false);
  const [hasTappedOnce, setHasTappedOnce] = useState(false);
  const [dogResetKey, setDogResetKey] = useState(0);
  const lottieRef = useRef<LottieRefCurrentProps>(null);
  
  // Initialize with a reset key to ensure paused state on load
  useEffect(() => {
    setDogResetKey(Date.now());
  }, []);

  useEffect(() => {
    if (lottieRef.current) {
      if (isDogPlaying) {
        lottieRef.current.play();
      } else {
        lottieRef.current.pause();
      }
    }
  }, [isDogPlaying]);
  const dogStopTimerRef = useRef<NodeJS.Timeout | null>(null);

  const triggerDogAnimation = () => {
    setIsDogPlaying(true);
    setHasTappedOnce(true);
    if (dogStopTimerRef.current) clearTimeout(dogStopTimerRef.current);
    dogStopTimerRef.current = setTimeout(() => {
      setIsDogPlaying(false);
      setDogResetKey(Date.now());
      dogStopTimerRef.current = null;
    }, 3000);
  };
  const [dogHasWalked, setDogHasWalked] = useState(false);
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
    const particleColors = ["#60A5FA", "#49D2FF", "#2CE08B", "#FFB020", "#FF4D6D", "#B36BFF"];
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
        color: particleColors[i % particleColors.length],
      });
    }
    setParticles(next);
    if (particleTimeoutRef.current != null) window.clearTimeout(particleTimeoutRef.current);
    particleTimeoutRef.current = window.setTimeout(() => setParticles([]), 700);
  };

  const lastStatusUpdateIdRef = useRef<string | null>(null);

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
    
    triggerDogAnimation();

    // Play pop.mp3 on each tap of the dog circle with maximum speed
    try {
      const audio = popAudioRef.current;
      if (audio) {
        audio.currentTime = 0;
        audio.volume = soundLevel === 0 ? 0.5 : soundLevel === 2 ? 1 : 0.65;
        void audio.play();
      }
    } catch (err) {
      console.error("Failed to play pop.mp3:", err);
    }

    // Increment local dog tap count for TTS logic
    dogTapCountRef.current++;

    // Immediate drill logic: change to 'drill' immediately after first tap regardless of status
    if (uid && current && lastStatusUpdateIdRef.current !== current.id) {
      lastStatusUpdateIdRef.current = current.id;
      // Use firestore directly for fastest update
      const db = getFirebaseDb();
      const docRef = doc(db, "users", uid, "vocab", current.id);
      updateDoc(docRef, { 
        status: "drill",
        updatedAt: serverTimestamp()
      }).catch(err => {
        console.error("Failed to immediate-switch to drill:", err);
        lastStatusUpdateIdRef.current = null;
      });
    }

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
  const tapTtsBadge = tapTtsMode === "max" ? "1" : tapTtsMode === "3" ? "3" : tapTtsMode === "10" ? "10" : null;
  const speakerAudioRef = useRef<HTMLAudioElement | null>(null);
  const popAudioRef = useRef<HTMLAudioElement | null>(null);
  const warningAudioRef = useRef<HTMLAudioElement | null>(null);

  const cycleTapMode = () => {
    const order: Array<"max" | "3" | "10" | "off"> = ["off", "10", "3", "max"];
    const idx = order.indexOf(tapTtsMode);
    setTapMode(order[(idx + 1) % order.length] ?? "off");

    // Play default.mp3 on each tap of the speaker icon with optimized latency
    try {
      if (!speakerAudioRef.current) {
        speakerAudioRef.current = new Audio("/default.mp3");
        speakerAudioRef.current.preload = "auto";
      }
      const audio = speakerAudioRef.current;
      audio.currentTime = 0; // Reset to start for instant replay
      audio.volume = soundLevel === 0 ? 0.5 : soundLevel === 2 ? 1 : 0.65;
      void audio.play();
    } catch (err) {
      console.error("Failed to play default.mp3:", err);
    }
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
    // Pre-warm audio objects for zero latency
    if (typeof window !== "undefined") {
      popAudioRef.current = new Audio("/pop.mp3");
      popAudioRef.current.preload = "auto";
      popAudioRef.current.load();
      
      speakerAudioRef.current = new Audio("/default.mp3");
      speakerAudioRef.current.preload = "auto";
      speakerAudioRef.current.load();

      warningAudioRef.current = new Audio("/warning.mp3");
      warningAudioRef.current.preload = "auto";
      warningAudioRef.current.load();
    }
  }, []);

  const effectiveCount = optimisticCount ?? count;
  const statusIcon = status === "ready" ? "💎" : status === "queue" ? "😮" : "🔥";

  const cycleStatus = async () => {
    if (!isAuthed || !uid || !current || statusBusy) return;

    // Play default.mp3 on status change
    try {
      if (!speakerAudioRef.current) {
        speakerAudioRef.current = new Audio("/default.mp3");
        speakerAudioRef.current.preload = "auto";
      }
      const audio = speakerAudioRef.current;
      audio.currentTime = 0;
      audio.volume = soundLevel === 0 ? 0.5 : soundLevel === 2 ? 1 : 0.65;
      void audio.play();
    } catch (err) {
      console.error("Failed to play sound on status change:", err);
    }

    const cur = (current.status ?? "queue").toString();
    const next = cur === "queue" ? "drill" : cur === "drill" ? "ready" : "queue";
    setOptimisticStatus(next);
    setStatusBusy(true);
    try {
      await upsertVocabulary(uid, { ...current, status: next as any });
      
      // Smart transition logic: if status changed to 'ready', wait 1s
      if (next === "ready") {
        setTimeout(() => {
          // Show congratulations popup
          setShowCongrats(true);
          confetti({
            particleCount: 150,
            spread: 70,
            origin: { y: 0.6 }
          });

          // Priority order for next vocab after popup is closed (handled by Continue button)
          // or we can pre-select it now but stay on this page until user continues
        }, 1000);
      }
    } finally {
      setStatusBusy(false);
      setOptimisticStatus(null);
    }
  };

  const cycleStep = () => {
    // Play default.mp3 on step cycle
    try {
      if (!speakerAudioRef.current) {
        speakerAudioRef.current = new Audio("/default.mp3");
        speakerAudioRef.current.preload = "auto";
      }
      const audio = speakerAudioRef.current;
      audio.currentTime = 0;
      audio.volume = soundLevel === 0 ? 0.5 : soundLevel === 2 ? 1 : 0.65;
      void audio.play();
    } catch (err) {
      console.error("Failed to play sound on step cycle:", err);
    }

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

    // Play warning.mp3 on deduct button tap
    try {
      const audio = warningAudioRef.current;
      if (audio) {
        audio.currentTime = 0;
        audio.volume = soundLevel === 0 ? 0.5 : soundLevel === 2 ? 1 : 0.65;
        void audio.play();
      }
    } catch (err) {
      console.error("Failed to play warning.mp3:", err);
    }

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

  const allCategories = useMemo(() => Array.from(new Set(items.map((it) => (it.category?.toString().trim() || "Uncategorized").trim()))).sort(), [items]);

  const categoryTotals = useMemo(() => {
    if (!isAuthed || !current) return { notReady: 0, total: 0 };
    const cat = categoryName;
    const inCat = items.filter((it) => (it.category?.toString().trim() || "Uncategorized").trim() === cat);
    return { notReady: inCat.filter((it) => it.status !== "ready").length, total: inCat.length };
  }, [isAuthed, items, current, categoryName]);

  const getThaiSyllables = (text: string) => {
    try {
      const segmenter = new Intl.Segmenter('th', { granularity: 'grapheme' });
      return Array.from(segmenter.segment(text)).map(s => s.segment);
    } catch (e) {
      return Array.from(text);
    }
  };

  const thaiColors = ["#49D2FF", "#B36BFF", "#FF4D6D", "#FFB000", "#22C55E", "#60A5FA"];
  const thaiSyllables = useMemo(() => getThaiSyllables(thai), [thai]);

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

  const [aiRefreshingPart, setAiRefreshingPart] = useState<'composition' | 'sentence' | null>(null);

  const renderAiExplain = (text: string, composition?: string | null, sentence?: string | null) => {
    // If we have persistent fields, use them. Otherwise parse the combined text.
    let comp = composition;
    let sent = sentence;

    if (!comp && !sent && text) {
      const compMatch = text.match(/<composition>([\s\S]*?)<\/composition>/);
      const sentMatch = text.match(/<sentence>([\s\S]*?)<\/sentence>/);
      comp = compMatch ? compMatch[1].trim() : null;
      sent = sentMatch ? sentMatch[1].trim() : null;
      
      // Fallback for old data without tags
      if (!comp && !sent) {
        const lines = text.split("\n").filter(l => l.trim());
        const compositionLines = lines.filter(l => !l.startsWith("ဝါကျ -"));
        const sentenceLines = lines.filter(l => l.startsWith("ဝါကျ -"));
        comp = compositionLines.join("\n");
        sent = sentenceLines.map(l => l.replace(/^ဝါကျ\s*-\s*/, '').trim()).join("\n");
      }
    }

    if (sent) {
      // First, handle the case where Thai and Burmese are on the same line with parentheses
      // e.g. "Thai sentence (Burmese translation)" -> "Thai sentence\nBurmese translation"
      if (sent.includes(' (') && sent.includes(')')) {
        sent = sent.replace(/\s*\((.*?)\)/g, '\n$1');
      }
      
      sent = sent.split("\n").map(l => 
        l.replace(/^ဝါကျ\s*-\s*/, '')
         .replace(/^\s*[\(\{\[]\s*/, '')
         .replace(/\s*[\)\}\]]\s*$/, '')
         .trim()
      ).filter(l => l.length > 0).join("\n");
    }

    const colorizeTerms = (line: string) => {
      const terms = ["ဗျည်း", "သရ", "အသတ်ဗျည်း"];
      // Also catch anything inside [ ] or ( ) that contains Thai characters
      let parts: (string | ReactNode)[] = [line];
      
      // First, handle Thai characters inside brackets/parentheses
      const thaiInBracketsRegex = /([\[\(])([\u0E00-\u0E7F\s]+)([\]\)])/g;
      const thaiParts: (string | ReactNode)[] = [];
      parts.forEach(part => {
        if (typeof part !== 'string') {
          thaiParts.push(part);
          return;
        }

        let lastIndex = 0;
        let match;
        while ((match = thaiInBracketsRegex.exec(part)) !== null) {
          // Push text before match
          if (match.index > lastIndex) {
            thaiParts.push(part.substring(lastIndex, match.index));
          }
          // Push the bracketed Thai with red color
          thaiParts.push(match[1]);
          thaiParts.push(<span key={`thai-${match.index}`} className="text-[#FF4D4D] font-bold">{match[2]}</span>);
          thaiParts.push(match[3]);
          lastIndex = thaiInBracketsRegex.lastIndex;
        }
        if (lastIndex < part.length) {
          thaiParts.push(part.substring(lastIndex));
        }
      });
      parts = thaiParts;

      // Then handle the Burmese terms
      terms.forEach(term => {
        const nextParts: (string | ReactNode)[] = [];
        parts.forEach(part => {
          if (typeof part !== 'string') {
            nextParts.push(part);
            return;
          }
          
          const split = part.split(term);
          split.forEach((s, i) => {
            if (s !== "") nextParts.push(s);
            if (i < split.length - 1) {
              nextParts.push(<span key={term + i} className="text-[#F5C542] font-bold">{term}</span>);
            }
          });
        });
        parts = nextParts;
      });
      return parts;
    };

    return (
      <div className="space-y-6">
        {comp && (
          <div className="space-y-2">
            <div className="flex items-center justify-between px-1">
              <span className="text-[17px] font-black text-[#00F2FF] tracking-wide [text-shadow:0_0_8px_rgba(0,242,255,0.6)]">ဖွဲ့စည်းပုံ</span>
              <button 
                onClick={() => void startAutoExplain('composition')}
                disabled={aiBusy}
                className="p-1.5 rounded-lg hover:bg-white/5 text-white/40 hover:text-white/70 transition-colors disabled:opacity-30"
              >
                <RefreshCcw size={14} className={aiRefreshingPart === 'composition' ? "animate-spin" : ""} />
              </button>
            </div>
            <div className="space-y-2">
              {comp.split("\n").filter(l => l.trim()).map((line, idx) => (
                <div key={idx} className="text-[15px] leading-relaxed text-white/90 font-medium">
                  {colorizeTerms(line)}
                </div>
              ))}
            </div>
          </div>
        )}

        {sent && (
          <div className="space-y-2">
            <div className="flex items-center justify-between px-1">
              <span className="text-[17px] font-black text-[#FF00C8] tracking-wide [text-shadow:0_0_8px_rgba(255,0,200,0.6)]">ဝါကျ</span>
              <button 
                onClick={() => void startAutoExplain('sentence')}
                disabled={aiBusy}
                className="p-1.5 rounded-lg hover:bg-white/5 text-white/40 hover:text-white/70 transition-colors disabled:opacity-30"
              >
                <RefreshCcw size={14} className={aiRefreshingPart === 'sentence' ? "animate-spin" : ""} />
              </button>
            </div>
            <div className="space-y-3">
              {sent.split("\n").filter(l => l.trim()).map((line, idx) => {
                const isBurmese = /[\u1000-\u109F]/.test(line);
                const isThai = /[\u0E00-\u0E7F]/.test(line);
                return (
                  <div key={idx} className={`text-[15px] leading-relaxed font-medium ${isBurmese ? 'text-[#60A5FA]' : 'text-white/90'}`}>
                    {isThai ? (
                      <button 
                        type="button" 
                        onClick={() => void playThaiTts(line, `sent-${idx}`)}
                        className={`text-left transition-opacity ${ttsActive === `sent-${idx}` ? 'opacity-70' : 'opacity-100'}`}
                      >
                        {line}
                      </button>
                    ) : (
                      line
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </div>
    );
  };

  const startAutoExplain = async (refreshPart?: 'composition' | 'sentence') => {
    if (!isAuthed || !uid || !current || aiBusy || aiSaving) return;
    
    // If not refreshing and we already have an explanation, stop
    if (!refreshPart && (current.ai_explanation || (current.ai_composition && current.ai_sentence))) return;

    const until = readAiRateLimitUntil(), now = Date.now();
    if (until > now) {
      const secs = Math.max(1, Math.ceil((until - now) / 1000));
      setAiError("ယနေ့ Limit ပြည့်သွားပါ၍ " + secs + " စက္ကန့်မှ ပြန်ကြည့်ပေးပါ။");
      setAiForId(current.id);
      return;
    }

    setAiBusy(true);
    setAiError(null);
    setAiDraft(null);
    setAiForId(current.id);
    if (refreshPart) setAiRefreshingPart(refreshPart);

    try {
      const key = await fetchAiApiKey(uid);
      if (!key) throw new Error("Settings တွင် AI API Key အရင်ထည့်ပေးပါ။");

      const response = await generateThaiExplanation(key, current.thai, current.burmese, vocabLogic || undefined);
      
      // Parse tags
      const compMatch = response.match(/<composition>([\s\S]*?)<\/composition>/);
      const sentMatch = response.match(/<sentence>([\s\S]*?)<\/sentence>/);
      const newComp = compMatch ? compMatch[1].trim() : "";
      const newSent = sentMatch ? sentMatch[1].trim() : "";

      // If refreshing a specific part, merge with existing
      // IMPORTANT: Use latest count and status from local state to avoid resets
      const updatedEntry: VocabularyEntry = {
        ...current,
        count: effectiveCount,
        status: (optimisticStatus ?? status) as any,
        ai_composition: refreshPart === 'sentence' ? current.ai_composition : newComp,
        ai_sentence: refreshPart === 'composition' ? current.ai_sentence : newSent,
        ai_explanation: null // Move away from combined field
      };

      await upsertVocabulary(uid, updatedEntry);
      setAiDraft(null); // No draft needed if we save immediately
    } catch (err: any) {
      setAiError(err.message || "AI Request error");
    } finally {
      setAiBusy(false);
      setAiRefreshingPart(null);
    }
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

  const showAiExplain = current?.ai_composition || current?.ai_sentence || current?.ai_explanation || (current?.id && aiDismissedId !== current.id && (aiBusy || aiError || aiDraft));

  return (
    <div className="min-h-screen bg-[#0A0B0F] text-white">
      <div className="min-h-screen">
        <AnimatePresence>
          {showCongrats && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-[1000] flex items-center justify-center bg-black/60 backdrop-blur-md p-6"
            >
              <motion.div
                initial={{ scale: 0.8, opacity: 0, y: 20 }}
                animate={{ scale: 1, opacity: 1, y: 0 }}
                className="w-full max-w-sm bg-[#1A1B23] rounded-[40px] border border-white/10 p-8 flex flex-col items-center text-center shadow-[0_0_50px_rgba(0,0,0,0.5)]"
              >
                <div className="relative w-48 h-48 mb-6">
                  <img
                    src="/con.png"
                    alt="Trophy"
                    className="w-full h-full object-contain"
                  />
                </div>
                
                <h2 className="text-[32px] font-black text-white mb-8 tracking-tight">
                  Congratulations!
                </h2>

                <div className="w-full space-y-3">
                  <button
                    onClick={() => {
                      setShowCongrats(false);
                      router.push("/calendar");
                    }}
                    className="w-full py-4 rounded-2xl bg-[#22C55E] text-white font-black text-lg shadow-[0_4px_20px_rgba(34,197,94,0.3)] active:scale-[0.98] transition-transform"
                  >
                    Check Daily Stat
                  </button>
                  
                  <button
                    onClick={() => {
                      setShowCongrats(false);
                      // Smart transition logic moved here: find next vocab after user clicks Continue
                      const candidates = [
                        ...items.filter(it => it.id !== current?.id && it.status === "drill"),
                        ...items.filter(it => it.id !== current?.id && (it.status === "queue" || !it.status))
                      ];

                      if (candidates.length > 0) {
                        router.replace(`/counter?id=${encodeURIComponent(candidates[0].id)}`);
                      } else {
                        router.push("/vocab");
                      }
                    }}
                    className="w-full py-4 rounded-2xl bg-[#A855F7] text-white font-black text-lg shadow-[0_4px_20px_rgba(168,85,247,0.3)] active:scale-[0.98] transition-transform"
                  >
                    Continue
                  </button>
                </div>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>

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
                    <div className="space-y-1"><label className="text-[11px] font-bold uppercase text-white/40 ml-1">Status</label><div className="flex gap-2 mb-2">{(["queue", "drill", "ready"] as const).map(s => <button key={s} onClick={() => setEditStatus(s)} className={"flex-1 py-3 rounded-xl border " + (editStatus === s ? "bg-white/20 border-white/40" : "bg-white/5 border-white/10")}><span className="text-[28px]">{s === "ready" ? "💎" : s === "queue" ? "😮" : "🔥"}</span></button>)}</div></div>
                    <button onClick={saveEdits} disabled={statusBusy} className="w-full py-4 rounded-2xl bg-gradient-to-r from-[#60A5FA] to-[#B36BFF] text-white font-black text-[16px]">{statusBusy ? "Saving..." : "Save Changes"}</button>
                  </div>
                </div>
              ) : !current ? <div className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3">{items.length ? "Word not found" : "No words yet"}</div> : (
                <>
                  <div className="mx-auto w-full max-w-[90%] px-3 text-center mt-[-10px]">
                    <AnimatePresence mode="wait" initial={false}>
                      <motion.button key={current.id} type="button" onClick={() => void playThaiTts(thai, "main-" + current.id)} disabled={ttsBusy} className={"bg-transparent font-semibold tracking-[-0.02em] transition-opacity whitespace-normal break-words leading-snug " + thaiFontClass + (ttsActive === "main-" + current.id ? " opacity-75" : " opacity-100")} initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -12 }}>
                        {thaiSyllables.map((ch, i) => <span key={i} style={{ color: thaiColors[i % thaiColors.length] }}>{ch}</span>)}
                      </motion.button>
                    </AnimatePresence>
                    {burmese && <div className="mt-1 text-[18px] sm:text-[20px] font-semibold text-[#60A5FA]">{burmese}</div>}
                  </div>
                  <div className="mt-3">
                    <div className="flex items-start justify-between">
                      <button type="button" onClick={() => void cycleStatus()} disabled={statusBusy} className={"flex h-[86px] w-[86px] items-center justify-center text-[64px] transition-all active:scale-95 " + (statusBusy ? "opacity-55" : "opacity-100")}>{statusIcon}</button>
                      <div className="flex-1 text-center -mt-[5px]"><div className="inline-flex items-start gap-2"><motion.div key={effectiveCount} initial={{ scale: 1 }} animate={pulseKey > 0 ? { scale: [1, 1.15, 1] } : {}} className="bg-gradient-to-r from-[#60A5FA] via-[#B36BFF] to-[#FF4D6D] bg-clip-text text-transparent text-[65px] sm:text-[76px] font-black leading-none mt-[10px]">{effectiveCount.toLocaleString()}{tapPopupText && (
  <div className="pointer-events-none absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-50">
    <AnimatePresence mode="popLayout">
      <motion.div 
        key={tapPopupKey} 
        initial={{ opacity: 0, y: 20, scale: 0.5, rotate: -10 }} 
        animate={{ 
          opacity: [0, 1, 1, 0],
          y: -140, 
          x: 120,
          scale: [0.5, 2.5, 2.8, 2],
          rotate: [ -10, 15, 20, 25 ]
        }} 
        transition={{ 
          duration: 0.8,
          times: [0, 0.2, 0.8, 1],
          ease: "easeOut"
        }}
        className="font-black text-white drop-shadow-[0_0_12px_rgba(255,122,0,0.6)] text-[24px]"
      >
        <span className="text-[14px] mt-1 mr-0.5 font-black">+</span>
        {tapPopupText.replace('+', '')}
      </motion.div>
    </AnimatePresence>
  </div>
)}</motion.div></div></div>
                      <div className="flex w-[74px] flex-col items-center gap-3 relative z-[200] mt-[8px]">
                        <button type="button" onClick={cycleStep} className="h-[68px] w-[68px] rounded-full p-[3px] bg-white/20 relative z-[201]"><div className="h-full w-full rounded-full border-[3px] border-white/90 bg-gradient-to-br from-[#FF4D6D] to-[#FF7A00] flex items-center justify-center relative"><span className="absolute top-[10px] left-[6px] text-[14px] font-black">+</span><span className="text-[34px] font-black">{incrementStep}</span></div></button>
                        <div className="relative z-[201]">
                          <button 
                            type="button" 
                            onClick={cycleTapMode} 
                            className="h-[64px] w-[64px] rounded-full border border-white/10 bg-white/5 flex items-center justify-center text-[28px] active:scale-90 active:bg-white/20 transition-all shadow-lg relative z-[202]"
                            style={{ touchAction: 'manipulation' }}
                          >
                            {tapTtsIcon}
                            {tapTtsBadge && (
                              <div className="absolute -right-1 -bottom-1 h-[20px] min-w-[20px] rounded-full bg-white text-[11px] font-black text-black flex items-center justify-center shadow-sm border border-black/5 z-[203]">
                                {tapTtsBadge}
                              </div>
                            )}
                          </button>
                        </div>
                      </div>
                    </div>
                    <div className="relative -mt-14 sm:-mt-16 flex items-center justify-center">
                      <div className="relative w-full max-w-[300px]">
                        <motion.div className="relative w-full aspect-square rounded-full border-[6px] border-white/90 overflow-hidden shadow-[0_0_80px_rgba(96,165,250,0.5)]" onClick={handleCircleTap} style={{ background: "conic-gradient(from 0deg, #00F2FF, #006AFF, #7000FF, #FF00C8, #FF0032, #FF8A00, #00F2FF)" }} whileTap={{ scale: 0.94 }}>
                          <motion.div className="absolute inset-0" animate={{ rotate: [0, 360] }} transition={{ duration: 4, repeat: Infinity, ease: "linear" }} style={{ background: "conic-gradient(from 0deg, transparent, rgba(255,255,255,0.5), transparent)" }} />
                          <div className="absolute inset-0 rounded-full bg-black/10 backdrop-blur-[2px]" />
                          <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-[100]">
                            <div className="w-[120px] h-[120px] scale-x-[-1] flex items-center justify-center">
                              {!isDogPlaying ? (
                                <img 
                                  src="/dog-static.png" 
                                  alt="Dog" 
                                  className="w-full h-full object-contain relative z-[101]"
                                />
                              ) : (
                                <img 
                                  src="/dog.gif" 
                                  alt="Dog" 
                                  className="w-full h-full object-contain relative z-[101]"
                                  style={{ display: 'block' }}
                                />
                              )}
                            </div>
                          </div>
                          <div className="absolute inset-0 overflow-visible pointer-events-none">{particles.map(p => <AnimatePresence key={p.id}><motion.span className="absolute h-[12px] w-[12px] rounded-full" style={{ backgroundColor: p.color, boxShadow: "0 0 25px " + p.color }} initial={{ x: 0, y: 0, opacity: 1 }} animate={{ x: p.x * 2.8, y: p.y * 2.8, opacity: 0, scale: 0.3 }} transition={{ duration: 0.9 }} /></AnimatePresence>)}</div>
                        </motion.div>
                        <div className="absolute bottom-[5px] right-[5px] z-30"><button type="button" onClick={(e) => { e.stopPropagation(); if (isAuthed && current && !countBusy) decrementCount(); }} className="h-[72px] w-[72px] sm:h-[82px] sm:w-[82px] rounded-full border-4 border-white/90 bg-gradient-to-br from-[#FF4D6D] to-[#FF7A00] flex items-center justify-center text-[30px] sm:text-[36px] font-black text-white">↓</button></div>
                      </div>
                    </div>
                    <div className="mt-auto pt-5">
                      <div className="relative rounded-3xl border border-white/10 bg-white/5 backdrop-blur-xl shadow-[0_20px_50px_rgba(0,0,0,0.3)] overflow-hidden">
                        {/* Pagination Dots */}
                        <div className="absolute top-2 left-0 right-0 flex items-center justify-center gap-1.5 z-20 pointer-events-none">
                          {[0, 1, 2, 3].map((idx) => (
                            <div 
                              key={idx}
                              className={`h-[4px] rounded-full transition-all duration-300 ${activeTargetCard === idx ? 'bg-white/70 w-3' : 'bg-white/30 w-[4px]'}`} 
                            />
                          ))}
                        </div>

                        <div className="relative overflow-hidden h-[85px]">
                          <div 
                            className="flex transition-transform duration-500 ease-out h-full"
                            style={{ transform: `translateX(-${activeTargetCard * 100}%)` }}
                            onTouchStart={(e) => {
                              const touch = e.touches[0];
                              const startX = touch.clientX;
                              const handleTouchEnd = (ee: TouchEvent) => {
                                const endX = ee.changedTouches[0].clientX;
                                if (startX - endX > 50 && activeTargetCard < 3) setActiveTargetCard(prev => prev + 1);
                                if (endX - startX > 50 && activeTargetCard > 0) setActiveTargetCard(prev => prev - 1);
                                document.removeEventListener("touchend", handleTouchEnd);
                              };
                              document.addEventListener("touchend", handleTouchEnd);
                            }}
                          >
                            {/* Card 1: To Hit */}
                            <div className="w-full shrink-0 px-4 py-3 flex items-center justify-between relative h-full">
                              <div className="flex flex-col">
                                <span className="text-[11px] font-bold text-white/40 uppercase tracking-widest">To Hit</span>
                                <span className="text-[10px] font-medium text-white/20 uppercase tracking-tight">For {dateText}</span>
                              </div>
                              <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                                <span className="text-[52px] font-black bg-gradient-to-r from-cyan-400 via-purple-500 to-pink-500 bg-clip-text text-transparent leading-none">
                                  {toHitCount.toLocaleString()}
                                </span>
                              </div>
                            </div>

                            {/* Card 2: Today Hits */}
                            <div className="w-full shrink-0 px-4 py-3 flex items-center justify-between relative h-full">
                              <div className="flex flex-col">
                                <span className="text-[11px] font-bold text-white/40 uppercase tracking-widest">Today Hits</span>
                                <span className="text-[10px] font-medium text-white/20 uppercase tracking-tight">Daily Progress</span>
                              </div>
                              <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                                <span className="text-[52px] font-black bg-gradient-to-r from-[#2CE08B] to-[#49D2FF] bg-clip-text text-transparent leading-none">
                                  {(backfillingState?.currentDayProgress || 0).toLocaleString()}
                                </span>
                              </div>
                            </div>

                            {/* Card 3: Total Vocab */}
                            <div className="w-full shrink-0 px-4 py-3 flex items-center justify-between relative h-full">
                              <div className="flex flex-col">
                                <span className="text-[11px] font-bold text-white/40 uppercase tracking-widest">Total Vocab</span>
                                <span className="text-[10px] font-medium text-white/20 uppercase tracking-tight">Lifetime</span>
                              </div>
                              <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                                <span className="text-[52px] font-black bg-gradient-to-r from-[#FFB020] to-[#FF4D6D] bg-clip-text text-transparent leading-none">
                                  {totalVocabCounts.toLocaleString()}
                                </span>
                              </div>
                            </div>

                            {/* Card 4: Missed Days */}
                            <div className="w-full shrink-0 px-4 py-3 flex items-center justify-between relative h-full">
                              <div className="flex flex-col">
                                <span className="text-[11px] font-bold text-white/40 uppercase tracking-widest">Missed Days</span>
                                <span className="text-[10px] font-medium text-white/20 uppercase tracking-tight">Vs Target</span>
                              </div>
                              <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                                <span className="text-[52px] font-black bg-gradient-to-r from-[#FF4D6D] to-[#B36BFF] bg-clip-text text-transparent leading-none">
                                  {daysDifference < 0 ? Math.abs(daysDifference) : 0}
                                </span>
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                    
                    {showAiExplain && (
                      <div className="mt-6 w-full flex flex-col">
                        <div className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-4 flex flex-col max-h-[70vh]">
                          <div className="flex-1 overflow-y-auto pb-[100px]">
                            {current.ai_composition || current.ai_sentence || current.ai_explanation ? (
                              <div>{renderAiExplain(String(current.ai_explanation || ""), current.ai_composition, current.ai_sentence)}</div>
                            ) : aiBusy ? (
                              <div className="flex items-center gap-2 text-white/40"><RefreshCcw className="animate-spin" size={16} /> AI Explaining…</div>
                            ) : aiError ? (
                              <div className="text-red-400 text-[14px]">{aiError}</div>
                            ) : aiDraft ? (
                              <div className="text-white/80">{aiDraft}</div>
                            ) : null}
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
