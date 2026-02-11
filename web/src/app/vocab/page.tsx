"use client";

import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { VocabularyEntry, VocabularyStatus } from "@/lib/vocab/types";
import { useState, useMemo, Suspense, useEffect } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import { motion, AnimatePresence, useMotionValue, useTransform } from "framer-motion";
import ErrorBoundary from "@/components/ErrorBoundary";
import { upsertVocabulary, deleteVocabulary } from "@/lib/vocab/firestore";
import { LucidePlus, LucideX, LucideTrash2 } from "lucide-react";

type SortOption = "Recent" | "Count";

function VocabItem({ it, primaryLanguage, uid, onDelete, onClick }: { 
  it: VocabularyEntry, 
  primaryLanguage: string, 
  uid: string | null,
  onDelete: (id: string) => void,
  onClick: () => void
}) {
  const x = useMotionValue(0);
  const opacity = useTransform(x, [-100, -50, 0], [0, 1, 1]);
  const deleteOpacity = useTransform(x, [-100, -50], [1, 0]);
  const [isDeleting, setIsDeleting] = useState(false);

  const handleDragEnd = (_: any, info: any) => {
    if (info.offset.x < -80) {
      // Threshold met, trigger delete
      setIsDeleting(true);
      setTimeout(() => onDelete(it.id), 200);
    } else {
      // Snap back
      x.set(0);
    }
  };

  return (
    <div className="relative overflow-hidden rounded-2xl group">
      {/* Delete Background */}
      <motion.div 
        style={{ opacity: deleteOpacity }}
        className="absolute inset-0 bg-[#FF4D6D] flex items-center justify-end px-6"
      >
        <LucideTrash2 size={24} className="text-white" />
      </motion.div>

      <motion.div
        drag="x"
        dragConstraints={{ left: -100, right: 0 }}
        style={{ x }}
        onDragEnd={handleDragEnd}
        onClick={onClick}
        animate={isDeleting ? { x: -400, opacity: 0 } : {}}
        className="relative z-10 rounded-2xl bg-[#0A0B0F] border border-white/5 p-4 hover:bg-white/[0.08] transition-all cursor-pointer touch-pan-y"
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
    </div>
  );
}

