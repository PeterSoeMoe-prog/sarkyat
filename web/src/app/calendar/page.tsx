"use client";

import { useMemo, useState, useEffect, useRef } from "react";
import { motion } from "framer-motion";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import ErrorBoundary from "@/components/ErrorBoundary";

import { DEFAULT_STARTING_DATE } from "@/lib/constants";

function CalendarMonth({ 
  year, 
  month, 
  startDay = DEFAULT_STARTING_DATE, 
  historyData, 
  dailyTarget, 
  earliestSuccessDate, 
  earliestSuccessRef 
}: { 
  year: number; 
  month: number; 
  startDay?: string; 
  historyData: Record<string, number>; 
  dailyTarget: number;
  earliestSuccessDate: string | null;
  earliestSuccessRef: React.RefObject<HTMLDivElement | null>;
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
    const isToday = currentDay.getTime() === today.getTime();
    const isStarted = currentDay >= startingDate && currentDay <= today;
    const dailyCount = historyData[isoString] || 0;
    const isSuccess = dailyCount >= dailyTarget;
    const isEarliestSuccess = isoString === earliestSuccessDate;
    
    days.push(
      <div 
        key={d} 
        ref={isEarliestSuccess ? earliestSuccessRef : null}
        className={`h-10 w-10 flex flex-col items-center justify-center rounded-xl text-[13px] font-bold transition-all relative
          ${isToday ? "bg-gradient-to-r from-[#FF4D6D] to-[#FFB020] text-white shadow-[0_8px_20px_rgba(255,77,109,0.3)] scale-110 z-10" : ""}
          ${!isToday && isSuccess ? "bg-[#2CE08B]/20 text-[#2CE08B] border border-[#2CE08B]/30 shadow-[0_0_15px_rgba(44,224,139,0.2)]" : ""}
          ${!isToday && !isSuccess && isStarted ? "bg-white/10 text-white/90 border border-white/5" : ""}
          ${!isStarted ? "text-white/20" : ""}
        `}
      >
        <span>{d}</span>
        {isSuccess && (
          <div className="absolute -bottom-1 h-1 w-1 rounded-full bg-[#2CE08B] shadow-[0_0_5px_#2CE08B]" />
        )}
      </div>
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
  const { startingDate: cloudStartingDate, goalsLoading, items, dailyTarget } = useVocabulary();
  const startingDate = cloudStartingDate || DEFAULT_STARTING_DATE;
  const [hasMounted, setHasMounted] = useState(false);
  const earliestSuccessRef = useRef<HTMLDivElement | null>(null);

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

  const earliestSuccessDate = useMemo(() => {
    if (!startingDate) return null;
    const start = new Date(startingDate);
    start.setHours(0, 0, 0, 0);
    const sortedDates = Object.keys(historyData)
      .filter(d => new Date(d) >= start && historyData[d] >= dailyTarget)
      .sort((a, b) => a.localeCompare(b));
    return sortedDates[0] || null;
  }, [historyData, startingDate, dailyTarget]);

  useEffect(() => {
    setHasMounted(true);
    if (earliestSuccessRef.current) {
      setTimeout(() => {
        earliestSuccessRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }, 500);
    }
  }, [earliestSuccessDate]);

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
                    earliestSuccessDate={earliestSuccessDate}
                    earliestSuccessRef={earliestSuccessRef}
                  />
                </motion.div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </ErrorBoundary>
  );
}
