"use client";

import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { motion } from "framer-motion";
import ErrorBoundary from "@/components/ErrorBoundary";
import { useMemo } from "react";

type CategoryStats = {
  name: string;
  done: number;
  total: number;
  percentage: number;
  color: string;
  glow: string;
};

function CategoryCircle({ stats }: { stats: CategoryStats }) {
  const radius = 70;
  const stroke = 6;
  const normalizedRadius = radius - stroke * 2;
  const circumference = normalizedRadius * 2 * Math.PI;
  const strokeDashoffset = circumference - (stats.percentage / 100) * circumference;

  return (
    <div className="flex flex-col items-center justify-center p-2">
      <div className="relative" style={{ width: radius * 2, height: radius * 2 }}>
        <svg
          height={radius * 2}
          width={radius * 2}
          className="transform -rotate-90"
        >
          <circle
            stroke="rgba(255,255,255,0.05)"
            fill="transparent"
            strokeWidth={stroke}
            r={normalizedRadius}
            cx={radius}
            cy={radius}
          />
          <motion.circle
            stroke={stats.color}
            fill="transparent"
            strokeWidth={stroke}
            strokeDasharray={circumference + " " + circumference}
            style={{ 
              strokeDashoffset,
              filter: `drop-shadow(0 0 8px ${stats.glow})`
            }}
            strokeLinecap="round"
            initial={{ strokeDashoffset: circumference }}
            animate={{ strokeDashoffset }}
            transition={{ duration: 1.5, ease: "easeOut" }}
            r={normalizedRadius}
            cx={radius}
            cy={radius}
          />
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
          <span className="text-[20px] mb-1">👑</span>
          <span className="text-[14px] font-bold text-white tracking-tight leading-tight px-2">{stats.name}</span>
          <span className="text-[12px] font-bold text-white/60 mt-0.5">{stats.done}/{stats.total}</span>
          <span className="text-[10px] font-black text-white/40 uppercase tracking-tighter mt-0.5">{stats.percentage}% Done</span>
        </div>
      </div>
    </div>
  );
}

export default function CategoryPage() {
  const { items, loading } = useVocabulary();

  const categoryData = useMemo(() => {
    const cats: Record<string, { done: number; total: number }> = {};
    
    items.forEach(item => {
      const name = item.category || "General";
      if (!cats[name]) cats[name] = { done: 0, total: 0 };
      cats[name].total++;
      if (item.status === "ready") cats[name].done++;
    });

    const colors = [
      { border: "#FF4D6D", glow: "rgba(255,77,109,0.5)" }, // Pink
      { border: "#B36BFF", glow: "rgba(179,107,255,0.5)" }, // Purple
      { border: "#49D2FF", glow: "rgba(73,210,255,0.5)" }, // Blue
      { border: "#2CE08B", glow: "rgba(44,224,139,0.5)" }, // Green
      { border: "#FFB020", glow: "rgba(255,176,32,0.5)" }, // Gold
    ];

    return Object.entries(cats).map(([name, data], idx) => ({
      name,
      done: data.done,
      total: data.total,
      percentage: data.total > 0 ? Math.round((data.done / data.total) * 100) : 0,
      color: colors[idx % colors.length].border,
      glow: colors[idx % colors.length].glow
    })).sort((a, b) => a.name.localeCompare(b.name));
  }, [items]);

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0A0B0F] flex items-center justify-center">
        <div className="h-8 w-8 border-2 border-[#B36BFF] border-t-transparent rounded-full animate-spin" />
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
              "radial-gradient(1200px 800px at 50% 10%, rgba(255,255,255,0.05), rgba(0,0,0,0) 55%), radial-gradient(900px 600px at 50% 60%, rgba(179,107,255,0.07), rgba(0,0,0,0) 60%), #0A0B0F",
          }}
        >
          <div className="mx-auto w-full max-w-md px-2 pt-[calc(env(safe-area-inset-top)+20px)] pb-[calc(env(safe-area-inset-bottom)+118px)]">
            <header className="mb-8 text-center">
              <h1 className="text-[34px] font-bold tracking-tight bg-gradient-to-r from-[#FF4D6D] to-[#49D2FF] bg-clip-text text-transparent">
                Category
              </h1>
            </header>

            <div className="grid grid-cols-3 gap-x-1 gap-y-4 px-1">
              {categoryData.map((cat) => (
                <CategoryCircle key={cat.name} stats={cat} />
              ))}
            </div>
          </div>
        </div>
      </div>
    </ErrorBoundary>
  );
}
