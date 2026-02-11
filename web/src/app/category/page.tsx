"use client";

import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { motion, AnimatePresence } from "framer-motion";
import ErrorBoundary from "@/components/ErrorBoundary";
import { useMemo, useState } from "react";
import { VocabularyEntry } from "@/lib/vocab/types";
import { LucideX } from "lucide-react";

import Link from "next/link";

type CategoryStats = {
  name: string;
  done: number;
  total: number;
  percentage: number;
  color: string;
  glow: string;
};

import { parseThaiWord } from "@/lib/vocab/thaiParser";

function CategoryCircle({ stats, isSelected, onClick }: { stats: CategoryStats, isSelected: boolean, onClick: () => void }) {
  const radius = 60;
  const stroke = 4;
  const normalizedRadius = radius - stroke * 2;
  const circumference = normalizedRadius * 2 * Math.PI;
  const strokeDashoffset = circumference - (stats.percentage / 100) * circumference;

  return (
    <motion.div 
      onClick={onClick}
      whileTap={{ scale: 0.95 }}
      className={`flex flex-col items-center justify-center p-1 cursor-pointer transition-all duration-300 rounded-3xl ${isSelected ? 'bg-white/10 ring-1 ring-white/20' : 'hover:bg-white/5'}`}
    >
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
              filter: isSelected ? `drop-shadow(0 0 12px ${stats.glow})` : `drop-shadow(0 0 6px ${stats.glow})`
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
          <span className="text-[18px] mb-0.5">👑</span>
          <span className="text-[12px] font-bold text-white tracking-tight leading-tight px-2 line-clamp-2">{stats.name}</span>
          <span className="text-[10px] font-bold text-white/60 mt-0.5">{stats.done}/{stats.total}</span>
        </div>
      </div>
    </motion.div>
  );
}

