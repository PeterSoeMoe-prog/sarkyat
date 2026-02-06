"use client";

import { motion } from "framer-motion";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import AuthScreen from "@/components/AuthScreen";
import ErrorBoundary from "@/components/ErrorBoundary";
import { isFirebaseConfigured } from "@/lib/firebase/client";

function formatLongDate(d: Date) {
  const months = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];
  const m = months[d.getMonth()] ?? "";
  return `${m} ${d.getDate()}, ${d.getFullYear()}`;
}

function ProgressRing({
  progress,
  size,
  stroke,
}: {
  progress: number;
  size: number;
  stroke: number;
}) {
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const dash = (progress / 100) * circumference;

  return (
    <div className="relative" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="block">
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="rgba(255,255,255,0.05)"
          strokeWidth={stroke}
        />
        <motion.circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="url(#progress-gradient)"
          strokeWidth={stroke}
          strokeLinecap="round"
          initial={{ strokeDasharray: `0 ${circumference}`, rotate: -90 }}
          animate={{ 
            strokeDasharray: [`0 ${circumference}`, `${dash} ${circumference - dash}`],
            rotate: [-90, 270] 
          }}
          transition={{ 
            duration: 2.5, 
            ease: "easeOut",
            // 1 minute loop animation
            repeat: Infinity,
            repeatDelay: 60,
            repeatType: "loop"
          }}
          style={{ originX: "50%", originY: "50%" }}
        />
        <defs>
          <linearGradient id="progress-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#49D2FF" />
            <stop offset="25%" stopColor="#B36BFF" />
            <stop offset="50%" stopColor="#FF4D6D" />
            <stop offset="75%" stopColor="#FFB020" />
            <stop offset="100%" stopColor="#2CE08B" />
          </linearGradient>
        </defs>
      </svg>
      <div className="absolute inset-0 rounded-full bg-black/20" />
    </div>
  );
}

