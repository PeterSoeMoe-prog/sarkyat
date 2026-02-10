"use client";

import { motion, AnimatePresence } from "framer-motion";
import { useRouter } from "next/navigation";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { useState, useMemo } from "react";
import { LucideBrain, LucidePlus, LucideSettings, LucideRefreshCcw, LucideChevronLeft, LucideUser, LucideSparkles, LucideInfo } from "lucide-react";
import { upsertVocabulary, deleteVocabulary } from "@/lib/vocab/firestore";
import { suggestVocabulary, detectDuplicates } from "@/lib/gemini";
import ErrorBoundary from "@/components/ErrorBoundary";

interface Suggestion {
  thai: string;
  burmese: string;
  category: string;
  reason?: string;
}

interface DuplicateGroup {
  thai: string;
  ids: string[];
  reason: string;
}

function AiPlusContent() {
  const router = useRouter();
  const { items, uid, userContext, updateUserContext, contextLoading, aiApiKey } = useVocabulary();
  
  const [activeTab, setActiveTab] = useState<"suggest" | "clean">("suggest");
  const [isGenerating, setIsGenerating] = useState(false);
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [duplicates, setDuplicates] = useState<DuplicateGroup[]>([]);
  const [showSettings, setShowSettings] = useState(false);
  
  const [profession, setProfession] = useState(userContext?.profession || "");
  const [interests, setInterests] = useState(userContext?.interests || "");

  const handleSaveContext = async () => {
    await updateUserContext({ profession, interests });
    setShowSettings(false);
  };

  const generateSuggestions = async () => {
    if (!aiApiKey) {
      alert("Please add your Gemini API Key in Settings first.");
      return;
    }
    
    setIsGenerating(true);
    try {
      const currentVocab = items.map(it => it.thai);
      const context = {
        profession: userContext?.profession,
        interests: userContext?.interests
      };
      
      const responseText = await suggestVocabulary(aiApiKey, currentVocab, context);
      const suggestedData = JSON.parse(responseText);
      
      if (Array.isArray(suggestedData)) {
        setSuggestions(suggestedData);
      }
    } catch (err) {
      console.error(err);
      alert("Failed to generate suggestions. Please check your API key and connection.");
    } finally {
      setIsGenerating(false);
    }
  };

  const generateCleanSuggestions = async () => {
    if (!aiApiKey) {
      alert("Please add your Gemini API Key in Settings first.");
      return;
    }
    
    setIsGenerating(true);
    try {
      const vocabList = items.map(it => ({ id: it.id, thai: it.thai, burmese: it.burmese }));
      const responseText = await detectDuplicates(aiApiKey, vocabList);
      const duplicateData = JSON.parse(responseText);
      
      if (Array.isArray(duplicateData)) {
        setDuplicates(duplicateData);
      }
    } catch (err) {
      console.error(err);
      alert("Failed to detect duplicates. Please check your API key and connection.");
    } finally {
      setIsGenerating(false);
    }
  };

  const handleDeleteEntry = async (id: string) => {
    if (!uid) return;
    try {
      await deleteVocabulary(uid, id);
      // Update local state to reflect deletion in the UI
      setDuplicates(prev => prev.map(group => ({
        ...group,
        ids: group.ids.filter(i => i !== id)
      })).filter(group => group.ids.length > 1));
    } catch (err) {
      console.error("Delete error:", err);
    }
  };

  const handleAddSuggested = async (sug: Suggestion) => {
    if (!uid) return;
    const newEntry = {
      id: crypto.randomUUID(),
      thai: sug.thai,
      burmese: sug.burmese,
      category: sug.category,
      count: 0,
      status: "queue" as const,
      updatedAt: Date.now(),
    };
    await upsertVocabulary(uid, newEntry);
    setSuggestions(prev => prev.filter(s => s.thai !== sug.thai));
  };

  return (
    <div className="min-h-screen bg-[#0A0B0F] text-white">
      {/* Header */}
      <header className="px-4 pt-[calc(env(safe-area-inset-top)+10px)] pb-4 flex items-center justify-between border-b border-white/5 bg-black/20 backdrop-blur-xl sticky top-0 z-50">
        <button onClick={() => router.push("/home")} className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 active:scale-95 transition-all">
          <LucideChevronLeft size={20} />
        </button>
        <div className="flex items-center gap-2">
          <div className="h-8 w-8 rounded-lg bg-gradient-to-br from-[#B36BFF] to-[#FF4D6D] flex items-center justify-center shadow-lg shadow-[#B36BFF]/20">
            <LucideSparkles size={16} className="text-white" />
          </div>
          <h1 className="text-[18px] font-black tracking-tight">AI Vocabs+</h1>
        </div>
        <button onClick={() => setShowSettings(!showSettings)} className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 active:scale-95 transition-all">
          <LucideSettings size={20} />
        </button>
      </header>

      {/* Tab Switcher */}
      <div className="px-4 py-2 bg-black/20 border-b border-white/5 flex gap-2">
        <button
          onClick={() => setActiveTab("suggest")}
          className={`flex-1 py-3 rounded-xl text-[13px] font-black transition-all ${
            activeTab === "suggest" ? "bg-white/10 text-white shadow-sm" : "text-white/30 hover:text-white/40"
          }`}
        >
          AI Vocabs+
        </button>
        <button
          onClick={() => setActiveTab("clean")}
          className={`flex-1 py-3 rounded-xl text-[13px] font-black transition-all ${
            activeTab === "clean" ? "bg-white/10 text-white shadow-sm" : "text-white/30 hover:text-white/40"
          }`}
        >
          AI Clean
        </button>
      </div>

      <main className="p-4 space-y-6 max-w-md mx-auto pb-40">
        {activeTab === "suggest" ? (
          <>
            {/* User Context Card */}
            <section className="bg-white/5 border border-white/10 rounded-3xl p-5 space-y-4">
              <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-2xl bg-white/5 flex items-center justify-center text-[#49D2FF]">
                  <LucideUser size={20} />
                </div>
                <div>
                  <h2 className="text-[15px] font-bold">Personal Context</h2>
                  <p className="text-[12px] text-white/40">Tailor your suggestions</p>
                </div>
              </div>
              
              <div className="grid grid-cols-2 gap-3">
                <div className="bg-black/20 rounded-2xl p-3 border border-white/5">
                  <span className="text-[10px] font-black uppercase tracking-widest text-white/20 block mb-1">Profession</span>
                  <span className="text-[14px] font-medium text-white/80 truncate block">{userContext?.profession || "Not set"}</span>
                </div>
                <div className="bg-black/20 rounded-2xl p-3 border border-white/5">
                  <span className="text-[10px] font-black uppercase tracking-widest text-white/20 block mb-1">Interests</span>
                  <span className="text-[14px] font-medium text-white/80 truncate block">{userContext?.interests || "Not set"}</span>
                </div>
              </div>

              <button 
                onClick={() => setShowSettings(true)}
                className="w-full py-3 rounded-2xl bg-[#B36BFF]/10 text-[#B36BFF] text-[13px] font-bold hover:bg-[#B36BFF]/20 transition-all"
              >
                Update Context
              </button>
            </section>

            {/* Action Button */}
            <button
              disabled={isGenerating}
              onClick={generateSuggestions}
              className="w-full py-5 rounded-3xl bg-gradient-to-r from-[#B36BFF] via-[#FF4D6D] to-[#FF8A50] text-white font-black text-[16px] shadow-xl shadow-[#B36BFF]/10 active:scale-[0.98] transition-all flex items-center justify-center gap-3 relative overflow-hidden group"
            >
              <div className="absolute inset-0 bg-white/20 translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-1000 ease-in-out" />
              {isGenerating ? (
                <>
                  <LucideRefreshCcw size={20} className="animate-spin" />
                  <span>Analyzing your list...</span>
                </>
              ) : (
                <>
                  <LucideBrain size={20} />
                  <span>Generate New Vocabs</span>
                </>
              )}
            </button>

            {/* Suggestions List */}
            <div className="space-y-4">
              <div className="flex items-center justify-between px-2">
                <h3 className="text-[14px] font-black uppercase tracking-widest text-white/30">AI Suggestions</h3>
                <span className="px-2 py-1 rounded-md bg-white/5 text-[10px] font-bold text-white/40">{suggestions.length} items</span>
              </div>

              <AnimatePresence mode="popLayout">
                {suggestions.map((sug, idx) => (
                  <motion.div
                    key={sug.thai}
                    layout
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0, scale: 0.95 }}
                    transition={{ delay: idx * 0.1 }}
                    className="bg-white/5 border border-white/5 rounded-3xl p-4 flex items-center justify-between group hover:bg-white/[0.08] transition-all"
                  >
                    <div className="flex-1 space-y-1">
                      <div className="flex items-center gap-2">
                        <span className="text-[18px] font-bold text-white">{sug.thai}</span>
                        <span className="px-2 py-0.5 rounded-full bg-[#B36BFF]/20 text-[#B36BFF] text-[10px] font-black uppercase">{sug.category}</span>
                      </div>
                      <div className="text-[14px] text-white/40 font-medium">{sug.burmese}</div>
                      {sug.reason && (
                        <div className="flex items-center gap-1.5 text-[11px] text-[#49D2FF]/60 bg-[#49D2FF]/5 px-2 py-1 rounded-lg w-fit">
                          <LucideInfo size={12} />
                          {sug.reason}
                        </div>
                      )}
                    </div>
                    <button
                      onClick={() => handleAddSuggested(sug)}
                      className="h-12 w-12 rounded-2xl bg-white/5 flex items-center justify-center text-white/40 hover:bg-[#2CE08B]/20 hover:text-[#2CE08B] transition-all active:scale-90 shadow-sm"
                    >
                      <LucidePlus size={24} />
                    </button>
                  </motion.div>
                ))}
              </AnimatePresence>

              {suggestions.length === 0 && !isGenerating && (
                <div className="py-20 text-center space-y-4">
                  <div className="h-20 w-20 rounded-full bg-white/5 flex items-center justify-center mx-auto text-white/10">
                    <LucideBrain size={40} />
                  </div>
                  <p className="text-white/20 font-bold max-w-[200px] mx-auto text-[14px]">
                    Tap generate to get personalized vocabulary suggestions
                  </p>
                </div>
              )}
            </div>
          </>
        ) : (
          <>
            {/* Action Button for Clean */}
            <button
              disabled={isGenerating}
              onClick={generateCleanSuggestions}
              className="w-full py-5 rounded-3xl bg-gradient-to-r from-[#49D2FF] to-[#B36BFF] text-white font-black text-[16px] shadow-xl shadow-[#49D2FF]/10 active:scale-[0.98] transition-all flex items-center justify-center gap-3 relative overflow-hidden group"
            >
              <div className="absolute inset-0 bg-white/20 translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-1000 ease-in-out" />
              {isGenerating ? (
                <>
                  <LucideRefreshCcw size={20} className="animate-spin" />
                  <span>Scanning for duplicates...</span>
                </>
              ) : (
                <>
                  <LucideBrain size={20} />
                  <span>Detect Duplicates</span>
                </>
              )}
            </button>

            {/* Duplicates List */}
            <div className="space-y-4">
              <div className="flex items-center justify-between px-2">
                <h3 className="text-[14px] font-black uppercase tracking-widest text-white/30">Semantic Duplicates</h3>
                <span className="px-2 py-1 rounded-md bg-white/5 text-[10px] font-bold text-white/40">{duplicates.length} groups</span>
              </div>

              <AnimatePresence mode="popLayout">
                {duplicates.map((group, idx) => (
                  <motion.div
                    key={group.thai}
                    layout
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, scale: 0.95 }}
                    className="bg-white/5 border border-white/5 rounded-3xl p-5 space-y-4"
                  >
                    <div className="space-y-1">
                      <h4 className="text-[18px] font-bold text-white">{group.thai}</h4>
                      <p className="text-[13px] text-[#FF4D6D]/80 bg-[#FF4D6D]/5 px-2 py-1 rounded-lg w-fit">{group.reason}</p>
                    </div>

                    <div className="space-y-2">
                      {group.ids.map(id => {
                        const entry = items.find(it => it.id === id);
                        if (!entry) return null;
                        return (
                          <div key={id} className="flex items-center justify-between bg-black/20 rounded-2xl p-3 border border-white/5">
                            <div className="min-w-0 flex-1">
                              <p className="text-[14px] font-medium truncate">{entry.thai}</p>
                              <p className="text-[12px] text-white/40 truncate">{entry.burmese}</p>
                            </div>
                            <button
                              onClick={() => handleDeleteEntry(id)}
                              className="ml-3 h-10 w-10 rounded-xl bg-[#FF4D6D]/10 text-[#FF4D6D] flex items-center justify-center active:scale-90 transition-all hover:bg-[#FF4D6D]/20"
                            >
                              ✕
                            </button>
                          </div>
                        );
                      })}
                    </div>
                  </motion.div>
                ))}
              </AnimatePresence>

              {duplicates.length === 0 && !isGenerating && (
                <div className="py-20 text-center space-y-4">
                  <div className="h-20 w-20 rounded-full bg-white/5 flex items-center justify-center mx-auto text-white/10">
                    <LucideBrain size={40} />
                  </div>
                  <p className="text-white/20 font-bold max-w-[200px] mx-auto text-[14px]">
                    No duplicates detected yet. Tap detect to scan your library.
                  </p>
                </div>
              )}
            </div>
          </>
        )}
      </main>

      {/* Settings Modal */}
      <AnimatePresence>
        {showSettings && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[100] bg-black/80 backdrop-blur-md flex items-end sm:items-center justify-center p-4"
          >
            <motion.div
              initial={{ y: "100%" }}
              animate={{ y: 0 }}
              exit={{ y: "100%" }}
              className="w-full max-w-md bg-[#16171D] border border-white/10 rounded-t-[40px] sm:rounded-[40px] p-8 space-y-6 shadow-2xl"
            >
              <div className="flex items-center justify-between">
                <h2 className="text-2xl font-black">Personal Context</h2>
                <button onClick={() => setShowSettings(false)} className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 text-white/40 hover:text-white transition-all">
                  ✕
                </button>
              </div>

              <div className="space-y-4">
                <div className="space-y-2">
                  <label className="text-[11px] font-black uppercase tracking-widest text-white/30 ml-2">Your Profession</label>
                  <input
                    type="text"
                    value={profession}
                    onChange={(e) => setProfession(e.target.value)}
                    placeholder="e.g. Tour Guide, Software Engineer..."
                    className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-[16px] focus:border-[#B36BFF]/50 outline-none transition-all placeholder:text-white/10"
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-[11px] font-black uppercase tracking-widest text-white/30 ml-2">Interests / Hobbies</label>
                  <textarea
                    rows={3}
                    value={interests}
                    onChange={(e) => setInterests(e.target.value)}
                    placeholder="e.g. History, Cooking, Reading books..."
                    className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-[16px] focus:border-[#B36BFF]/50 outline-none transition-all resize-none placeholder:text-white/10"
                  />
                </div>
              </div>

              <button
                disabled={contextLoading}
                onClick={handleSaveContext}
                className="w-full py-5 rounded-2xl bg-white text-black font-black text-[16px] active:scale-[0.98] transition-all flex items-center justify-center gap-2"
              >
                {contextLoading ? <LucideRefreshCcw className="animate-spin" size={20} /> : "Save Profile"}
              </button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export default function AiPlusPage() {
  return (
    <ErrorBoundary>
      <AiPlusContent />
    </ErrorBoundary>
  );
}