function VocabList({ categoryName, items, onClose }: { categoryName: string, items: VocabularyEntry[], onClose: () => void }) {
  const router = useRouter();
  const [searchQuery, setSearchQuery] = useState("");
  const [primaryLanguage, setPrimaryLanguage] = useState<"Thai" | "Myanmar">("Thai");

  const filteredItems = useMemo(() => {
    if (!searchQuery.trim()) return items;
    const q = searchQuery.toLowerCase();
    return items.filter(it => 
      it.thai.toLowerCase().includes(q) || 
      (it.burmese && it.burmese.toLowerCase().includes(q))
    );
  }, [items, searchQuery]);

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-[100] bg-[#0A0B0F] flex flex-col"
    >
      <div className="mx-auto w-full max-w-md px-4 pt-[calc(env(safe-area-inset-top)+20px)] flex flex-col h-full">
        <header className="mb-6 shrink-0">
          <div className="flex items-center justify-between pt-4 mb-4">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-2xl bg-[#B36BFF]/10 flex items-center justify-center text-xl shadow-inner border border-[#B36BFF]/20">👑</div>
              <div>
                <p className="text-[10px] font-black text-[#B36BFF] uppercase tracking-widest leading-none mb-1">Category</p>
                <h2 className="text-[20px] font-bold text-white tracking-tight leading-none">{categoryName}</h2>
              </div>
            </div>
            <button 
              onClick={onClose}
              className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 hover:bg-white/10 transition-all"
            >
              <LucideX size={20} className="text-white/40" />
            </button>
          </div>

          <div className="space-y-3 mb-4">
            <div className="relative">
              <input
                type="text"
                placeholder={`Search in ${categoryName}...`}
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-[15px] focus:outline-none focus:border-[#B36BFF]/50 transition-all placeholder:text-white/20"
              />
              <div className="absolute right-4 top-1/2 -translate-y-1/2 text-white/20">
                🔍
              </div>
            </div>

            <div className="flex gap-2 overflow-x-auto pb-2 no-scrollbar items-center justify-between">
              <div className="flex items-center">
                <span className="text-[11px] font-bold text-white/20 uppercase tracking-widest">{filteredItems.length} items</span>
              </div>

              {/* Language Toggle */}
              <div className="flex bg-white/5 rounded-full p-1 border border-white/10 ml-4">
                {(["Thai", "Myanmar"] as const).map((lang) => (
                  <button
                    key={lang}
                    onClick={() => setPrimaryLanguage(lang)}
                    className={`px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest transition-all ${
                      primaryLanguage === lang
                        ? "bg-white/20 text-white shadow-sm"
                        : "text-white/30 hover:text-white/60"
                    }`}
                  >
                    {lang}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </header>

        {/* List */}
        <div className="flex-1 space-y-2 pb-20 overflow-y-auto no-scrollbar">
          <AnimatePresence mode="popLayout">
            {filteredItems.map((it, idx) => (
              <motion.div
                key={it.id}
                layout
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.95 }}
                transition={{ delay: idx * 0.02 }}
                onClick={() => router.push(`/counter?id=${it.id}`)}
                className="group relative rounded-2xl bg-white/5 border border-white/5 p-4 hover:bg-white/[0.08] transition-all overflow-hidden cursor-pointer"
              >
                <div className="flex items-center justify-between gap-4">
                  <div className="flex-1 min-w-0">
                    <div className="text-[17px] font-bold text-white tracking-tight mb-0.5 truncate">
                      {primaryLanguage === "Thai" ? it.thai : (it.burmese || "—")}
                    </div>
                    <div className="text-[13px] font-medium text-white/40 truncate">
                      {primaryLanguage === "Thai" ? (it.burmese || "—") : it.thai}
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <div className="px-3 py-1.5 rounded-xl bg-black/20 border border-white/5 min-w-[48px] text-center">
                      <span className="text-[14px] font-black text-[#2CE08B] tabular-nums">
                        {(it.count || 0).toLocaleString()}
                      </span>
                    </div>
                  </div>
                </div>
                <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/[0.03] to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-in-out pointer-events-none" />
              </motion.div>
            ))}
          </AnimatePresence>

          {filteredItems.length === 0 && (
            <div className="py-20 text-center">
              <div className="text-[40px] mb-4">📭</div>
              <div className="text-white/20 font-bold">No vocabulary found</div>
            </div>
          )}
        </div>
      </div>
    </motion.div>
  );
}

import { useRouter } from "next/navigation";

export default function CategoryPage() {
  const router = useRouter();
  const { items, loading } = useVocabulary();
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);

  const categoryData = useMemo(() => {
    const cats: Record<string, { done: number; total: number }> = {};
    
    console.log("CategoryPage: Processing items", items.length);
    
    items.forEach(item => {
      const name = item.category?.trim() || "General";
      if (!cats[name]) cats[name] = { done: 0, total: 0 };
      cats[name].total++;
      if (item.status === "ready") cats[name].done++;
    });

    console.log("CategoryPage: Category groups", Object.keys(cats));

    const colors = [
      { border: "#FF4D6D", glow: "rgba(255,77,109,0.5)" },
      { border: "#B36BFF", glow: "rgba(179,107,255,0.5)" },
      { border: "#49D2FF", glow: "rgba(73,210,255,0.5)" },
      { border: "#2CE08B", glow: "rgba(44,224,139,0.5)" },
      { border: "#FFB020", glow: "rgba(255,176,32,0.5)" },
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

  const filteredItems = useMemo(() => {
    if (!selectedCategory) return [];
    const filtered = items.filter(it => (it.category?.trim() || "General") === selectedCategory);
    console.log(`CategoryPage: Filtered items for ${selectedCategory}`, filtered.length);
    return filtered;
  }, [items, selectedCategory]);

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
          <div className="mx-auto w-full max-w-md px-4 pt-[calc(env(safe-area-inset-top)+20px)] pb-[calc(env(safe-area-inset-bottom)+118px)]">
            <div className="text-center flex flex-col items-center justify-center mb-8">
              <div className="relative inline-flex items-center justify-center">
                <h1 className="text-[34px] font-bold tracking-tighter bg-gradient-to-r from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF] bg-clip-text text-transparent">
                  Category
                </h1>
                <div className="absolute left-full top-0 ml-2">
                  <div className="px-3 py-1 rounded-full bg-white/10 border border-white/10 backdrop-blur-md">
                    <span className="text-[14px] font-black text-white/60 tabular-nums">
                      {categoryData.length}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-3 gap-2 px-1">
              {categoryData.map((cat) => (
                <CategoryCircle 
                  key={cat.name} 
                  stats={cat} 
                  isSelected={selectedCategory === cat.name}
                  onClick={() => {
                    setSelectedCategory(cat.name);
                  }}
                />
              ))}
            </div>

            <AnimatePresence>
              {selectedCategory && (
                <>
                  {/* Backdrop */}
                  <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    onClick={() => setSelectedCategory(null)}
                    className="fixed inset-0 z-[90] bg-black/60 backdrop-blur-sm"
                  />
                  <VocabList 
                    key={selectedCategory}
                    categoryName={selectedCategory} 
                    items={filteredItems} 
                    onClose={() => setSelectedCategory(null)}
                  />
                </>
              )}
            </AnimatePresence>
          </div>
        </div>
      </div>
    </ErrorBoundary>
  );
}
