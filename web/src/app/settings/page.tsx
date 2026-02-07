"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { signOut } from "firebase/auth";
import { doc, setDoc } from "firebase/firestore";

import { firebaseApp } from "@/lib/firebase/client";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { getFirebaseAuth, getFirebaseDb, isFirebaseConfigured } from "@/lib/firebase/client";
import { DEFAULT_STARTING_DATE } from "@/lib/constants";

function formatDateDisplay(isoString: string) {
  if (!isoString) return "";
  const [y, m, d] = isoString.split("-");
  if (!y || !m || !d) return isoString;
  return `${d}/${m}/${y}`;
}

export default function SettingsPage() {
  const { 
    uid, 
    isAnonymous, 
    email, 
    displayName, 
    photoURL, 
    loading, 
    aiApiKey, 
    aiKeyLoading, 
    updateAiApiKey,
    userDailyGoal: cloudUserDailyGoal,
    startingDate: cloudStartingDate,
    xDate,
    setXDate,
    updateStudyGoals,
    rule,
    setRule,
  } = useVocabulary();
  const [accountOpen, setAccountOpen] = useState(false);
  const accountRef = useRef<HTMLDivElement | null>(null);
  const [now, setNow] = useState(() => new Date());
  const [googleAiApiKey, setGoogleAiApiKey] = useState("");
  const [googleAiApiKeyVisible, setGoogleAiApiKeyVisible] = useState(false);
  
  const [localUserDailyGoal, setLocalUserDailyGoal] = useState<number | null>(null);
  const [localStartingDate, setLocalStartingDate] = useState(DEFAULT_STARTING_DATE);
  const [localRule, setLocalRule] = useState<string>("");
  const [localXDate, setLocalXDate] = useState(DEFAULT_STARTING_DATE);
  const [isManualSaving, setIsManualSaving] = useState(false);
  const [showSavedIndicator, setShowSavedIndicator] = useState(false);

  useEffect(() => {
    if (rule !== undefined) {
      setLocalRule(rule.toLocaleString());
    }
  }, [rule]);

  useEffect(() => {
    if (aiApiKey) {
      setGoogleAiApiKey(aiApiKey);
    }
  }, [aiApiKey]);

  useEffect(() => {
    if (cloudUserDailyGoal !== undefined && cloudUserDailyGoal !== null) {
      setLocalUserDailyGoal(cloudUserDailyGoal);
    }
    if (cloudStartingDate) {
      setLocalStartingDate(cloudStartingDate);
    }
  }, [cloudUserDailyGoal, cloudStartingDate]);

  useEffect(() => {
    if (xDate) {
      setLocalXDate(xDate);
    }
  }, [xDate]);

  const handleSaveAiKey = async () => {
    if (!googleAiApiKey.trim()) return;
    await updateAiApiKey(googleAiApiKey.trim());
  };

  const handleManualSaveGoals = async () => {
    if (!uid || isAnonymous) return;
    setIsManualSaving(true);
    try {
      const finalGoal = localUserDailyGoal || 500;
      await updateStudyGoals(
        finalGoal, 
        localStartingDate
      );
      // Confirm the saved value is what we keep
      setLocalUserDailyGoal(finalGoal);
      setShowSavedIndicator(true);
      setTimeout(() => setShowSavedIndicator(false), 2000);
    } catch (e) {
      console.error("Save failed:", e);
    } finally {
      setIsManualSaving(false);
    }
  };

  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(id);
  }, []);

  useEffect(() => {
    if (!accountOpen) return;

    const onDown = (e: MouseEvent | TouchEvent) => {
      const target = e.target as Node | null;
      if (!target) return;
      if (accountRef.current?.contains(target)) return;
      setAccountOpen(false);
    };

    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setAccountOpen(false);
    };

    window.addEventListener("mousedown", onDown);
    window.addEventListener("touchstart", onDown, { passive: true });
    window.addEventListener("keydown", onKey);
    return () => {
      window.removeEventListener("mousedown", onDown);
      window.removeEventListener("touchstart", onDown);
      window.removeEventListener("keydown", onKey);
    };
  }, [accountOpen]);

  const doSignOut = async () => {
    const auth = getFirebaseAuth();
    await signOut(auth);
  };

  const timeText = `${String(now.getHours()).padStart(2, "0")}:${String(
    now.getMinutes()
  ).padStart(2, "0")}:${String(now.getSeconds()).padStart(2, "0")}`;

  const runtimeFirebase = useMemo(() => {
    if (!firebaseApp) return null;
    return {
      projectId: firebaseApp.options.projectId ?? null,
      authDomain: firebaseApp.options.authDomain ?? null,
    };
  }, []);

  const ghostBtn =
    "rounded-full bg-[var(--surface)]/80 px-4 py-2 text-[13px] font-semibold text-[color:var(--foreground)] backdrop-blur-xl border border-[color:var(--border)] shadow-sm hover:shadow-md transition-shadow";

  const isAuthed = !!uid && !isAnonymous;

  return (
    <div className="min-h-screen bg-[#0A0B0F] text-white">
      <div
        className="min-h-screen"
        style={{
          background:
            "radial-gradient(1200px 800px at 50% 10%, rgba(255,255,255,0.08), rgba(0,0,0,0) 55%), radial-gradient(900px 600px at 50% 60%, rgba(255,83,145,0.09), rgba(0,0,0,0) 60%), #0A0B0F",
        }}
      >
        <div className="mx-auto w-full max-w-md px-4 pt-[calc(env(safe-area-inset-top)+20px)] pb-[calc(env(safe-area-inset-bottom)+118px)]">
        <header className="flex items-center justify-between mb-8">
          <Link href="/" className={ghostBtn}>
            Home
          </Link>
          <div className="text-[17px] font-bold tracking-tight">
            Settings
          </div>
          <div className="w-[60px]" />
        </header>

        {/* Profile Card Section */}
        <section className="mb-8">
          <div className="flex items-center justify-between px-1 mb-3">
            <h2 className="text-[14px] font-bold uppercase tracking-wider text-[#60A5FA]">Account</h2>
            {isAuthed && (
              <div className="flex items-center gap-1.5">
                <motion.div
                  animate={{ opacity: [0.4, 1, 0.4] }}
                  transition={{ duration: 2, repeat: Infinity }}
                  className="h-2 w-2 rounded-full bg-[#2CE08B] shadow-[0_0_8px_#2CE08B]"
                />
                <span className="text-[11px] font-bold text-[#2CE08B] tracking-wide uppercase">LIVE</span>
              </div>
            )}
          </div>

          <div className="rounded-[24px] bg-[var(--card)] p-5 shadow-[0_12px_40px_rgba(0,0,0,0.12)] border border-[color:var(--border)] backdrop-blur-3xl">
            {isAuthed ? (
              <>
                <div className="flex items-center gap-5">
                  <div className="relative">
                    <div className="h-20 w-20 rounded-full overflow-hidden border-2 border-white/20 bg-[var(--surface)] shadow-[0_0_20px_rgba(255,255,255,0.15)]">
                      {photoURL ? (
                        <img
                          src={photoURL}
                          alt=""
                          referrerPolicy="no-referrer"
                          className="h-full w-full object-cover"
                        />
                      ) : (
                        <div className="h-full w-full flex items-center justify-center text-[24px] font-bold">
                          {(displayName ?? email ?? "U").slice(0, 1).toUpperCase()}
                        </div>
                      )}
                    </div>
                    <motion.div 
                      className="absolute -bottom-1 -right-1 h-6 w-6 rounded-full bg-[#2CE08B] border-2 border-[var(--card)] shadow-sm flex items-center justify-center"
                      initial={{ scale: 0 }}
                      animate={{ scale: 1 }}
                      transition={{ type: "spring", stiffness: 400, damping: 10 }}
                    >
                      <div className="h-2 w-2 rounded-full bg-white animate-pulse" />
                    </motion.div>
                  </div>
                  
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-0.5">
                      <h3 className="text-[18px] font-bold tracking-tight truncate">
                        {displayName ?? "Peter Soe Moe"}
                      </h3>
                      <div className="px-2 py-0.5 rounded-full bg-gradient-to-r from-[#60A5FA] via-[#B36BFF] to-[#FF4D6D] text-[9px] font-black text-white uppercase tracking-wider shadow-sm">
                        PRO
                      </div>
                    </div>
                    <p className="text-[13px] font-medium text-[color:var(--muted)] truncate">
                      {email ?? "peter@example.com"}
                    </p>
                    <button
                      onClick={() => void doSignOut()}
                      className="mt-3 text-[12px] font-bold text-[#FF4D6D] hover:opacity-80 transition-opacity"
                    >
                      Sign Out
                    </button>
                  </div>
                </div>
              </>
            ) : (
              <div className="text-center py-2">
                <p className="text-[14px] font-bold text-[color:var(--muted-strong)]">Sign in required</p>
                <p className="text-[12px] font-medium text-[color:var(--muted)] mt-1">Unlock pro features to sync data</p>
              </div>
            )}
          </div>
        </section>

        {/* Study Goals Section */}
        {isAuthed && (
          <section className="mb-8">
            <div className="flex items-center justify-between px-1 mb-3">
              <h2 className="text-[14px] font-bold uppercase tracking-wider text-[#2CE08B]">Study Goals</h2>
              <div className="flex items-center gap-2">
                <AnimatePresence>
                  {showSavedIndicator && (
                    <motion.div
                      initial={{ opacity: 0, x: 5 }}
                      animate={{ opacity: 1, x: 0 }}
                      exit={{ opacity: 0 }}
                      className="text-[10px] font-black text-[#2CE08B] uppercase tracking-widest"
                    >
                      ✓ Saved
                    </motion.div>
                  )}
                </AnimatePresence>
                <button
                  type="button"
                  onClick={handleManualSaveGoals}
                  disabled={isManualSaving}
                  className="px-3 py-1.5 rounded-xl bg-[#2CE08B]/10 text-[10px] font-black text-[#2CE08B] uppercase tracking-wider hover:bg-[#2CE08B]/20 transition-all active:scale-95 border border-[#2CE08B]/20 disabled:opacity-40"
                >
                  {isManualSaving ? "Saving..." : "Save Goals"}
                </button>
                {isManualSaving && (
                  <motion.div
                    animate={{ rotate: 360 }}
                    transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
                    className="h-4 w-4 border-2 border-[#2CE08B] border-t-transparent rounded-full"
                  />
                )}
              </div>
            </div>
            <div className="rounded-[24px] bg-[var(--card)] p-5 shadow-[0_12px_40px_rgba(0,0,0,0.12)] border border-[color:var(--border)] backdrop-blur-3xl space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h4 className="text-[13px] font-bold text-white/90">Daily Study Goal</h4>
                  <p className="text-[11px] font-medium text-[color:var(--muted)]">Items per day</p>
                </div>
                <div className="flex items-center gap-3 bg-black/20 rounded-xl p-1 border border-white/5">
                  <button 
                    onClick={() => setLocalUserDailyGoal(prev => Math.max(100, (prev || 500) - 100))}
                    className="h-8 w-8 flex items-center justify-center rounded-lg hover:bg-white/5 text-white/60 transition-colors"
                  >
                    −
                  </button>
                  <input
                    type="number"
                    step="100"
                    value={localUserDailyGoal || ""}
                    autoComplete="off"
                    data-lpignore="true"
                    onChange={(e) => {
                      const val = parseInt(e.target.value, 10);
                      setLocalUserDailyGoal(isNaN(val) ? null : val);
                    }}
                    placeholder="500"
                    className="text-[14px] font-bold w-16 text-center tabular-nums bg-transparent border-none focus:outline-none focus:ring-0 p-0"
                  />
                  <button 
                    onClick={() => setLocalUserDailyGoal(prev => (prev || 500) + 100)}
                    className="h-8 w-8 flex items-center justify-center rounded-lg hover:bg-white/5 text-white/60 transition-colors"
                  >
                    +
                  </button>
                </div>
              </div>

              <div className="flex items-center justify-between">
                <div>
                  <h4 className="text-[13px] font-bold text-white/90">Starting Date (dd/mm/yyyy)</h4>
                  <p className="text-[11px] font-medium text-[color:var(--muted)]">When your journey began</p>
                </div>
                <div className="relative group">
                  <div className="bg-black/20 rounded-xl px-3 py-2 border border-white/5 text-[14px] font-bold text-white flex items-center gap-2 cursor-pointer hover:bg-white/5 transition-colors">
                    <span>{formatDateDisplay(localStartingDate)}</span>
                    <span className="text-white/20">🗓️</span>
                    <input
                      type="date"
                      value={localStartingDate}
                      onChange={(e) => setLocalStartingDate(e.target.value)}
                      className="absolute inset-0 opacity-0 cursor-pointer"
                    />
                  </div>
                </div>
              </div>
            </div>
          </section>
        )}

        {/* Rule Section */}
        {uid && !isAnonymous && (
          <section className="mb-8">
            <h2 className="text-[14px] font-bold uppercase tracking-wider text-[#B36BFF] px-1 mb-3">Policy</h2>
            <div className="rounded-[24px] bg-[var(--card)] p-5 shadow-[0_12px_40px_rgba(0,0,0,0.12)] border border-[color:var(--border)] backdrop-blur-3xl">
              <div className="flex items-center justify-between">
                <div>
                  <h4 className="text-[13px] font-bold text-white/90">Rule</h4>
                  <p className="text-[11px] font-medium text-[color:var(--muted)]">Active policy value</p>
                </div>
                <div className="flex items-center gap-3 bg-black/20 rounded-xl p-1 border border-white/5">
                  <button 
                    onClick={() => {
                      const num = Math.max(0, (rule || 0) - 100);
                      setLocalRule(num.toLocaleString());
                      setRule(num);
                      localStorage.setItem("policy_rule", num.toString());
                      if (uid && !isAnonymous) {
                        const db = getFirebaseDb();
                        const goalRef = doc(db, "users", uid, "settings", "goals");
                        setDoc(goalRef, { rule: num }, { merge: true });
                      }
                    }}
                    className="h-8 w-8 flex items-center justify-center rounded-lg hover:bg-white/5 text-white/60 transition-colors"
                  >
                    −
                  </button>
                  <input
                    type="text"
                    value={localRule}
                    autoComplete="off"
                    data-lpignore="true"
                    onChange={(e) => {
                      const raw = e.target.value.replace(/,/g, "");
                      if (raw === "" || /^\d+$/.test(raw)) {
                        const num = raw === "" ? 0 : parseInt(raw, 10);
                        setLocalRule(num.toLocaleString());
                        setRule(num);
                        // Persist to localStorage immediately
                        localStorage.setItem("policy_rule", num.toString());
                        
                        // Atomic sync to Firestore
                        if (uid && !isAnonymous) {
                          const db = getFirebaseDb();
                          const goalRef = doc(db, "users", uid, "settings", "goals");
                          setDoc(goalRef, { rule: num }, { merge: true });
                        }
                      }
                    }}
                    placeholder="000,000"
                    className="text-[14px] font-bold text-[#B36BFF] text-right w-24 bg-transparent border-none focus:outline-none focus:ring-0 p-0"
                  />
                  <button 
                    onClick={() => {
                      const num = (rule || 0) + 100;
                      setLocalRule(num.toLocaleString());
                      setRule(num);
                      localStorage.setItem("policy_rule", num.toString());
                      if (uid && !isAnonymous) {
                        const db = getFirebaseDb();
                        const goalRef = doc(db, "users", uid, "settings", "goals");
                        setDoc(goalRef, { rule: num }, { merge: true });
                      }
                    }}
                    className="h-8 w-8 flex items-center justify-center rounded-lg hover:bg-white/5 text-white/60 transition-colors"
                  >
                    +
                  </button>
                </div>
              </div>

              <div className="flex items-center justify-between border-t border-white/5 pt-4">
                <div>
                  <h4 className="text-[13px] font-bold text-white/90">X Date (DD/MM/YYYY)</h4>
                  <p className="text-[11px] font-medium text-[color:var(--muted)]">Target deadline</p>
                </div>
                <div className="relative group">
                  <div className="bg-black/20 rounded-xl px-3 py-2 border border-white/5 text-[14px] font-bold text-[#B36BFF] flex items-center gap-2 cursor-pointer hover:bg-white/5 transition-colors">
                    <span>{formatDateDisplay(localXDate)}</span>
                    <span className="text-[#B36BFF]/20">🗓️</span>
                    <input
                      type="date"
                      value={localXDate}
                      onChange={(e) => {
                        const val = e.target.value;
                        setLocalXDate(val);
                        setXDate(val);
                        // Persist to localStorage immediately
                        localStorage.setItem("policy_x_date", val);
                        
                        // Atomic sync to Firestore
                        if (uid && !isAnonymous) {
                          const db = getFirebaseDb();
                          const goalRef = doc(db, "users", uid, "settings", "goals");
                          setDoc(goalRef, { xDate: val }, { merge: true });
                        }
                      }}
                      className="absolute inset-0 opacity-0 cursor-pointer"
                    />
                  </div>
                </div>
              </div>
            </div>
          </section>
        )}

        {/* Tools Section */}
        <section className="mb-8">
          <h2 className="text-[14px] font-bold uppercase tracking-wider text-[#B36BFF] px-1 mb-3">Tools</h2>
          <div className="space-y-3">
            <Link
              href="/settings/import"
              className="flex items-center justify-between rounded-2xl bg-[var(--surface)]/70 px-5 py-4 text-[15px] font-bold text-[color:var(--foreground)] border border-[color:var(--border)] backdrop-blur-xl shadow-sm hover:shadow-md transition-all group active:scale-[0.98]"
            >
              <div className="flex items-center gap-3">
                <div className="h-8 w-8 rounded-xl bg-[#B36BFF]/10 flex items-center justify-center text-[16px]">📥</div>
                <span>Import CSV</span>
              </div>
              <span className="text-[20px] text-[color:var(--muted)] group-hover:translate-x-0.5 transition-transform">›</span>
            </Link>
          </div>
        </section>

        {/* AI Configuration Section */}
        <section className="mb-8">
          <h2 className="text-[14px] font-bold uppercase tracking-wider text-[#FF4D6D] px-1 mb-3">AI Intelligence</h2>
          <div className="rounded-[24px] bg-[var(--card)] p-5 shadow-[0_12px_40px_rgba(0,0,0,0.12)] border border-[color:var(--border)] backdrop-blur-3xl">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-2xl bg-[#FF4D6D]/10 flex items-center justify-center text-[20px]">✨</div>
                <div>
                  <h3 className="text-[15px] font-bold tracking-tight">Google AI Studio</h3>
                  <p className="text-[11px] font-bold text-[#2CE08B] uppercase tracking-wide">
                    {aiApiKey ? "Saved to Cloud" : "On-Device Storage"}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setGoogleAiApiKeyVisible((v) => !v)}
                  className="px-3 py-1.5 rounded-xl bg-white/5 text-[10px] font-black text-white/60 uppercase tracking-wider hover:bg-white/10 transition-all active:scale-95 border border-white/5"
                >
                  {googleAiApiKeyVisible ? "Hide Key" : "Show Key"}
                </button>
                {aiKeyLoading && (
                  <motion.div
                    animate={{ rotate: 360 }}
                    transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
                    className="h-4 w-4 border-2 border-[#FF4D6D] border-t-transparent rounded-full"
                  />
                )}
              </div>
            </div>

            <div className="relative group">
              <input
                value={googleAiApiKey}
                onChange={(e) => setGoogleAiApiKey(e.target.value)}
                type={googleAiApiKeyVisible ? "text" : "password"}
                placeholder="Paste API Key here..."
                className="w-full rounded-2xl bg-black/20 pl-4 pr-[80px] py-4 text-[14px] font-bold text-[color:var(--foreground)] placeholder:text-[color:var(--muted)] border border-white/5 backdrop-blur-xl shadow-inner focus:outline-none focus:border-[#FF4D6D]/50 transition-all"
                autoCapitalize="none"
                autoCorrect="off"
                spellCheck={false}
              />
              <div className="absolute inset-0 rounded-2xl pointer-events-none border border-transparent group-focus-within:border-[#FF4D6D]/30 group-focus-within:animate-pulse transition-all" />
              
              <div className="absolute right-2 top-1/2 -translate-y-1/2">
                <button
                  type="button"
                  onClick={handleSaveAiKey}
                  disabled={aiKeyLoading || !googleAiApiKey.trim() || googleAiApiKey === aiApiKey}
                  className="px-4 py-2 rounded-xl bg-gradient-to-r from-[#FF4D6D] to-[#FFB020] text-[11px] font-black text-white uppercase tracking-wider shadow-lg active:scale-95 transition-all disabled:opacity-40"
                >
                  Save
                </button>
              </div>
            </div>
            <p className="mt-3 text-[11px] font-medium text-[color:var(--muted)] px-1 leading-relaxed">
              Your key is used to generate smart explanations for vocabularies.
            </p>
          </div>
        </section>

        {/* System Info Section */}
        {isAuthed && runtimeFirebase && (
          <section className="mb-8">
            <h2 className="text-[14px] font-bold uppercase tracking-wider text-[#FFB020] px-1 mb-3">System</h2>
            <div className="rounded-[24px] bg-[var(--surface)]/40 p-5 border border-[color:var(--border)] backdrop-blur-xl">
              <div className="space-y-3 text-[12px] font-bold">
                <div className="flex justify-between items-center pb-2 border-b border-white/5">
                  <span className="text-[color:var(--muted)]">Project ID</span>
                  <span className="text-[color:var(--foreground)]">{runtimeFirebase.projectId}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-[color:var(--muted)]">UID</span>
                  <span className="text-[color:var(--foreground)] tabular-nums">{uid.slice(0, 8)}...</span>
                </div>
              </div>
            </div>
          </section>
        )}

        {/* Footer Info */}
        <div className="text-center opacity-40">
          <p className="text-[10px] font-black tracking-widest uppercase">Sar Kyat Pro v2.0</p>
          <div className="mt-2 flex justify-center gap-1.5 tabular-nums text-[10px] font-bold">
            <span>{timeText}</span>
          </div>
        </div>
      </div>
      </div>
    </div>
  );
}
