"use client";

import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { motion, AnimatePresence } from "framer-motion";
import ErrorBoundary from "@/components/ErrorBoundary";
import { useMemo, useState } from "react";
import { VocabularyEntry } from "@/lib/vocab/types";

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
  const { vocabLogic } = useVocabulary();

  return (
    <motion.div
      initial={{ opacity: 0, y: "100%" }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: "100%" }}
      transition={{ type: "spring", damping: 25, stiffness: 200 }}
      className="fixed inset-x-0 bottom-0 z-[100] h-[80vh] rounded-t-[32px] bg-[#1A1B23] border-t border-white/10 shadow-[0_-20px_80px_rgba(0,0,0,0.5)] flex flex-col max-w-md mx-auto"
    >
      <div className="p-6 border-b border-white/5 flex items-center justify-between shrink-0">
        <div>
          <p className="text-[10px] font-black text-[#B36BFF] uppercase tracking-widest leading-none mb-1">Category</p>
          <h3 className="text-[20px] font-bold text-white tracking-tight">{categoryName}</h3>
        </div>
        <button 
          onClick={onClose}
          className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 hover:bg-white/10 transition-colors"
        >
          <span className="text-[20px] text-white/40">✕</span>
        </button>
      </div>
      <div className="flex-1 overflow-y-auto custom-scrollbar px-2 pb-10">
        <div className="divide-y divide-white/5">
          {items.map((item, idx) => {
            const breakdown = vocabLogic ? parseThaiWord(item.thai, vocabLogic) : [];
            return (
              <motion.div 
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: idx * 0.02 }}
                key={item.id} 
                onClick={() => router.push(`/counter?id=${item.id}`)}
                className="p-5 flex flex-col hover:bg-white/5 transition-colors group cursor-pointer"
              >
                <div className="flex items-center justify-between gap-4 mb-3">
                  <div className="flex-1 min-w-0 pr-4">
                    <h4 className="text-[18px] font-bold text-white group-hover:text-[#49D2FF] transition-colors truncate">{item.thai}</h4>
                    <p className="text-[14px] font-medium text-white/40 truncate">{item.burmese || 'No translation'}</p>
                  </div>
                  <div className="text-right shrink-0">
                    <span className="text-[16px] font-black text-white/20 tabular-nums">
                      {(item.count || 0).toLocaleString()}
                    </span>
                  </div>
                </div>
                
                {breakdown.length > 0 && (
                  <div className="flex flex-wrap gap-1.5 opacity-60 group-hover:opacity-100 transition-opacity">
                    {breakdown.map((b, bIdx) => (
                      <div key={bIdx} className="flex flex-col items-center px-2 py-1 rounded-lg bg-white/5 border border-white/5 min-w-[32px]">
                        <span className="text-[12px] font-bold text-white/80">{b.char}</span>
                        <span className="text-[8px] font-black text-[#FF4D6D] uppercase leading-none mt-0.5">
                          {b.type === 'consonant' ? 'ဗျည်း' : b.type === 'vowel' ? 'သရ' : b.type === 'tone' ? 'Tone' : b.type === 'final' ? 'အသတ်ဗျည်း' : '-'}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </motion.div>
            );
          })}
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
