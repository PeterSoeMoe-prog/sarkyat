"use client";

import { useMemo, useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import ErrorBoundary from "@/components/ErrorBoundary";

import { DEFAULT_STARTING_DATE } from "@/lib/constants";

function CalendarMonth({ 
  year, 
  month, 
  startDay = DEFAULT_STARTING_DATE, 
  historyData, 
  dailyTarget, 
  earliestMissDate, 
  earliestSuccessRef,
  onDateClick,
  backfillingState
}: { 
  year: number; 
  month: number; 
  startDay?: string; 
  historyData: Record<string, number>; 
  dailyTarget: number;
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
    
    const displayCount = isCleared ? dailyTarget : (isTargetDate ? backfillingState.currentDayProgress : 0);

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
  const { startingDate: cloudStartingDate, goalsLoading, items, dailyTarget, backfillingState } = useVocabulary();
  const startingDate = cloudStartingDate || DEFAULT_STARTING_DATE;
  const [hasMounted, setHasMounted] = useState(false);
  const earliestSuccessRef = useRef<HTMLButtonElement | null>(null);
  
  // Date Detail State
  const [selectedDate, setSelectedDate] = useState<{ date: string; count: number; isTarget: boolean } | null>(null);

  // Group items by date (normalized to midnight)
  const historyData = useMemo(() => {
    const dailyCounts: Record<string, number> = {};
    items.forEach(it => {
      if (it.updatedAt) {
        const date = new Date(it.updatedAt);
        date.setHours(0, 0, 0, 0);
        const iso = date.toISOString().split('T')[0];
        dailyCounts[iso] = (dailyCounts[iso] || 0) + (it.count || 0);
      }
    });
    return dailyCounts;
  }, [items]);

  const earliestMissDate = useMemo(() => {
    if (!startingDate) return null;
    const start = new Date(startingDate);
    start.setHours(0, 0, 0, 0);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    let current = new Date(start);
    while (current <= today) {
      const iso = current.toISOString().split('T')[0];
      const count = historyData[iso] || 0;
      if (count < dailyTarget) {
        return iso;
      }
      current.setDate(current.getDate() + 1);
    }
    return null;
  }, [historyData, startingDate, dailyTarget]);

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
            <header className="mb-8 text-center">
              <h1 className="text-[28px] font-bold tracking-tight">Study Journey</h1>
              <div className="mt-2 inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-[#2CE08B]/10 border border-[#2CE08B]/20">
                <span className="text-[12px] font-black text-[#2CE08B] uppercase tracking-widest">Total Days:</span>
                <span className="text-[16px] font-bold text-white tabular-nums">{totalDays}</span>
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
                    dailyTarget={dailyTarget}
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
