"use client";

import { motion, useSpring, useTransform, animate } from "framer-motion";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState, useRef } from "react";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import AuthScreen from "@/components/AuthScreen";
import ErrorBoundary from "@/components/ErrorBoundary";
import { isFirebaseConfigured } from "@/lib/firebase/client";
import { DEFAULT_STARTING_DATE } from "@/lib/constants";

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
  readyPct,
  dailyPct,
  size,
  stroke,
  daysDifference,
}: {
  readyPct: number;
  dailyPct: number;
  size: number;
  stroke: number;
  daysDifference: number;
}) {
  const [key, setKey] = useState(0);
  const outerRadius = (size - stroke) / 2;
  const outerCircumference = 2 * Math.PI * outerRadius;
  const outerDash = (readyPct / 100) * outerCircumference;

  const innerStroke = stroke * 0.7;
  const innerGap = 4;
  const innerRadius = outerRadius - stroke / 2 - innerGap - innerStroke / 2;
  const innerCircumference = 2 * Math.PI * innerRadius;
  const innerDash = (Math.min(dailyPct, 100) / 100) * innerCircumference;

  const outerDuration = 3.125;
  const text1Delay = outerDuration * 0.9;
  const text1Duration = 3;
  const innerDelay = text1Delay + text1Duration;
  const innerDuration = 3.05;
  const text2Delay = innerDelay + (innerDuration * 0.9);
  const text2Duration = 3;

  const absoluteDays = Math.abs(daysDifference);
  
  const statusLines = daysDifference > 0 
    ? [
        <p key="0" className="text-[10px] font-medium text-white/60 uppercase tracking-tighter leading-none">You've Done</p>,
        <p key="1" className="text-[14px] font-black text-[#FFD700] uppercase tracking-tight leading-none my-1.5">{absoluteDays} Days Than</p>,
        <p key="2" className="text-[10px] font-medium text-white/60 uppercase tracking-tighter leading-none">Daily Target!</p>
      ]
    : daysDifference < 0 
      ? [
          <p key="0" className="text-[10px] font-medium text-white/60 uppercase tracking-tighter leading-none">You've Missed</p>,
          <p key="1" className="text-[14px] font-black text-[#FFD700] uppercase tracking-tight leading-none my-1.5">{absoluteDays} Days To</p>,
          <p key="2" className="text-[10px] font-medium text-white/60 uppercase tracking-tighter leading-none">Hit Target!</p>
        ]
      : [
          <p key="0" className="text-[10px] font-medium text-white/60 uppercase tracking-tighter leading-none">You're Exactly</p>,
          <p key="1" className="text-[14px] font-black text-[#FFD700] uppercase tracking-tight leading-none my-1.5">On Daily</p>,
          <p key="2" className="text-[10px] font-medium text-white/60 uppercase tracking-tighter leading-none">Target!</p>
        ];

  return (
    <div 
      className="relative cursor-pointer group active:scale-95 transition-transform" 
      style={{ width: size, height: size }}
      onClick={() => setKey(prev => prev + 1)}
    >
      <svg width={size} height={size} className="block overflow-visible">
        {/* Outer Ring Background */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={outerRadius}
          fill="none"
          stroke="rgba(255,255,255,0.03)"
          strokeWidth={stroke}
        />
        {/* Outer Ring (Ready %) */}
        <motion.circle
          key={`outer-${key}`}
          cx={size / 2}
          cy={size / 2}
          r={outerRadius}
          fill="none"
          stroke="url(#progress-gradient)"
          strokeWidth={stroke}
          strokeLinecap="round"
          initial={{ strokeDasharray: `0 ${outerCircumference}`, rotate: -90 }}
          animate={{ 
            strokeDasharray: [`0 ${outerCircumference}`, `${outerDash} ${outerCircumference - outerDash}`],
            rotate: [-90, 270] 
          }}
          transition={{ 
            duration: outerDuration, 
            ease: "easeOut",
          }}
          style={{ originX: "50%", originY: "50%" }}
        />

        {/* Inner Ring Background */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={innerRadius}
          fill="none"
          stroke="rgba(255,255,255,0.03)"
          strokeWidth={innerStroke}
        />
        {/* Inner Ring (Daily Progress %) */}
        <motion.circle
          key={`inner-${key}`}
          cx={size / 2}
          cy={size / 2}
          r={innerRadius}
          fill="none"
          stroke="#49D2FF"
          strokeWidth={innerStroke}
          strokeLinecap="round"
          initial={{ strokeDasharray: `0 ${innerCircumference}`, rotate: -90 }}
          animate={{ 
            strokeDasharray: [`0 ${innerCircumference}`, `${innerDash} ${innerCircumference - innerDash}`],
            rotate: [-90, 270] 
          }}
          transition={{ 
            duration: innerDuration, 
            delay: innerDelay,
            ease: "easeOut",
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
      
      {/* Centered Texts */}
      <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-20">
        {/* Text 1: Ready Pct */}
        <motion.div 
          key={`text1-${key}`}
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ 
            opacity: [0, 1, 1, 0],
            scale: [0.9, 1, 1, 0.95]
          }}
          transition={{
            duration: text1Duration + 0.5,
            times: [0, 0.1, 0.9, 1],
            delay: text1Delay,
            ease: "easeInOut"
          }}
          className="absolute inset-0 flex items-center justify-center text-center px-4"
        >
          <div>
            <p className="text-[10px] font-bold text-white/40 uppercase tracking-tighter leading-tight">
              You've Done
            </p>
            <p className="text-[16px] font-black text-white/80 tracking-tighter leading-none my-0.5 shadow-sm">
              {readyPct}%
            </p>
            <p className="text-[9px] font-bold text-white/40 uppercase tracking-tighter leading-tight">
              of all Vocabs!
            </p>
          </div>
        </motion.div>

        {/* Text 2: Daily Target Status (English Only) */}
        <motion.div 
          key={`text2-${key}`}
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ 
            opacity: [0, 1],
            scale: [0.9, 1]
          }}
          transition={{
            duration: 0.5,
            delay: text2Delay,
            ease: "easeOut"
          }}
          className="absolute inset-0 flex items-center justify-center text-center px-4"
        >
          <div className="flex flex-col items-center justify-center">
            {statusLines}
          </div>
        </motion.div>
      </div>

      <div className="absolute inset-[15%] rounded-full bg-black/40 backdrop-blur-md group-hover:bg-black/50 transition-colors z-10 shadow-inner" />
    </div>
  );
}

