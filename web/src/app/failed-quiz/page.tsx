"use client";

import { useEffect, useState, useMemo } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import Link from "next/link";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { fetchFailedQuizIds, saveFailedQuizIds } from "@/lib/vocab/firestore";

export default function FailedQuizPage() {
  const router = useRouter();
  const { items, loading, uid } = useVocabulary();
  const [failedIds, setFailedIds] = useState<string[]>([]);

  useEffect(() => {
    if (uid) {
      fetchFailedQuizIds(uid).then(ids => {
        setFailedIds(ids);
      });
    } else {
      const stored = localStorage.getItem("failed_quiz_ids");
      if (stored) {
        try {
          setFailedIds(JSON.parse(stored));
        } catch (e) {
          console.error("Failed to parse failed_quiz_ids", e);
        }
      }
    }
  }, [uid]);

  const failedItems = useMemo(() => {
    // Filter items that are in failedIds AND are NOT in 'ready' status
    return items
      .filter((it) => failedIds.includes(it.id) && it.status !== "ready")
      .sort((a, b) => {
        const indexA = failedIds.indexOf(a.id);
        const indexB = failedIds.indexOf(b.id);
        return indexA - indexB; // Maintain original order (existing on top, new below)
      });
  }, [items, failedIds]);

  // Clean up persistent IDs if they are now 'ready'
  useEffect(() => {
    if (uid && failedIds.length > 0) {
      const currentValidIds = failedIds.filter(id => {
        const item = items.find(it => it.id === id);
        return !item || item.status !== "ready";
      });

      if (currentValidIds.length !== failedIds.length) {
        setFailedIds(currentValidIds);
        saveFailedQuizIds(uid, currentValidIds);
      }
    }
  }, [items, uid, failedIds]);

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0A0B0F] flex items-center justify-center">
        <div className="text-white/60 font-bold tracking-widest uppercase">Loading...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0A0B0F] text-white overflow-x-hidden">
      <div
        className="min-h-screen"
        style={{
          background:
            "radial-gradient(1200px 800px at 50% 10%, rgba(255,255,255,0.08), rgba(0,0,0,0) 55%), #0A0B0F",
        }}
      >
        <div className="mx-auto w-full max-w-md px-4 pt-8 pb-32">
          <header className="flex items-center justify-between mb-8">
            <Link 
              href="/quiz" 
              className="rounded-full bg-white/5 px-4 py-2 text-[13px] font-semibold text-white/60 border border-white/10"
            >
              Back
            </Link>
            <div className="text-[17px] font-bold tracking-tight">ဒါတွေ ပြန်ကျက်ဖို့လိုမယ်</div>
            <div className="w-[60px]" />
          </header>

          <div className="space-y-3 mb-12">
            {failedItems.length === 0 ? (
              <div className="text-center py-20 bg-white/5 rounded-[32px] border border-white/10">
                <div className="text-4xl mb-4">✨</div>
                <p className="text-white/40 font-medium">No failed words to show!</p>
              </div>
            ) : (
              failedItems.map((item) => (
                <motion.div
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  key={item.id}
                  onClick={() => router.push(`/counter?id=${item.id}`)}
                  className="bg-white/5 border border-white/10 rounded-2xl p-5 cursor-pointer hover:bg-white/10 transition-colors"
                >
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-2xl font-bold">{item.thai}</span>
                    <span className="px-2 py-1 rounded-md bg-[#FF4D6D]/20 text-[#FF4D6D] text-[10px] font-black uppercase tracking-wider">
                      DRILL
                    </span>
                  </div>
                  <div className="text-white/60 font-medium text-lg mb-1">{item.burmese}</div>
                  {item.ai_explanation && (
                    <div className="mt-3 text-white/30 text-xs leading-relaxed border-t border-white/5 pt-3 italic">
                      {item.ai_explanation}
                    </div>
                  )}
                </motion.div>
              ))
            )}
          </div>
          
          <div className="mt-8 mb-12">
            <Link 
              href="/quiz"
              className="w-full py-4 rounded-2xl bg-gradient-to-r from-[#FF4D6D] to-[#B36BFF] font-black text-lg shadow-lg flex items-center justify-center active:scale-[0.98] transition-transform"
            >
              Try Again
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