function VocabContent() {
  const { items, loading, uid } = useVocabulary();
  
  const handleDelete = async (id: string) => {
    if (!uid) return;
    try {
      await deleteVocabulary(uid, id);
    } catch (err) {
      console.error("Delete failed:", err);
    }
  };
  
  // Local derivation of allCategories to avoid useVocabulary dependency issue
  const allCategories = useMemo(() => {
    const cats = new Set<string>();
    items.forEach(it => {
      if (it.category) cats.add(it.category.trim());
    });
    return Array.from(cats).sort();
  }, [items]);

  const searchParams = useSearchParams();
  const router = useRouter();
  const [searchQuery, setSearchQuery] = useState("");
  const [sortBy, setSortBy] = useState<SortOption>("Recent");
  const [sortOrder, setSortByOrder] = useState<"asc" | "desc">("desc");
  const [primaryLanguage, setPrimaryLanguage] = useState<"Thai" | "Myanmar">("Thai");

  const [isAdding, setIsAdding] = useState(false);
  const [newThai, setNewThai] = useState("");
  const [newBurmese, setNewBurmese] = useState("");
  const [newCategory, setNewCategory] = useState("");
  const [newStatus, setNewStatus] = useState<VocabularyStatus>("queue");
  const [isSaving, setIsSaving] = useState(false);

  const mode = searchParams.get("mode");

  useEffect(() => {
    if (mode === "add") {
      setIsAdding(true);
    }
  }, [mode]);

  const handleSaveNew = async () => {
    if (!uid || !newThai.trim()) return;
    setIsSaving(true);
    try {
      const newEntry: VocabularyEntry = {
        id: crypto.randomUUID(),
        thai: newThai.trim(),
        burmese: newBurmese.trim(),
        category: newCategory.trim() || "General",
        count: 0,
        status: newStatus,
        updatedAt: Date.now(),
      };
      await upsertVocabulary(uid, newEntry);
      setNewThai("");
      setNewBurmese("");
      setNewCategory("");
      setIsAdding(false);
      // Remove mode=add from URL without full reload
      router.replace("/vocab");
    } catch (err) {
      console.error("Save error:", err);
    } finally {
      setIsSaving(false);
    }
  };

  const categoryFilter = searchParams.get("category");

  const filteredAndSortedItems = useMemo(() => {
    let result = [...items];

    // Category filter from URL
    if (categoryFilter) {
      result = result.filter(
        (it) => (it.category?.trim() || "General") === categoryFilter
      );
    }

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
    } else if (sortBy === "Count") {
      result.sort((a, b) => {
        const countA = a.count || 0;
        const countB = b.count || 0;
        return sortOrder === "asc" ? countA - countB : countB - countA;
      });
    }

    return result;
  }, [items, searchQuery, sortBy, sortOrder, categoryFilter]);

  if (loading && items.length === 0) {
    return (
      <div className="min-h-screen bg-[#0A0B0F] flex items-center justify-center">
        <div className="h-8 w-8 border-2 border-[#B36BFF] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-md px-4 pt-[calc(env(safe-area-inset-top)+20px)] pb-[calc(env(safe-area-inset-bottom)+118px)] flex flex-col min-h-screen">
      <header className="mb-6 shrink-0">
        <div className="flex items-center justify-between pt-4 mb-4">
          <h1 className="text-2xl font-black text-white">Vocabulary</h1>
          <button
            onClick={() => setIsAdding(!isAdding)}
            className={`h-10 w-10 rounded-full flex items-center justify-center transition-all ${
              isAdding ? "bg-white/10 text-white/40" : "bg-[#B36BFF] text-white shadow-lg shadow-[#B36BFF]/20"
            }`}
          >
            {isAdding ? <LucideX size={20} /> : <LucidePlus size={20} />}
          </button>
        </div>

        <AnimatePresence>
          {isAdding && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }}
              className="overflow-hidden mb-6"
            >
              <div className="bg-white/5 border border-white/10 rounded-2xl p-4 space-y-4 shadow-xl">
                <div className="space-y-1.5">
                  <label className="text-[11px] font-black uppercase tracking-widest text-white/30 ml-1">Thai Word</label>
                  <input
                    type="text"
                    value={newThai}
                    onChange={(e) => setNewThai(e.target.value)}
                    placeholder="Enter Thai text..."
                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-[16px] focus:border-[#B36BFF]/50 outline-none transition-all"
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="text-[11px] font-black uppercase tracking-widest text-white/30 ml-1">Burmese Mean</label>
                  <input
                    type="text"
                    value={newBurmese}
                    onChange={(e) => setNewBurmese(e.target.value)}
                    placeholder="Enter Myanmar translation..."
                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-[16px] focus:border-[#B36BFF]/50 outline-none transition-all"
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="text-[11px] font-black uppercase tracking-widest text-white/30 ml-1">Category</label>
                  <input
                    type="text"
                    list="vocab-cat-suggestions"
                    value={newCategory}
                    onChange={(e) => setNewCategory(e.target.value)}
                    placeholder="General..."
                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-[16px] focus:border-[#B36BFF]/50 outline-none transition-all"
                  />
                  <datalist id="vocab-cat-suggestions">
                    {allCategories.map((c: string) => <option key={c} value={c} />)}
                  </datalist>
                </div>
                <div className="space-y-1.5">
                  <label className="text-[11px] font-black uppercase tracking-widest text-white/30 ml-1">Status</label>
                  <div className="flex gap-2">
                    {(["queue", "drill", "ready"] as const).map((s) => (
                      <button
                        key={s}
                        type="button"
                        onClick={() => setNewStatus(s)}
                        className={`flex-1 py-3 rounded-xl border transition-all text-[20px] ${
                          newStatus === s 
                            ? "bg-white/20 border-white/40 shadow-inner" 
                            : "bg-white/5 border-white/10 opacity-40 hover:opacity-100"
                        }`}
                      >
                        {s === "ready" ? "💎" : s === "queue" ? "😮" : "🔥"}
                      </button>
                    ))}
                  </div>
                </div>
                <button
                  disabled={isSaving || !newThai.trim()}
                  onClick={handleSaveNew}
                  className="w-full bg-gradient-to-r from-[#B36BFF] to-[#FF4D6D] py-4 rounded-xl text-white font-black text-[15px] shadow-lg shadow-[#B36BFF]/20 active:scale-[0.98] transition-all disabled:opacity-50"
                >
                  {isSaving ? "Saving..." : "Add to Library"}
                </button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Search and Filter */}
        <div className="space-y-3 mb-4">
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

          <div className="flex gap-2 overflow-x-auto pb-2 no-scrollbar items-center justify-between">
            <div className="flex gap-2">
              <button
                onClick={() => setSortBy("Recent")}
                className={`whitespace-nowrap px-4 py-2 rounded-full text-[12px] font-bold transition-all border ${
                  sortBy === "Recent"
                    ? "bg-[#B36BFF] border-[#B36BFF] text-white shadow-[0_0_15px_rgba(179,107,255,0.3)]"
                    : "bg-white/5 border-white/10 text-white/40 hover:bg-white/10"
                }`}
              >
                Recent
              </button>
              <button
                onClick={() => {
                  if (sortBy === "Count") {
                    setSortByOrder(sortOrder === "asc" ? "desc" : "asc");
                  } else {
                    setSortBy("Count");
                    setSortByOrder("desc"); // Default to desc on first tap
                  }
                }}
                className={`whitespace-nowrap px-4 py-2 rounded-full text-[12px] font-bold transition-all border flex items-center gap-1 ${
                  sortBy === "Count"
                    ? "bg-[#B36BFF] border-[#B36BFF] text-white shadow-[0_0_15px_rgba(179,107,255,0.3)]"
                    : "bg-white/5 border-white/10 text-white/40 hover:bg-white/10"
                }`}
              >
                Count ({sortBy === "Count" ? (sortOrder === "asc" ? "A-Z" : "Z-A") : "A-Z"})
              </button>
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

        {/* Active Category Chip */}
        {categoryFilter && (
          <div className="flex items-center justify-between bg-[#B36BFF]/10 border border-[#B36BFF]/20 rounded-2xl p-4">
            <div className="flex items-center gap-3">
              <span className="text-xl">👑</span>
              <div>
                <p className="text-[10px] font-black text-[#B36BFF] uppercase tracking-widest leading-none mb-1">Category</p>
                <h2 className="text-[18px] font-bold text-white tracking-tight leading-none">{categoryFilter}</h2>
              </div>
            </div>
            <button 
              onClick={() => router.push("/vocab")}
              className="h-8 w-8 flex items-center justify-center rounded-full bg-white/5 hover:bg-white/10 text-white/40 transition-all"
            >
              ✕
            </button>
          </div>
        )}
      </header>

      {/* List */}
      <div className="flex-1 space-y-2 pb-20 overflow-y-auto no-scrollbar">
        <AnimatePresence mode="popLayout">
          {filteredAndSortedItems.map((it) => (
            <VocabItem
              key={it.id}
              it={it}
              primaryLanguage={primaryLanguage}
              uid={uid}
              onDelete={handleDelete}
              onClick={() => router.push(`/counter?id=${it.id}`)}
            />
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
  );
}

export default function VocabPage() {
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
          <Suspense fallback={
            <div className="min-h-screen bg-[#0A0B0F] flex items-center justify-center">
              <div className="h-8 w-8 border-2 border-[#B36BFF] border-t-transparent rounded-full animate-spin" />
            </div>
          }>
            <VocabContent />
          </Suspense>
        </div>
      </div>
    </ErrorBoundary>
  );
}
