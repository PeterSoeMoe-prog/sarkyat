"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
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
    xDate,
    setXDate,
    rule,
    setRule,
    items,
  } = useVocabulary();
  const router = useRouter();
  const [accountOpen, setAccountOpen] = useState(false);
  const accountRef = useRef<HTMLDivElement | null>(null);
  const [now, setNow] = useState(() => new Date());
  const [googleAiApiKey, setGoogleAiApiKey] = useState("");
  const [googleAiApiKeyVisible, setGoogleAiApiKeyVisible] = useState(() => {
    if (typeof window !== "undefined") {
      return localStorage.getItem("ai_key_visible") === "true";
    }
    return false;
  });
  const [isEditingAiKey, setIsEditingAiKey] = useState(false);
  
  const [localRule, setLocalRule] = useState<string>("");
  const [localXDate, setLocalXDate] = useState(DEFAULT_STARTING_DATE);

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
    if (xDate) {
      setLocalXDate(xDate);
    }
  }, [xDate]);

  const toggleAiKeyVisibility = () => {
    const newVal = !googleAiApiKeyVisible;
    setGoogleAiApiKeyVisible(newVal);
    localStorage.setItem("ai_key_visible", String(newVal));
  };

  const handleSaveAiKey = async () => {
    if (!googleAiApiKey.trim()) return;
    await updateAiApiKey(googleAiApiKey.trim());
    setIsEditingAiKey(false);
    setGoogleAiApiKeyVisible(false);
  };

  const handleExportCsv = () => {
    if (!items || items.length === 0) return;
    
    // Create CSV header
    const headers = ["Thai", "Burmese", "Category", "Count", "Status", "AI Explanation"];
    
    // Convert items to CSV rows
    const rows = items.map(item => [
      `"${(item.thai || "").toString().replace(/"/g, '""')}"`,
      `"${(item.burmese || "").toString().replace(/"/g, '""')}"`,
      `"${(item.category || "").toString().replace(/"/g, '""')}"`,
      item.count || 0,
      `"${(item.status || "").toString().replace(/"/g, '""')}"`,
      `"${(item.ai_explanation || "").toString().replace(/"/g, '""')}"`
    ]);
    
    const csvContent = [headers.join(","), ...rows.map(r => r.join(","))].join("\n");
    
    // Create download link
    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `sar-kyat-vocab-export-${new Date().toISOString().split('T')[0]}.csv`);
    link.style.visibility = "hidden";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
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
    <div className="min-h-screen bg-[#0A0B0F] text-white overflow-x-hidden">
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

          <div className="rounded-[24px] bg-white/5 p-1.5 shadow-[0_12px_40px_rgba(0,0,0,0.12)] border border-white/10 backdrop-blur-3xl">
            {isAuthed ? (
              <div className="flex items-center justify-between p-3.5">
                <div className="flex items-center gap-4">
                  <div className="relative">
                    <div className="h-14 w-14 rounded-full overflow-hidden border-2 border-white/10 bg-white/5 shadow-inner">
                      {photoURL ? (
                        <img
                          src={photoURL}
                          alt=""
                          referrerPolicy="no-referrer"
                          className="h-full w-full object-cover"
                        />
                      ) : (
                        <div className="flex h-full w-full items-center justify-center bg-white/5 text-[24px]">👤</div>
                      )}
                    </div>
                    {isAuthed && (
                      <div className="absolute -bottom-0.5 -right-0.5 h-4 w-4 rounded-full border-2 border-[#0A0B0F] bg-[#2CE08B] shadow-[0_0_8px_#2CE08B]" />
                    )}
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <h3 className="text-[16px] font-bold tracking-tight text-white">{displayName || "Pro Learner"}</h3>
                      <span className="px-1.5 py-0.5 rounded-md bg-gradient-to-r from-[#FF4D6D] to-[#B36BFF] text-[8px] font-black text-white uppercase tracking-wider">PRO</span>
                    </div>
                    <p className="text-[11px] font-medium text-white/30 truncate max-w-[140px]">{email}</p>
                  </div>
                </div>
                <button
                  type="button"
                  onClick={async () => {
                    const auth = getFirebaseAuth();
                    await auth.signOut();
                    router.push("/");
                  }}
                  className="px-3 py-2 rounded-xl bg-white/5 text-[10px] font-black text-white/40 uppercase tracking-widest hover:bg-white/10 hover:text-white/60 transition-all active:scale-95 border border-white/5"
                >
                  Sign Out
                </button>
              </div>
            ) : (
              <div className="text-center py-2">
                <p className="text-[14px] font-bold text-[color:var(--muted-strong)]">Sign in required</p>
                <p className="text-[12px] font-medium text-[color:var(--muted)] mt-1">Unlock pro features to sync data</p>
              </div>
            )}
          </div>
        </section>


        {/* Rule Section */}
        {uid && !isAnonymous && (
          <section className="mb-8">
            <h2 className="text-[14px] font-bold uppercase tracking-wider text-[#B36BFF] px-1 mb-3">Policy</h2>
            <div className="rounded-[24px] bg-white/5 p-5 shadow-[0_12px_40px_rgba(0,0,0,0.12)] border border-white/10 backdrop-blur-3xl">
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
                  <h4 className="text-[13px] font-bold text-white/90">Started Date (DD/MM/YYYY)</h4>
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
          <div className="rounded-[24px] bg-white/5 p-2 shadow-[0_12px_40px_rgba(0,0,0,0.12)] border border-white/10 backdrop-blur-3xl">
            <div className="flex flex-col">
              <Link
                href="/import"
                className="flex items-center justify-between p-3.5 rounded-2xl hover:bg-white/5 transition-all group"
              >
                <div className="flex items-center gap-4">
                  <div className="h-10 w-10 rounded-xl bg-white/5 flex items-center justify-center text-[20px] shadow-inner">📥</div>
                  <div>
                    <h4 className="text-[14px] font-bold text-white/90">Import CSV</h4>
                    <p className="text-[11px] font-medium text-white/30">Add external vocabulary</p>
                  </div>
                </div>
                <span className="text-[18px] text-white/20 group-hover:text-white/40 group-hover:translate-x-0.5 transition-all">›</span>
              </Link>

              {/* NEW ROW: Export CSV */}
              <div className="border-t border-white/5 mt-1 pt-1">
                <button
                  onClick={handleExportCsv}
                  className="w-full flex items-center justify-between p-3.5 rounded-2xl hover:bg-white/5 transition-all group text-left"
                >
                  <div className="flex items-center gap-4">
                    <div className="h-10 w-10 rounded-xl bg-white/5 flex items-center justify-center text-[20px] shadow-inner">📤</div>
                    <div>
                      <h4 className="text-[14px] font-bold text-white/90">Export CSV</h4>
                      <p className="text-[11px] font-medium text-white/30">Download your vocabulary</p>
                    </div>
                  </div>
                  <span className="text-[18px] text-white/20 group-hover:text-white/40 group-hover:translate-x-0.5 transition-all">›</span>
                </button>
              </div>
            </div>
          </div>
        </section>

        {/* AI Configuration Section */}
        <section className="mb-8">
          <h2 className="text-[14px] font-bold uppercase tracking-wider text-[#FF4D6D] px-1 mb-3">AI Intelligence</h2>
          
          {/* Block 2: AI Key Row */}
          <div className="rounded-[24px] bg-white/5 p-2 shadow-[0_12px_40px_rgba(0,0,0,0.12)] border border-white/10 backdrop-blur-3xl">
            <div className="flex flex-col gap-1">
              <div className="flex items-center justify-between p-3.5">
                <div className="flex items-center gap-4">
                  <div className="h-10 w-10 rounded-xl bg-white/5 flex items-center justify-center text-[20px] shadow-inner">🔑</div>
                  <div>
                    <h3 className="text-[14px] font-bold text-white/90">X Key</h3>
                    <p className="text-[11px] font-medium text-white/30 uppercase tracking-widest">
                      Gemini AI Studio
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  {aiApiKey && !isEditingAiKey && (
                    <button
                      type="button"
                      onClick={toggleAiKeyVisibility}
                      className="h-9 w-9 flex items-center justify-center rounded-xl bg-white/5 text-[16px] hover:bg-white/10 transition-all active:scale-95 border border-white/5"
                    >
                      {googleAiApiKeyVisible ? "👁️" : "🕶️"}
                    </button>
                  )}
                  <button
                    type="button"
                    onClick={() => {
                      if (isEditingAiKey) {
                        handleSaveAiKey();
                      } else {
                        setIsEditingAiKey(true);
                        setGoogleAiApiKeyVisible(true);
                      }
                    }}
                    className="px-4 py-2 rounded-xl bg-white/5 text-[10px] font-black text-white/40 uppercase tracking-widest hover:bg-white/10 hover:text-white/60 transition-all active:scale-95 border border-white/5"
                  >
                    {isEditingAiKey ? "Save" : aiApiKey ? "Update" : "Set Key"}
                  </button>
                </div>
              </div>

              <AnimatePresence>
                {(isEditingAiKey || (googleAiApiKeyVisible && aiApiKey)) && (
                  <motion.div
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: "auto", opacity: 1 }}
                    exit={{ height: 0, opacity: 0 }}
                    className="overflow-hidden"
                  >
                    <div className="px-3.5 pb-3.5 pt-0">
                      <div className="relative group">
                        <input
                          type={googleAiApiKeyVisible ? "text" : "password"}
                          value={googleAiApiKey}
                          onChange={(e) => setGoogleAiApiKey(e.target.value)}
                          placeholder="Enter Gemini API Key..."
                          disabled={!isEditingAiKey}
                          className="w-full bg-black/20 rounded-xl px-4 py-3 text-[13px] font-medium text-white/80 border border-white/5 focus:outline-none focus:ring-1 focus:ring-[#FF4D6D]/30 transition-all placeholder:text-white/10"
                        />
                        {isEditingAiKey && (
                          <button
                            onClick={() => {
                              setIsEditingAiKey(false);
                              setGoogleAiApiKey(aiApiKey || "");
                            }}
                            className="absolute right-3 top-1/2 -translate-y-1/2 text-[10px] font-bold text-white/20 hover:text-white/40 uppercase tracking-tight"
                          >
                            Cancel
                          </button>
                        )}
                      </div>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </div>
          <p className="mt-3 text-[11px] font-medium text-white/20 px-1 leading-relaxed">
            Your key is used to generate smart explanations for vocabularies.
          </p>
        </section>

        {/* System Info Section */}
        {isAuthed && runtimeFirebase && (
          <section className="mb-8">
            <h2 className="text-[14px] font-bold uppercase tracking-wider text-[#FFB020] px-1 mb-3">System</h2>
            <div className="rounded-[24px] bg-white/5 p-2 shadow-[0_12px_40px_rgba(0,0,0,0.12)] border border-white/10 backdrop-blur-3xl">
              <div className="space-y-1">
                <div className="flex items-center justify-between p-3 rounded-xl hover:bg-white/5 transition-all">
                  <div className="flex items-center gap-3">
                    <div className="h-8 w-8 rounded-lg bg-white/5 flex items-center justify-center text-[14px]">🆔</div>
                    <span className="text-[13px] font-bold text-white/60">Project ID</span>
                  </div>
                  <span className="text-[13px] font-bold text-white/90 tabular-nums">{runtimeFirebase.projectId}</span>
                </div>
                <div className="flex items-center justify-between p-3 rounded-xl hover:bg-white/5 transition-all">
                  <div className="flex items-center gap-3">
                    <div className="h-8 w-8 rounded-lg bg-white/5 flex items-center justify-center text-[14px]">👤</div>
                    <span className="text-[13px] font-bold text-white/60">UID</span>
                  </div>
                  <span className="text-[13px] font-bold text-white/90 tabular-nums">{uid.slice(0, 8)}...</span>
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
