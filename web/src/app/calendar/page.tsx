"use client";

import { useMemo, useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X } from "lucide-react";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import ErrorBoundary from "@/components/ErrorBoundary";

import { DEFAULT_STARTING_DATE } from "@/lib/constants";

function formatDateDisplay(isoString: string) {
  if (!isoString) return "";
  const parts = isoString.split("-");
  if (parts.length !== 3) return isoString;
  const [y, m, d] = parts;
  return `${d}/${m}/${y}`;
}

function CalendarMonth({ 
  year, 
  month, 
  startDay = DEFAULT_STARTING_DATE, 
  historyData, 
  userDailyGoal, 
  earliestMissDate, 
  earliestSuccessRef,
  onDateClick,
  backfillingState
}: { 
  year: number; 
  month: number; 
  startDay?: string; 
  historyData: Record<string, number>; 
  userDailyGoal: number;
  earliestMissDate: string | null;
  earliestSuccessRef: React.RefObject<HTMLButtonElement | null>;
  onDateClick: (date: string, count: number, isTarget: boolean) => void;
  backfillingState: any;
}) {
  const monthName = new Date(year, month).toLocaleString("default", { month: "long" });
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const firstDayOfMonth = new Date(year, month, 1).getDay(); // 0 = Sunday, 1 = Monday, etc.
  
  const startingDate = new Date(startDay);
  startingDate.setHours(0, 0, 0, 0); // Ensure consistency
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const days = [];
  // Empty slots for days before the 1st of the month
  for (let i = 0; i < firstDayOfMonth; i++) {
    days.push(<div key={`empty-${i}`} className="h-10 w-10" />);
  }

  for (let d = 1; d <= daysInMonth; d++) {
    const currentDay = new Date(year, month, d);
    currentDay.setHours(0, 0, 0, 0);
    const isoString = currentDay.toISOString().split('T')[0];
    
    // Backfilling Logic for Visuals
    const isTargetDate = isoString === backfillingState?.currentTargetDate;
    const dayIndex = Math.floor((currentDay.getTime() - startingDate.getTime()) / (1000 * 60 * 60 * 24));
    const isCleared = dayIndex >= 0 && dayIndex < backfillingState?.clearedDaysCount;
    const isFuture = currentDay > today || dayIndex < 0;
    
    const displayCount = isCleared ? userDailyGoal : (isTargetDate ? backfillingState.currentDayProgress : 0);

    days.push(
      <button 
        key={d} 
        ref={isTargetDate ? earliestSuccessRef : null}
        onClick={() => onDateClick(isoString, displayCount, isTargetDate)}
        disabled={isFuture && !isTargetDate}
        className={`h-10 w-10 flex flex-col items-center justify-center rounded-xl text-[13px] font-bold transition-all relative
          ${isTargetDate ? "bg-white/10 text-white ring-2 ring-[#B36BFF] shadow-[0_0_15px_rgba(179,107,255,0.4)] animate-pulse" : ""}
          ${isCleared ? "bg-[#2CE08B]/20 text-[#2CE08B] border border-[#2CE08B]/30 shadow-[0_0_15px_rgba(44,224,139,0.2)]" : ""}
          ${!isCleared && !isTargetDate && !isFuture ? "bg-white/5 text-white/40 border border-white/5" : ""}
          ${isFuture ? "text-white/10" : ""}
          hover:scale-105 active:scale-95 disabled:opacity-50
        `}
      >
        <span>{d}</span>
        {isCleared && (
          <div className="absolute -bottom-1 h-1 w-1 rounded-full bg-[#2CE08B] shadow-[0_0_5px_#2CE08B]" />
        )}
      </button>
    );
  }

  return (
    <div className="mb-8">
      <h3 className="text-[16px] font-bold text-white/80 mb-4 px-1">{monthName} {year}</h3>
      <div className="grid grid-cols-7 gap-2 place-items-center">
        {["S", "M", "T", "W", "T", "F", "S"].map(day => (
          <div key={day} className="h-10 w-10 flex items-center justify-center text-[11px] font-black text-white/30 uppercase tracking-widest">
            {day}
          </div>
        ))}
        {days}
      </div>
    </div>
  );
}