export default function HomePage() {
  const { 
    items, 
    loading, 
    dailyTarget, 
    authInitializing, 
    uid,
    isCachedLoggedIn,
    aiKeyLoading
  } = useVocabulary();
  const router = useRouter();
  const [hasMounted, setHasMounted] = useState(false);
  const isAuthed = !!uid;

  useEffect(() => {
    setHasMounted(true);
  }, []);

  // PREVENT FLICKER: Show premium splash during auth initialization
  if (!hasMounted || authInitializing) {
    return (
      <div className="min-h-screen bg-[#0A0B0F] flex flex-col items-center justify-center">
        <div
          className="min-h-screen w-full flex flex-col items-center justify-center"
          style={{
            background:
              "radial-gradient(1200px 800px at 50% 10%, rgba(255,255,255,0.05), rgba(0,0,0,0) 55%), radial-gradient(900px 600px at 50% 60%, rgba(179,107,255,0.07), rgba(0,0,0,0) 60%), #0A0B0F",
          }}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ 
              duration: 0.8,
              repeat: Infinity,
              repeatType: "reverse",
              ease: "easeInOut"
            }}
            className="flex flex-col items-center gap-6"
          >
            <div className="text-[42px] font-bold tracking-tighter bg-gradient-to-r from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF] bg-clip-text text-transparent filter drop-shadow-[0_0_20px_rgba(179,107,255,0.3)]">
              Sar-Kyat
            </div>
            <div className="h-1 w-24 bg-gradient-to-r from-transparent via-[#B36BFF]/30 to-transparent rounded-full" />
          </motion.div>
        </div>
      </div>
    );
  }

  // REDIRECT LOGIC: Only show login if auth is finished and we aren't cached/authed
  if (!isAuthed && !isCachedLoggedIn) {
    return <AuthScreen />;
  }

  const now = useMemo(() => new Date(), []);
  const dateText = useMemo(() => formatLongDate(now), [now]);

  if (!hasMounted) {
    return <div className="min-h-screen bg-[#0A0B0F]" />;
  }

  if (loading || (uid && aiKeyLoading)) {
    return (
      <div className="min-h-screen bg-[#0A0B0F] flex flex-col items-center justify-center p-4">
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="relative"
        >
          <div className="h-24 w-24 rounded-3xl bg-gradient-to-br from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF] p-[2px] animate-pulse">
            <div className="flex h-full w-full items-center justify-center rounded-[calc(1.5rem-2px)] bg-[#0A0B0F]">
              <div className="h-10 w-10 border-4 border-[#B36BFF] border-t-transparent rounded-full animate-spin" />
            </div>
          </div>
        </motion.div>
        <motion.p
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="mt-6 text-[14px] font-bold text-white/40 tracking-widest uppercase"
        >
          Initializing Experience
        </motion.p>
      </div>
    );
  }

  if (!uid && isFirebaseConfigured) {
    return <AuthScreen />;
  }

  // Derived stats
  const statusCounts = { drill: 0, queue: 0, ready: 0 };
  for (const it of items) {
    if (it.status === "drill") statusCounts.drill++;
    if (it.status === "queue") statusCounts.queue++;
    if (it.status === "ready") statusCounts.ready++;
  }

  const allTotal = items.length;
  const readyPct = allTotal > 0 ? Math.round((statusCounts.ready / allTotal) * 100) : 0;
  const hitsFor = statusCounts.ready;
  const totalVocabCounts = items.reduce((sum, it) => sum + (it.count || 0), 0);

  const legend = {
    queue: { count: statusCounts.queue, pct: allTotal > 0 ? Math.round((statusCounts.queue / allTotal) * 100) : 0 },
    drill: { count: statusCounts.drill, pct: allTotal > 0 ? Math.round((statusCounts.drill / allTotal) * 100) : 0 },
    ready: { count: statusCounts.ready, pct: allTotal > 0 ? Math.round((statusCounts.ready / allTotal) * 100) : 0 },
  };

  const btnBase = "w-full rounded-2xl px-5 py-4 text-[18px] font-semibold text-white shadow-[0_18px_50px_rgba(0,0,0,0.30)]";

  return (
    <ErrorBoundary>
      <div className="min-h-screen bg-[#0A0B0F] text-white">
        <div
          className="min-h-screen"
          style={{
            background:
              "radial-gradient(1200px 800px at 50% 10%, rgba(255,255,255,0.08), rgba(0,0,0,0) 55%), radial-gradient(900px 600px at 50% 60%, rgba(255,83,145,0.09), rgba(0,0,0,0) 60%), #0A0B0F",
          }}
        >
          <div className="mx-auto w-full max-w-md px-4 pt-[calc(env(safe-area-inset-top)+18px)] pb-[calc(env(safe-area-inset-bottom)+118px)]">
            <div className="text-center flex items-center justify-center gap-2">
              <div className="text-[34px] font-bold tracking-tighter bg-gradient-to-r from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF] bg-clip-text text-transparent">
                Sar Kyat Pro
              </div>
              <div className="flex items-center gap-1.5 px-2 py-0.5 rounded-full bg-[#2CE08B]/10 border border-[#2CE08B]/20 mb-4">
                <div className="h-1.5 w-1.5 rounded-full bg-[#2CE08B] animate-pulse shadow-[0_0_8px_#2CE08B]" />
                <span className="text-[10px] font-black text-[#2CE08B] uppercase tracking-widest">LIVE</span>
              </div>
            </div>

            <div className="mt-6 relative rounded-3xl border border-white/10 bg-white/5 px-5 py-4 backdrop-blur-xl shadow-[0_25px_80px_rgba(0,0,0,0.35)] overflow-hidden">
              <div className="absolute top-4 left-0 right-0 flex items-center justify-center gap-2 pointer-events-none">
                <div className="h-[6px] w-[6px] rounded-full bg-white/30" />
                <div className="h-[6px] w-[6px] rounded-full bg-white/70" />
              </div>
              <div className="text-center pt-1.5">
                <div className="relative inline-flex items-start justify-center">
                  <motion.div
                    className="bg-gradient-to-r from-[#49D2FF] via-[#B36BFF] to-[#FF4D6D] bg-clip-text text-transparent text-[60px] sm:text-[72px] font-bold leading-none tracking-[-0.03em] relative"
                    style={{ 
                      filter: "drop-shadow(0 18px 45px rgba(255,80,150,0.25))",
                      WebkitTextStroke: "1px rgba(255,255,255,0.15)"
                    }}
                    animate={{
                      filter: [
                        "drop-shadow(0 18px 45px rgba(255,80,150,0.25))",
                        "drop-shadow(0 18px 60px rgba(255,80,150,0.45))",
                        "drop-shadow(0 18px 45px rgba(255,80,150,0.25))"
                      ],
                    }}
                    transition={{
                      duration: 3,
                      repeat: Infinity,
                      ease: "easeInOut"
                    }}
                  >
                    {loading || !isAuthed ? "—" : hitsFor.toLocaleString()}
                    <motion.div 
                      className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent skew-x-[-20deg] pointer-events-none"
                      animate={{
                        x: ["-100%", "200%"],
                      }}
                      transition={{
                        duration: 4,
                        repeat: Infinity,
                        ease: "linear",
                        delay: 1
                      }}
                    />
                  </motion.div>
                  <div className="absolute left-full top-2 ml-1 whitespace-nowrap text-[14px] sm:text-[16px] font-bold text-white/40 uppercase tracking-widest">
                    Hits for
                  </div>
                </div>

                <div className="mt-4 flex justify-center">
                  <div className="inline-flex items-center rounded-full border border-white/15 bg-black/20 px-4 py-1.5 text-[16px] font-semibold text-white/90 shadow-[0_12px_40px_rgba(0,0,0,0.30)]">
                    {dateText}
                  </div>
                </div>

                <div className="mt-2 text-[12px] font-semibold text-white/35">
                  {loading ? "Loading…" : !isAuthed ? "Sign in required" : ""}
                </div>
              </div>

              <div className="mt-4 grid grid-cols-2 gap-3">
                <motion.button
                  type="button"
                  whileTap={{ scale: 0.98 }}
                  whileHover={{ scale: 1.01 }}
                  onClick={() => router.push("/")}
                  className={
                    btnBase +
                    " bg-gradient-to-r from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF]"
                  }
                >
                  Daily List
                </motion.button>
                <motion.button
                  type="button"
                  whileTap={{ scale: 0.98 }}
                  whileHover={{ scale: 1.01 }}
                  onClick={() => router.push("/counter")}
                  className={
                    btnBase +
                    " bg-gradient-to-r from-[#FF4D94] via-[#FF4D6D] to-[#FF7A00]"
                  }
                >
                  Start Study
                </motion.button>
              </div>
            </div>

            <div className="mt-8 grid grid-cols-[1fr_auto] items-center gap-6">
              <div className="flex items-center justify-center">
                <ProgressRing progress={readyPct} size={160} stroke={22} />
              </div>

              <div className="min-w-[156px]">
                <div className="space-y-3 text-[14px] font-semibold text-white/80">
                  <div className="flex items-center justify-between gap-3">
                    <div className="flex items-center gap-2">
                      <span className="h-[10px] w-[10px] rounded-full bg-[#FF4D6D]" />
                      <span>Queue</span>
                    </div>
                    <span className="tabular-nums">
                      {legend.queue.count.toLocaleString()} ({legend.queue.pct}%)
                    </span>
                  </div>
                  <div className="flex items-center justify-between gap-3">
                    <div className="flex items-center gap-2">
                      <span className="h-[10px] w-[10px] rounded-full bg-[#FFB020]" />
                      <span>Drill</span>
                    </div>
                    <span className="tabular-nums">
                      {legend.drill.count.toLocaleString()} ({legend.drill.pct}%)
                    </span>
                  </div>
                  <div className="flex items-center justify-between gap-3">
                    <div className="flex items-center gap-2">
                      <span className="h-[10px] w-[10px] rounded-full bg-[#2CE08B]" />
                      <span>Ready</span>
                    </div>
                    <span className="tabular-nums">
                      {legend.ready.count.toLocaleString()} ({legend.ready.pct}%)
                    </span>
                  </div>
                </div>

                <div className="mt-5 text-right">
                  <div className="text-[42px] font-semibold leading-none tracking-[-0.02em]">
                    All {allTotal.toLocaleString()}
                  </div>
                </div>
              </div>
            </div>

            <div className="mt-8 relative rounded-3xl border border-white/10 bg-white/5 px-5 py-2.5 sm:py-4 backdrop-blur-xl shadow-[0_25px_80px_rgba(0,0,0,0.35)] overflow-hidden">
              <div className="text-center text-[14px] font-semibold text-white/40 pt-1">Total Vocab Counts</div>
              <div
                className="mt-2 text-center bg-gradient-to-r from-[#49D2FF] via-[#B36BFF] via-[#FF4D6D] to-[#FFB020] bg-clip-text text-transparent text-[42px] sm:text-[64px] font-semibold leading-none tracking-[-0.03em] whitespace-nowrap overflow-hidden text-ellipsis"
                style={{ filter: "drop-shadow(0 18px 45px rgba(255,80,150,0.20))" }}
              >
                {loading || !isAuthed ? "—" : totalVocabCounts.toLocaleString()}
              </div>

              <div className="mt-6 flex items-center justify-center gap-2">
                <div className="h-[6px] w-[6px] rounded-full bg-white/70" />
                <div className="h-[6px] w-[6px] rounded-full bg-white/30" />
                <div className="h-[6px] w-[6px] rounded-full bg-white/30" />
                <div className="h-[6px] w-[6px] rounded-full bg-white/30" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </ErrorBoundary>
  );
}