function CountUp({ value, className, style }: { value: number; className?: string; style?: any }) {
  const [displayValue, setDisplayValue] = useState(value);
  const prevValue = useRef(value);

  useEffect(() => {
    // Determine a sensible start value (e.g., 90% of target or target - 50)
    // For large numbers, starting from 0 is too fast.
    const startValue = value > 100 ? Math.floor(value * 0.98) : 0;
    setDisplayValue(startValue);
    prevValue.current = startValue;

    const timeout = setTimeout(() => {
      const controls = animate(prevValue.current, value, {
        duration: 8, // 4x slower than original 2s
        ease: "linear", // Linear makes the "ticking" speed constant and slower
        onUpdate: (latest) => setDisplayValue(Math.floor(latest)),
      });
      return () => controls.stop();
    }, 2000);

    return () => clearTimeout(timeout);
  }, [value]);

  return (
    <motion.div className={className} style={style}>
      {displayValue.toLocaleString()}
    </motion.div>
  );
}

export default function HomePage() {
  const { 
    items, 
    loading, 
    userDailyGoal, 
    authInitializing, 
    uid,
    aiKeyLoading,
    backfillingState,
    totalVocabCounts,
    xDate,
    rule,
    failedIdsCount
  } = useVocabulary();
  const router = useRouter();
  const [hasMounted, setHasMounted] = useState(false);

  const handleResume = () => {
    if (!items.length) {
      router.push("/vocab");
      return;
    }

    // 1. Check last active vocab from localStorage
    const lastId = typeof window !== "undefined" ? localStorage.getItem("sar-kyat-last-active-vocab-id") : null;
    if (lastId) {
      const lastItem = items.find(it => it.id === lastId);
      // Load if it exists and is NOT ready
      if (lastItem && lastItem.status !== "ready") {
        router.push(`/counter?id=${encodeURIComponent(lastId)}`);
        return;
      }
    }

    // 2. Otherwise, find next available item (Queue first, then Drill)
    const candidates = [
      ...items.filter(it => it.status === "queue" || !it.status),
      ...items.filter(it => it.status === "drill")
    ];

    if (candidates.length > 0) {
      router.push(`/counter?id=${encodeURIComponent(candidates[0].id)}`);
    } else {
      // 3. Fallback to vocab list if everything is 'ready'
      router.push("/vocab");
    }
  };

  const isAuthed = !!uid;

  const [activeCardIndex, setActiveCardIndex] = useState(0);
  const [bottomCardIndex, setBottomCardIndex] = useState(0);

  const currentTargetDate = useMemo(() => {
    if (!backfillingState?.currentTargetDate) return new Date();
    return new Date(backfillingState.currentTargetDate);
  }, [backfillingState]);

  const dateText = useMemo(() => formatLongDate(currentTargetDate), [currentTargetDate]);

  const daysDifference = useMemo(() => {
    if (!xDate || !rule) return 0;
    
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const start = new Date(xDate);
    start.setHours(0, 0, 0, 0);
    
    const diffTime = today.getTime() - start.getTime();
    const currentDayIndex = Math.floor(diffTime / (1000 * 60 * 60 * 24));
    
    // Target items for today = (currentDayIndex + 1) * rule
    // Current total items = totalVocabCounts
    const targetItems = (currentDayIndex + 1) * rule;
    const diffItems = totalVocabCounts - targetItems;
    
    return Math.round(diffItems / rule);
  }, [totalVocabCounts, rule, xDate]);

  const burmeseStatus = useMemo(() => {
    if (!backfillingState || !rule) return null;
    
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const startIso = xDate || DEFAULT_STARTING_DATE;
    const start = new Date(startIso);
    start.setHours(0, 0, 0, 0);
    
    // Difference from today to X Date in days
    const diffTime = today.getTime() - start.getTime();
    const currentDayIndex = Math.floor(diffTime / (1000 * 60 * 60 * 24)) + 1;
    
    const clearedDays = backfillingState.clearedDaysCount;
    const diffDays = Math.abs(clearedDays - currentDayIndex);
    
    const todayText = today.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
    
    if (clearedDays >= currentDayIndex) {
      return `ယနေ့ (${todayText}) အထိ ${diffDays} ရက် ကျော်လွန်နေပါတယ်။`;
    } else {
      return `ယနေ့ (${todayText}) အထိ ${diffDays} ရက် လိုအပ်နေပါတယ်။`;
    }
  }, [backfillingState, rule, xDate]);

  const formattedXDate = useMemo(() => {
    if (!xDate) return "";
    const parts = xDate.split("-");
    if (parts.length !== 3) return "";
    const [y, m, d] = parts;
    return `${d}/${m}/${y}`;
  }, [xDate]);

  useEffect(() => {
    setHasMounted(true);
  }, []);

  if (loading || authInitializing) {
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
          Initializing Sar Kyat
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
  const dailyPct = rule > 0 ? Math.round((backfillingState?.currentDayProgress || 0) / rule * 100) : 0;
  const hitsFor = backfillingState?.currentDayProgress ?? 0;

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
            <div className="relative w-full flex items-center justify-center min-h-[44px]">
              <div className="absolute left-0 flex items-center z-50">
                <motion.button
                  whileTap={{ scale: 0.9 }}
                  onClick={() => router.push("/vocab?mode=add")}
                  className="flex items-center justify-center h-[44px] w-[44px] transition-all group"
                >
                  <span className="text-[42px] font-black leading-none mb-1 transition-all bg-gradient-to-br from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF] bg-clip-text text-transparent drop-shadow-[0_0_12px_rgba(179,107,255,0.9)] group-active:drop-shadow-[0_0_20px_rgba(179,107,255,1)]">+</span>
                </motion.button>
              </div>
              <div className="flex flex-col items-center justify-center">
                <div className="relative">
                  <div className="text-[34px] font-bold tracking-tighter bg-gradient-to-r from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF] bg-clip-text text-transparent pointer-events-none">
                    Sar Kyat Pro
                  </div>
                  <div className="absolute -top-1 -right-8 flex items-center gap-1 opacity-80">
                    <div className="h-1.5 w-1.5 rounded-full bg-[#2CE08B] animate-pulse shadow-[0_0_8px_#2CE08B]" />
                    <span className="text-[10px] font-black text-[#2CE08B] uppercase tracking-widest">LIVE</span>
                  </div>
                </div>
              </div>
              <div className="absolute right-0 flex items-center gap-2">
                {failedIdsCount > 0 && (
                  <motion.button
                    whileTap={{ scale: 0.9 }}
                    onClick={() => router.push("/failed-quiz")}
                    className="relative p-1.5 group"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      width="20"
                      height="20"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2.5"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      className="text-white/80 group-hover:text-white transition-colors"
                    >
                      <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
                      <path d="M13.73 21a2 2 0 0 1-3.46 0" />
                    </svg>
                    <span className="absolute -top-1 -right-1 h-5 w-5 rounded-full bg-[#FF4D6D] text-[10px] font-black flex items-center justify-center shadow-[0_0_12px_rgba(255,77,109,0.6)] border-2 border-[#0A0B0F]">
                      {failedIdsCount}
                    </span>
                  </motion.button>
                )}
              </div>
            </div>

              {/* Card System */}
            <div className="mt-4 relative rounded-3xl border border-white/10 bg-white/5 p-1 backdrop-blur-xl shadow-[0_25px_80px_rgba(0,0,0,0.35)] overflow-hidden">
              <div className="absolute top-3 left-0 right-0 flex items-center justify-center gap-2 z-20">
                <button 
                  onClick={() => setActiveCardIndex(0)}
                  className={`h-[6px] rounded-full transition-all duration-300 cursor-pointer ${activeCardIndex === 0 ? 'bg-white/70 w-3' : 'bg-white/30 w-[6px]'}`} 
                />
                <button 
                  onClick={() => setActiveCardIndex(1)}
                  className={`h-[6px] rounded-full transition-all duration-300 cursor-pointer ${activeCardIndex === 1 ? 'bg-white/70 w-3' : 'bg-white/30 w-[6px]'}`} 
                />
              </div>

              <div className="relative overflow-hidden">
                <div 
                  className="flex transition-transform duration-500 ease-out"
                  style={{ transform: `translateX(-${activeCardIndex * 100}%)` }}
                  onTouchStart={(e) => {
                    const touch = e.touches[0];
                    const startX = touch.clientX;
                    const handleTouchEnd = (ee: TouchEvent) => {
                      const endX = ee.changedTouches[0].clientX;
                      if (startX - endX > 50) setActiveCardIndex(1);
                      if (endX - startX > 50) setActiveCardIndex(0);
                      document.removeEventListener("touchend", handleTouchEnd);
                    };
                    document.addEventListener("touchend", handleTouchEnd);
                  }}
                >
                  {/* Card 1: Default Stats View */}
                  <div className="w-full shrink-0 px-5 py-3">
                    <div className="text-center pt-1.5">
                      <div className="relative inline-flex items-start justify-center">
                        <motion.div
                          className="text-[52px] sm:text-[64px] font-bold leading-none tracking-[-0.03em] relative inline-block"
                          style={{ 
                            filter: "drop-shadow(0 18px 45px rgba(255,80,150,0.25))",
                            WebkitTextStroke: "1px rgba(255,255,255,0.15)",
                            background: "linear-gradient(110deg, #49D2FF 0%, #B36BFF 25%, #ffffff 45%, #ffffff 55%, #FF4D6D 75%, #FFB020 100%)",
                            backgroundSize: "200% 100%",
                            WebkitBackgroundClip: "text",
                            backgroundClip: "text",
                            color: "transparent",
                          }}
                        >
                          {loading || !isAuthed ? "—" : hitsFor.toLocaleString()}
                        </motion.div>
                        <div className="absolute left-full top-2 ml-1 whitespace-nowrap text-[14px] sm:text-[16px] font-bold text-white/40 uppercase tracking-widest">
                          Hits for
                        </div>
                      </div>

                      <div className="mt-4 flex flex-col items-center">
                        <div className="flex justify-center items-center gap-1.5">
                          <div className="inline-flex items-center rounded-full border border-white/15 bg-black/20 px-4 py-1.5 text-[16px] font-semibold text-white/90 shadow-[0_12px_40px_rgba(0,0,0,0.30)] relative">
                            {dateText}
                            {formattedXDate && (
                              <span className="absolute -top-1 -right-1 text-[9px] font-bold text-white/30 leading-none transform translate-x-full -translate-y-1/4">
                                {formattedXDate}
                              </span>
                            )}
                          </div>
                        </div>
                      </div>

                      <div className="mt-4 grid grid-cols-3 gap-2">
                        <motion.button
                          type="button"
                          whileTap={{ scale: 0.98 }}
                          onClick={() => router.push("/")}
                          className={btnBase + " bg-gradient-to-r from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF] !py-3 !px-2 !text-[13px] shadow-none"}
                        >
                          Daily List
                        </motion.button>
                        <motion.button
                          type="button"
                          whileTap={{ scale: 0.98 }}
                          onClick={handleResume}
                          className={btnBase + " bg-gradient-to-r from-[#FF4D94] via-[#FF4D6D] to-[#FF7A00] !py-3 !px-2 !text-[13px] shadow-none"}
                        >
                          Resume
                        </motion.button>
                        <motion.button
                          type="button"
                          whileTap={{ scale: 0.98 }}
                          onClick={() => router.push("/quiz")}
                          className={btnBase + " bg-gradient-to-r from-[#60A5FA] via-[#4FD2FF] to-[#2CE08B] !py-3 !px-2 !text-[13px] shadow-none"}
                        >
                          Daily Quiz
                        </motion.button>
                      </div>

                      <motion.button
                        type="button"
                        whileTap={{ scale: 0.98 }}
                        onClick={() => router.push("/ai-plus")}
                        className={btnBase + " mt-6 bg-white/5 border border-white/10 !py-3.5 !text-[15px] font-black text-white/80 shadow-none hover:bg-white/10 transition-colors"}
                      >
                        <span className="bg-gradient-to-r from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF] bg-clip-text text-transparent">AI+ Vocabs</span>
                      </motion.button>

                      <motion.button
                        type="button"
                        whileTap={{ scale: 0.98 }}
                        onClick={() => router.push("/pages")}
                        className={btnBase + " mt-2 bg-white/5 border border-white/10 !py-3.5 !text-[15px] font-black text-white/80 shadow-none hover:bg-white/10 transition-colors"}
                      >
                        <span className="bg-gradient-to-r from-[#2CE08B] to-[#49D2FF] bg-clip-text text-transparent">Pages</span>
                      </motion.button>
                    </div>
                  </div>

                  {/* Card 2: Session Picker (iOS Style) */}
                  <div className="w-full shrink-0 px-5 py-3">
                    <div className="pt-1">
                      {/* Tabs Header */}
                      <div className="flex bg-white/5 rounded-xl p-1 mb-4 border border-white/5">
                        {["Minutes", "Hits", "Vocabs"].map((tab) => (
                          <div key={tab} className={`flex-1 text-center py-1.5 text-[12px] font-bold rounded-lg transition-all ${tab === "Hits" ? "bg-gradient-to-r from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF] text-white" : "text-white/40"}`}>
                            {tab}
                          </div>
                        ))}
                      </div>

                      {/* Selectors Placeholder */}
                      <div className="flex justify-around items-center mb-4 h-20">
                        <div className="text-center scale-90 origin-bottom">
                          <div className="text-white/20 text-[12px] font-bold mb-0.5">60</div>
                          <div className="bg-white/5 rounded-xl px-3 py-1.5 text-[18px] font-black text-white/40 border border-white/5">60</div>
                          <div className="text-white/20 text-[12px] font-bold mt-0.5">40</div>
                        </div>
                        <div className="text-center">
                          <div className="text-white/20 text-[13px] font-bold mb-0.5">7,000</div>
                          <div className="bg-white/5 rounded-xl px-5 py-1.5 text-[22px] font-black text-white border border-white/10 shadow-[0_0_20px_rgba(255,255,255,0.05)]">5,000</div>
                          <div className="text-white/20 text-[13px] font-bold mt-0.5">3,000</div>
                        </div>
                        <div className="text-center scale-90 origin-bottom">
                          <div className="text-white/20 text-[12px] font-bold mb-0.5">15</div>
                          <div className="bg-white/5 rounded-xl px-3 py-1.5 text-[18px] font-black text-white/40 border border-white/5">10</div>
                          <div className="text-white/20 text-[12px] font-bold mt-0.5">5</div>
                        </div>
                      </div>

                      {/* Action Buttons */}
                      <div className="grid grid-cols-2 gap-3 pb-1">
                        <motion.button
                          whileTap={{ scale: 0.98 }}
                          className="py-3 rounded-2xl bg-white/5 border border-white/10 text-[15px] font-black text-white/60"
                        >
                          Start Session
                        </motion.button>
                        <motion.button
                          whileTap={{ scale: 0.98 }}
                          className="py-3 rounded-2xl bg-gradient-to-r from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF] text-[15px] font-black text-white shadow-[0_0_20px_rgba(73,210,255,0.4)] relative overflow-hidden group"
                        >
                          <div className="absolute inset-0 bg-white/20 opacity-0 group-hover:opacity-100 transition-opacity" />
                          Resume
                        </motion.button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="mt-8 grid grid-cols-[1fr_auto] items-center gap-6">
              <div className="flex items-center justify-center">
                <ProgressRing 
                  readyPct={readyPct} 
                  dailyPct={dailyPct} 
                  size={160} 
                  stroke={18} 
                  daysDifference={daysDifference}
                />
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

            <div className="mt-8 relative rounded-3xl border border-white/10 bg-white/5 p-1 backdrop-blur-xl shadow-[0_25px_80px_rgba(0,0,0,0.35)] overflow-hidden">
              {/* Pagination Dots */}
              <div className="absolute top-3 left-0 right-0 flex items-center justify-center gap-2 z-20">
                {[0, 1, 2, 3].map((idx) => (
                  <button 
                    key={idx}
                    onClick={() => setBottomCardIndex(idx)}
                    className={`h-[6px] rounded-full transition-all duration-300 cursor-pointer ${bottomCardIndex === idx ? 'bg-white/70 w-3' : 'bg-white/30 w-[6px]'}`} 
                  />
                ))}
              </div>

              <div className="relative overflow-hidden">
                <div 
                  className="flex transition-transform duration-500 ease-out"
                  style={{ transform: `translateX(-${bottomCardIndex * 100}%)` }}
                  onTouchStart={(e) => {
                    const touch = e.touches[0];
                    const startX = touch.clientX;
                    const handleTouchEnd = (ee: TouchEvent) => {
                      const endX = ee.changedTouches[0].clientX;
                      if (startX - endX > 50 && bottomCardIndex < 3) setBottomCardIndex(prev => prev + 1);
                      if (endX - startX > 50 && bottomCardIndex > 0) setBottomCardIndex(prev => prev - 1);
                      document.removeEventListener("touchend", handleTouchEnd);
                    };
                    document.addEventListener("touchend", handleTouchEnd);
                  }}
                >
                  {/* Bottom Card 1: Total Vocab Counts */}
                  <div className="w-full shrink-0 px-5 py-6">
                    <div className="text-center text-[14px] font-semibold text-white/40 mb-2">Total Vocab Counts</div>
                    <CountUp
                      value={loading || !isAuthed ? 0 : totalVocabCounts}
                      className="text-center bg-gradient-to-r from-[#49D2FF] via-[#B36BFF] via-[#FF4D6D] to-[#FFB020] bg-clip-text text-transparent text-[42px] sm:text-[64px] font-semibold leading-none tracking-[-0.02em] whitespace-nowrap overflow-hidden text-ellipsis"
                      style={{ filter: "drop-shadow(0 18px 45px rgba(255,80,150,0.20))" }}
                    />
                  </div>

                  {/* Bottom Card 2: To Hit (iOS Mirror) */}
                  <div className="w-full shrink-0 px-5 py-6">
                    <div className="text-center text-[14px] font-semibold text-white/40 mb-2 uppercase tracking-widest">To Hit</div>
                    <CountUp
                      value={!backfillingState?.dailyTarget ? 0 : Math.max(0, backfillingState.dailyTarget - (backfillingState.currentDayProgress || 0))}
                      className="text-center bg-gradient-to-r from-cyan-400 via-purple-500 to-pink-500 bg-clip-text text-transparent text-[52px] sm:text-[64px] font-black leading-none tracking-tight"
                    />
                    <div className="mt-2 text-center text-[12px] font-medium text-white/20 uppercase tracking-widest">
                      For {dateText}
                    </div>
                  </div>

                  {/* Bottom Card 3: Today Hits (iOS Mirror) */}
                  <div className="w-full shrink-0 px-5 py-6">
                    <div className="text-center text-[14px] font-semibold text-white/40 mb-2 uppercase tracking-widest">Today Hits</div>
                    <div className="flex items-center justify-center gap-4">
                      <CountUp
                        value={backfillingState?.currentDayProgress || 0}
                        className="bg-gradient-to-r from-cyan-400 via-purple-500 to-pink-500 bg-clip-text text-transparent text-[52px] sm:text-[64px] font-black leading-none tracking-tight"
                      />
                    </div>
                    <div className="mt-2 text-center text-[12px] font-medium text-white/20 uppercase tracking-widest">
                      Lifetime: {totalVocabCounts.toLocaleString()}
                    </div>
                  </div>

                  {/* Bottom Card 4: Missed Days (iOS Mirror) */}
                  <div className="w-full shrink-0 px-5 py-6">
                    <div className="text-center text-[14px] font-semibold text-white/40 mb-2 uppercase tracking-widest">Missed Days</div>
                    <div className="text-center bg-gradient-to-r from-[#FF4D6D] to-[#FFB020] bg-clip-text text-transparent text-[52px] sm:text-[64px] font-black leading-none tracking-tight">
                      {daysDifference < 0 ? Math.abs(daysDifference) : 0}
                    </div>
                    <div className="mt-2 text-center text-[12px] font-medium text-white/20 uppercase tracking-widest">
                      Target: {rule?.toLocaleString() || 0} / Day
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </ErrorBoundary>
  );
}