export default function CalendarPage() {
  const { xDate: cloudXDate, goalsLoading, items, userDailyGoal, backfillingState, rule } = useVocabulary();
  const startingDate = cloudXDate || DEFAULT_STARTING_DATE;
  const [hasMounted, setHasMounted] = useState(false);
  const earliestSuccessRef = useRef<HTMLButtonElement | null>(null);
  
  // Date Detail State
  const [selectedDate, setSelectedDate] = useState<{ date: string; count: number; isTarget: boolean } | null>(null);
  const [showStatusPopup, setShowStatusPopup] = useState(true);

  // Auto-hide popup after 10s
  useEffect(() => {
    if (showStatusPopup) {
      const timer = setTimeout(() => {
        setShowStatusPopup(false);
      }, 10000);
      return () => clearTimeout(timer);
    }
  }, [showStatusPopup]);

  const statusPopupText = useMemo(() => {
    if (!backfillingState || !rule) return "";
    
    const today = new Date();
    const todayText = today.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
    
    const ruleVal = rule || 100;
    const startIso = cloudXDate || DEFAULT_STARTING_DATE;
    const start = new Date(startIso);
    start.setHours(0, 0, 0, 0);
    today.setHours(0, 0, 0, 0);
    
    const diffTime = today.getTime() - start.getTime();
    const currentDayIndex = Math.floor(diffTime / (1000 * 60 * 60 * 24));
    
    const totalHits = items.reduce((sum, it) => sum + (it.count || 0), 0);
    const targetItems = (currentDayIndex + 1) * ruleVal;
    const diffItems = totalHits - targetItems;
    const diffDays = Math.abs(Math.round(diffItems / ruleVal));
    
    if (diffItems >= 0) {
      return `ယနေ့ (${todayText}) အထိ ${diffDays} ရက် ကျော်လွန်နေပါတယ်။`;
    } else {
      return `ယနေ့ (${todayText}) အထိ ${diffDays} ရက် လိုအပ်နေပါတယ်။`;
    }
  }, [backfillingState, rule, cloudXDate, items]);

  // Group items by date (normalized to midnight)
  const historyData = useMemo(() => {
    const dailyCounts: Record<string, number> = {};
    for (const it of items) {
      if (!it.updatedAt) continue;
      const iso = new Date(it.updatedAt).toISOString().split('T')[0];
      dailyCounts[iso] = (dailyCounts[iso] || 0) + (it.count || 0);
    }
    return dailyCounts;
  }, [items]);

  const earliestMissDate = useMemo(() => {
    if (!startingDate) return null;
    const start = new Date(startingDate);
    start.setHours(0, 0, 0, 0);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    let current = new Date(start);
    const target = userDailyGoal ?? 500;
    for (let d = 0; d < 365; d++) {
      const iso = current.toISOString().split('T')[0];
      const count = historyData[iso] || 0;
      if (count < target) {
        return iso;
      }
      current.setDate(current.getDate() + 1);
    }
    return null;
  }, [historyData, startingDate, userDailyGoal]);

  useEffect(() => {
    setHasMounted(true);
    if (earliestMissDate && earliestSuccessRef.current) {
      setTimeout(() => {
        earliestSuccessRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }, 500);
    }
  }, [earliestMissDate]);

  const totalDays = useMemo(() => {
    if (!startingDate) return 0;
    const start = new Date(startingDate);
    start.setHours(0, 0, 0, 0);
    const end = new Date();
    end.setHours(0, 0, 0, 0);
    const diffTime = end.getTime() - start.getTime();
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24)) + 1; // +1 to include today
    return diffDays;
  }, [startingDate]);

  const monthsToRender = useMemo(() => {
    if (!startingDate) return [];
    const start = new Date(startingDate);
    const end = new Date();
    const months = [];
    
    let current = new Date(start.getFullYear(), start.getMonth(), 1);
    while (current <= end) {
      months.push({ year: current.getFullYear(), month: current.getMonth() });
      current.setMonth(current.getMonth() + 1);
    }
    return months.reverse(); // Show most recent first
  }, [startingDate]);

  if (!hasMounted || goalsLoading) {
    return (
      <div className="min-h-screen bg-[#0A0B0F] flex items-center justify-center">
        <div className="h-8 w-8 border-2 border-[#2CE08B] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <ErrorBoundary>
      <div className="min-h-screen bg-[#0A0B0F] text-white">
        <div
          className="min-h-screen"
          style={{
            background:
              "radial-gradient(1200px 800px at 50% 10%, rgba(255,255,255,0.08), rgba(0,0,0,0) 55%), radial-gradient(900px 600px at 50% 60%, rgba(44,224,139,0.09), rgba(0,0,0,0) 60%), #0A0B0F",
          }}
        >
          <div className="mx-auto w-full max-w-md px-4 pt-[calc(env(safe-area-inset-top)+20px)] pb-[calc(env(safe-area-inset-bottom)+118px)]">
            <header className="mb-8 text-center flex flex-col items-center">
              <div className="flex items-center gap-2 mb-1">
                <h1 className="text-[28px] font-bold tracking-tight">Study Journey</h1>
                <span className="text-[10px] font-medium text-white/20 mt-2">({formatDateDisplay(startingDate)})</span>
              </div>
              <div className="flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/5 border border-white/10 backdrop-blur-md">
                <span className="text-[11px] font-black text-white/30 uppercase tracking-widest">Progress</span>
                <span className="text-[16px] font-bold text-white tabular-nums">
                  {backfillingState?.clearedDaysCount || 0}/{totalDays}
                </span>
              </div>
            </header>

            <div className="space-y-4">
              {monthsToRender.map((m, i) => (
                <motion.div
                  key={`${m.year}-${m.month}`}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: Math.min(i * 0.05, 0.5) }} // Cap delay for performance
                  className="rounded-[32px] bg-white/5 border border-white/10 p-6 backdrop-blur-xl shadow-xl"
                >
                  <CalendarMonth 
                    year={m.year} 
                    month={m.month} 
                    startDay={startingDate} 
                    historyData={historyData}
                    userDailyGoal={userDailyGoal ?? 500}
                    earliestMissDate={earliestMissDate}
                    earliestSuccessRef={earliestSuccessRef}
                    onDateClick={(date, count, isTarget) => setSelectedDate({ date, count, isTarget })}
                    backfillingState={backfillingState}
                  />
                </motion.div>
              ))}
            </div>
          </div>
        </div>

        {/* Large Burmese Status Popup */}
        <AnimatePresence>
          {showStatusPopup && (
            <motion.div
              initial={{ opacity: 0, y: 20, scale: 0.95 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, scale: 0.9, transition: { duration: 0.5 } }}
              className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-[70] w-[90vw] max-w-md p-8 rounded-[32px] bg-gradient-to-br from-[#FF4D6D]/20 via-[#B36BFF]/20 to-[#49D2FF]/20 border border-white/20 backdrop-blur-2xl shadow-[0_50px_100px_rgba(0,0,0,0.5)] flex flex-col items-center gap-6 text-center"
            >
              <div className="absolute inset-0 bg-white/5 opacity-50 pointer-events-none" />
              
              <div className="flex items-center justify-between w-full relative z-10">
                <h2 className="text-[14px] font-black text-[#2CE08B] uppercase tracking-[0.2em]">Study Status</h2>
                <button 
                  onClick={() => setShowStatusPopup(false)} 
                  className="p-2 rounded-full bg-white/10 hover:bg-white/20 active:bg-white/30 transition-colors"
                >
                  <X className="w-5 h-5 text-white/60" />
                </button>
              </div>

              <div className="relative z-10 py-4">
                <p className="text-[24px] font-bold text-white leading-tight tracking-tight">
                  {statusPopupText}
                </p>
              </div>

              <div className="w-full relative z-10">
                <div className="w-full h-1.5 rounded-full bg-white/10 overflow-hidden border border-white/5">
                  <motion.div 
                    className="h-full bg-gradient-to-r from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF]" 
                    initial={{ width: "100%" }}
                    animate={{ width: "0%" }}
                    transition={{ duration: 10, ease: "linear" }}
                  />
                </div>
                <p className="mt-3 text-[10px] font-bold text-white/30 uppercase tracking-widest">Auto-closing in 10s</p>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Date Detail Notification */}
        <AnimatePresence>
          {selectedDate && (
            <motion.div
              initial={{ opacity: 0, y: 20, scale: 0.95 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 20, scale: 0.95 }}
              onClick={() => setSelectedDate(null)}
              className="fixed bottom-24 left-1/2 -translate-x-1/2 z-[70] w-auto whitespace-nowrap"
            >
              <div className="bg-white/10 border border-white/15 backdrop-blur-2xl px-6 py-3 rounded-2xl shadow-2xl flex items-center gap-3">
                <span className="text-[13px] font-bold text-white/90">
                  {selectedDate.count.toLocaleString()} Counts
                </span>
                <div className="h-3 w-[1px] bg-white/10" />
                <span className="text-[13px] font-medium text-white/40">
                  {new Date(selectedDate.date).toLocaleDateString("en-US", { month: "short", day: "numeric" })}
                </span>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </ErrorBoundary>
  );
}
