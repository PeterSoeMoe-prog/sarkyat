"use client";

import { useMemo, useState, useEffect } from "react";
import { motion } from "framer-motion";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import ErrorBoundary from "@/components/ErrorBoundary";

function CalendarMonth({ year, month, startDay }: { year: number; month: number; startDay: string }) {
  const monthName = new Date(year, month).toLocaleString("default", { month: "long" });
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const firstDayOfMonth = new Date(year, month, 1).getDay(); // 0 = Sunday, 1 = Monday, etc.
  
  const startingDate = new Date(startDay);
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const days = [];
  // Empty slots for days before the 1st of the month
  for (let i = 0; i < firstDayOfMonth; i++) {
    days.push(<div key={`empty-${i}`} className="h-10 w-10" />);
  }

  for (let d = 1; d <= daysInMonth; d++) {
    const currentDay = new Date(year, month, d);
    const isToday = currentDay.getTime() === today.getTime();
    const isStarted = currentDay >= startingDate && currentDay <= today;
    
    days.push(
      <div 
        key={d} 
        className={`h-10 w-10 flex items-center justify-center rounded-xl text-[13px] font-bold transition-all
          ${isToday ? "bg-gradient-to-r from-[#FF4D6D] to-[#FFB020] text-white shadow-lg scale-110 z-10" : ""}
          ${!isToday && isStarted ? "bg-white/10 text-white/90 border border-white/5" : ""}
          ${!isStarted ? "text-white/20" : ""}
        `}
      >
        {d}
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
  const { startingDate, goalsLoading } = useVocabulary();
  const [hasMounted, setHasMounted] = useState(false);

  useEffect(() => {
    setHasMounted(true);
  }, []);

  const totalDays = useMemo(() => {
    if (!startingDate) return 0;
    const start = new Date(startingDate);
    const end = new Date();
    const diffTime = Math.abs(end.getTime() - start.getTime());
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
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
                  transition={{ delay: i * 0.1 }}
                  className="rounded-[32px] bg-white/5 border border-white/10 p-6 backdrop-blur-xl shadow-xl"
                >
                  <CalendarMonth year={m.year} month={m.month} startDay={startingDate} />
                </motion.div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </ErrorBoundary>
  );
}
