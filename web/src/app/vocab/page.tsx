"use client";

import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { useState, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import ErrorBoundary from "@/components/ErrorBoundary";

type SortOption = "Recent" | "Count (A-Z)" | "Count (Z-A)";

export default function VocabPage() {
  const { items, loading } = useVocabulary();
  const [searchQuery, setSearchQuery] = useState("");
  const [sortBy, setSortBy] = useState<SortOption>("Recent");

  const filteredAndSortedItems = useMemo(() => {
    let result = [...items];

    // Search filter
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(
        (it) =>
          it.thai.toLowerCase().includes(q) ||
          (it.burmese && it.burmese.toLowerCase().includes(q))
      );
    }

    // Sorting
    if (sortBy === "Recent") {
      result.sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0));
    } else if (sortBy === "Count (A-Z)") {
      result.sort((a, b) => (a.count || 0) - (b.count || 0));
    } else if (sortBy === "Count (Z-A)") {
      result.sort((a, b) => (b.count || 0) - (a.count || 0));
    }

    return result;
  }, [items, searchQuery, sortBy]);

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
            <header className="mb-6">
              <h1 className="text-[34px] font-bold tracking-tighter bg-gradient-to-r from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF] bg-clip-text text-transparent mb-6">
                Sar Kyat Pro
              </h1>

              {/* Search and Filter */}
              <div className="space-y-3">
                <div className="relative">
                  <input
                    type="text"
                    placeholder="Search vocabulary..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-3.5 text-[15px] focus:outline-none focus:border-[#B36BFF]/50 transition-all placeholder:text-white/20"
                  />
                  <div className="absolute right-4 top-1/2 -translate-y-1/2 text-white/20">
                    🔍
                  </div>
                </div>

                <div className="flex gap-2 overflow-x-auto pb-2 no-scrollbar">
                  {(["Recent", "Count (A-Z)", "Count (Z-A)"] as SortOption[]).map((opt) => (
                    <button
                      key={opt}
                      onClick={() => setSortBy(opt)}
                      className={`whitespace-nowrap px-4 py-2 rounded-full text-[12px] font-bold transition-all border ${
                        sortBy === opt
                          ? "bg-[#B36BFF] border-[#B36BFF] text-white shadow-[0_0_15px_rgba(179,107,255,0.3)]"
                          : "bg-white/5 border-white/10 text-white/40 hover:bg-white/10"
                      }`}
                    >
                      {opt}
                    </button>
                  ))}
                </div>
              </div>
            </header>

            {/* List */}
            <div className="space-y-2">
              <AnimatePresence mode="popLayout">
                {filteredAndSortedItems.map((it) => (
                  <motion.div
                    key={it.id}
                    layout
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, scale: 0.95 }}
                    className="group relative rounded-2xl bg-white/5 border border-white/5 p-4 hover:bg-white/[0.08] transition-all overflow-hidden"
                  >
                    <div className="flex items-center justify-between gap-4">
                      <div className="flex-1 min-w-0">
                        <div className="text-[17px] font-bold text-white tracking-tight mb-0.5 truncate">
                          {it.thai}
                        </div>
                        <div className="text-[13px] font-medium text-white/40 truncate">
                          {it.burmese || "—"}
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <div className="px-3 py-1.5 rounded-xl bg-black/20 border border-white/5 min-w-[48px] text-center">
                          <span className="text-[14px] font-black text-[#2CE08B] tabular-nums">
                            {it.count || 0}
                          </span>
                        </div>
                      </div>
                    </div>
                    {/* Light streak effect on hover */}
                    <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/[0.03] to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-in-out pointer-events-none" />
                  </motion.div>
                ))}
              </AnimatePresence>

              {filteredAndSortedItems.length === 0 && (
                <div className="py-20 text-center">
                  <div className="text-[40px] mb-4">📭</div>
                  <div className="text-white/20 font-bold">No vocabulary found</div>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </ErrorBoundary>
  );
}
