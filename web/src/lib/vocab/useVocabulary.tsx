"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { 
  collection, 
  doc, 
  getDoc, 
  getDocs, 
  onSnapshot,
  orderBy, 
  query, 
  setDoc,
  updateDoc,
  where,
  serverTimestamp
} from "firebase/firestore";
import { onAuthStateChanged } from "firebase/auth";
import { getFirebaseAuth, getFirebaseDb, isFirebaseConfigured } from "@/lib/firebase/client";
import { 
  fetchAiApiKey, 
  fetchStudyGoals, 
  listenVocabulary, 
  saveAiApiKey, 
  saveStudyGoals, 
  fetchVocabLogic, 
  saveVocabLogic, 
  fetchFailedQuizIds, 
  saveFailedQuizIds, 
  vocabCollectionPath,
  fetchUserContext,
  saveUserContext,
  batchUpdateAiComposition,
  type UserStudyGoals, 
  type VocabLogic,
  type UserContext
} from "@/lib/vocab/firestore";
import { saveVocabToIndexedDB, getVocabFromIndexedDB } from "@/lib/vocab/indexeddb";
import type { VocabularyEntry } from "@/lib/vocab/types";

import { DEFAULT_STARTING_DATE } from "@/lib/constants";

const MM_TO_TH_VOWELS: Record<string, string> = {
  "ု": "ุ",
  "ူ": "ู",
  "ိ": "ิ",
  "ီ": "ี",
  "ေ": "เ",
  "ဲ": "ไ",
  "ာ": "า",
  "ါ": "า",
  "ံ": "ํ",
};

const normalizeAiCompositionText = (text: string) => {
  const lines = text.split("\n");
  const out = lines.map((line) => {
    if (!/[\u0E00-\u0E7F]/.test(line)) return line;
    if (!/[\u102B-\u1032\u1036]/.test(line)) return line;
    let next = line;
    for (const [mm, th] of Object.entries(MM_TO_TH_VOWELS)) {
      if (next.includes(mm)) next = next.split(mm).join(th);
    }
    if (/[()\u0E00-\u0E7F]/.test(next)) {
      next = next.replace(/\(([^)]*)\)/g, (_m, inner) => {
        const cleaned = String(inner)
          .replace(/[\u0E00-\u0E7F]/g, "")
          .replace(/\s{2,}/g, " ")
          .trim();
        return `(${cleaned})`;
      });
    }
    return next;
  });
  return out.join("\n");
};

export type SyncStatus = "offline" | "syncing" | "live";

export function useVocabulary() {
  const [uid, setUid] = useState<string | null>(null);
  const [isAnonymous, setIsAnonymous] = useState(false);
  const [email, setEmail] = useState<string | null>(null);
  const [failedIdsCount, setFailedIdsCount] = useState(0);
  const [failedIds, setFailedIds] = useState<string[]>([]);
  const [rule, setRule] = useState<number>(() => {
    if (typeof window !== "undefined") {
      const local = localStorage.getItem("policy_rule");
      return local ? parseInt(local, 10) : 0;
    }
    return 0;
  });
  const [xDate, setXDate] = useState<string>(() => {
    if (typeof window !== "undefined") {
      const local = localStorage.getItem("policy_x_date");
      return local || DEFAULT_STARTING_DATE;
    }
    return DEFAULT_STARTING_DATE;
  });
  const [vocabLogic, setVocabLogic] = useState<VocabLogic>(() => {
    if (typeof window !== "undefined") {
      const c = localStorage.getItem("vocab_logic_consonants") || "";
      const v = localStorage.getItem("vocab_logic_vowels") || "";
      const t = localStorage.getItem("vocab_logic_tones") || "";
      return { consonants: c, vowels: v, tones: t };
    }
    return { consonants: "", vowels: "", tones: "" };
  });
  const [displayName, setDisplayName] = useState<string | null>(null);
  const [photoURL, setPhotoURL] = useState<string | null>(null);
  const [items, setItems] = useState<VocabularyEntry[]>(() => {
    if (typeof window !== "undefined") {
      const local = localStorage.getItem("cached_vocab_items");
      return local ? JSON.parse(local) : [];
    }
    return [];
  });
  const aiCompositionMigrationRef = useRef(false);

  useEffect(() => {
    if (typeof window !== "undefined" && items.length === 0) {
      getVocabFromIndexedDB().then(savedItems => {
        if (savedItems.length > 0) {
          setItems(savedItems);
          setLoading(false);
        }
      });
    }
  }, []);
  const [loading, setLoading] = useState(() => {
    if (typeof window !== "undefined") {
      return localStorage.getItem("cached_vocab_items") ? false : true;
    }
    return true;
  });
  const [fromCache, setFromCache] = useState(true);
  const [online, setOnline] = useState(true);
  const [vocabError, setVocabError] = useState<string | null>(null);
  const [aiApiKey, setAiApiKey] = useState<string | null>(() => {
    if (typeof window !== "undefined") {
      return localStorage.getItem("google_ai_studio_key");
    }
    return null;
  });
  const [aiKeyLoading, setAiKeyLoading] = useState(false);
  const [startingDate, setStartingDate] = useState<string>(() => {
    if (typeof window !== "undefined") {
      const local = localStorage.getItem("startingDate");
      return local || DEFAULT_STARTING_DATE;
    }
    return DEFAULT_STARTING_DATE;
  });
  const [goalsLoading, setGoalsLoading] = useState(false);
  const [authInitializing, setAuthInitializing] = useState(true);
  const [userContext, setUserContext] = useState<UserContext | null>(null);
  const [contextLoading, setContextLoading] = useState(false);

  useEffect(() => {
    if (!isFirebaseConfigured) {
      setAuthInitializing(false);
      setUid(null);
      return;
    }
    const auth = getFirebaseAuth();
    return onAuthStateChanged(auth, (user) => {
      if (user) {
        setUid(user.uid);
        setIsAnonymous(user.isAnonymous);
        setEmail(user.email);
        setDisplayName(user.displayName);
        setPhotoURL(user.photoURL);
      } else {
        setUid(null);
        setIsAnonymous(false);
        setEmail(null);
        setDisplayName(null);
        setPhotoURL(null);
        setItems([]);
      }
      setAuthInitializing(false);
    });
  }, []);

  useEffect(() => {
    if (!uid || isAnonymous) {
      setAiApiKey(null);
      return;
    }

    const loadKey = async () => {
      if (!uid || isAnonymous) return;
      setAiKeyLoading(true);
      try {
        // Try to migrate from localStorage if present
        const localKey = typeof window !== "undefined" ? localStorage.getItem("google_ai_studio_key") : null;
        const cloudKey = await fetchAiApiKey(uid!);

        if (localKey && !cloudKey) {
          await saveAiApiKey(uid!, localKey);
          setAiApiKey(localKey);
        } else if (cloudKey) {
          setAiApiKey(cloudKey);
        }
      } catch (e) {
        console.error("Failed to load AI Key:", e);
      } finally {
        setAiKeyLoading(false);
      }
    };

    const loadGoals = async () => {
      setGoalsLoading(true);
      try {
        // Tier 1: Local Storage (Instant)
        const localDate = localStorage.getItem("startingDate");
        if (localDate) {
          setStartingDate(localDate);
        }

        // Load Vocab Logic from local storage
        const localC = localStorage.getItem("vocab_logic_consonants");
        const localV = localStorage.getItem("vocab_logic_vowels");
        const localT = localStorage.getItem("vocab_logic_tones");
        if (localC || localV || localT) {
          setVocabLogic({ 
            consonants: localC || "", 
            vowels: localV || "", 
            tones: localT || "" 
          });
        }

        // Tier 2: Firestore Sync
        const [goals, logic, context] = await Promise.all([
          fetchStudyGoals(uid),
          fetchVocabLogic(uid),
          fetchUserContext(uid)
        ]);

        if (goals) {
          if (goals.startingDate) {
            setStartingDate(goals.startingDate);
            localStorage.setItem("startingDate", goals.startingDate);
          }
          if (goals.rule !== undefined) {
            setRule(goals.rule);
            localStorage.setItem("policy_rule", goals.rule.toString());
          }
          if (goals.xDate) {
            setXDate(goals.xDate);
            localStorage.setItem("policy_x_date", goals.xDate);
          }
        }

        if (logic) {
          setVocabLogic(logic);
          localStorage.setItem("vocab_logic_consonants", logic.consonants || "");
          localStorage.setItem("vocab_logic_vowels", logic.vowels || "");
          localStorage.setItem("vocab_logic_tones", logic.tones || "");
        }

        if (context) {
          setUserContext(context);
        }
      } catch (err) {
        console.error("Error fetching study goals/logic:", err);
      } finally {
        setGoalsLoading(false);
      }
    };

    // Clean up generic keys once to remove remnants
    const cleanupRemnants = () => {
      const keysToClear = ["dailyTarget", "manual_daily_target", "userDailyGoal"];
      keysToClear.forEach(k => {
        if (localStorage.getItem(k)) {
          console.log(`Cleaning up stale localStorage key: ${k}`);
          localStorage.removeItem(k);
        }
      });
    };

    cleanupRemnants();
    void loadKey();
    void loadGoals();
  }, [uid, isAnonymous]);

  useEffect(() => {
    if (!uid || isAnonymous) {
      setItems([]);
      setLoading(false);
      setFromCache(true);
      setVocabError(null);
      return;
    }

    setLoading(true);
    setVocabError(null);

    const maybeMigrateAiComposition = (nextItems: VocabularyEntry[], fromCache: boolean) => {
      if (typeof window === "undefined") return;
      if (fromCache) return;
      if (aiCompositionMigrationRef.current) return;
      const key = `ai_comp_mm_migrated_${uid}`;
      if (localStorage.getItem(key)) return;
      aiCompositionMigrationRef.current = true;

      const updates: Array<{ id: string; ai_composition: string }> = [];
      nextItems.forEach((item) => {
        const comp = typeof item.ai_composition === "string" ? item.ai_composition : "";
        if (!comp) return;
        const hasThai = /[\u0E00-\u0E7F]/.test(comp);
        const hasMyanmarVowels = /[\u102B-\u1032\u1036]/.test(comp);
        const hasThaiInParens = /\([^)]*[\u0E00-\u0E7F][^)]*\)/.test(comp);
        if (!hasThai || (!hasMyanmarVowels && !hasThaiInParens)) return;
        const fixed = normalizeAiCompositionText(comp);
        if (fixed !== comp) {
          updates.push({ id: item.id, ai_composition: fixed });
        }
      });

      if (updates.length === 0) {
        localStorage.setItem(key, String(Date.now()));
        return;
      }

      void batchUpdateAiComposition(uid, updates)
        .then(() => {
          localStorage.setItem(key, String(Date.now()));
        })
        .catch((err) => {
          console.error("AI composition migration failed:", err);
          aiCompositionMigrationRef.current = false;
        });
    };

    try {
      const unsub = listenVocabulary(
        uid,
        (next) => {
          console.log("Vocab data source:", next.fromCache ? "Cache" : "Server");
          maybeMigrateAiComposition(next.items, next.fromCache);
          setItems(next.items);
          if (typeof window !== "undefined") {
            localStorage.setItem("cached_vocab_items", JSON.stringify(next.items));
            saveVocabToIndexedDB(next.items);
          }
          setFromCache(next.fromCache);
          setLoading(false);
        },
        (err) => {
          setVocabError(`${err.code ?? "firestore-error"}: ${err.message ?? ""}`.trim());
          setItems([]);
          setFromCache(true);
          setLoading(false);
        }
      );

      return () => {
        console.log("Unsubscribing from vocab listener (Effect 3)");
        unsub();
      };
    } catch (e: unknown) {
      const err = e as { message?: string };
      setVocabError(err?.message ? String(err.message) : "Failed to start Firestore listener.");
      setItems([]);
      setFromCache(true);
      setLoading(false);
      return;
    }
  }, [uid, isAnonymous]);

  const updateAiApiKey = async (key: string) => {
    if (!uid) return;
    setAiKeyLoading(true);
    try {
      await saveAiApiKey(uid, key);
      setAiApiKey(key);
      localStorage.setItem("google_ai_studio_key", key);
    } finally {
      setAiKeyLoading(false);
    }
  };

  const updateVocabLogic = async (logic: VocabLogic) => {
    if (!uid) return;
    try {
      setVocabLogic(logic);
      localStorage.setItem("vocab_logic_consonants", logic.consonants || "");
      localStorage.setItem("vocab_logic_vowels", logic.vowels || "");
      localStorage.setItem("vocab_logic_tones", logic.tones || "");
      await saveVocabLogic(uid, logic);
    } catch (e) {
      console.error("Failed to save vocab logic:", e);
    }
  };

  const updateUserContext = async (context: UserContext) => {
    if (!uid) return;
    setContextLoading(true);
    try {
      await saveUserContext(uid, context);
      setUserContext(context);
    } finally {
      setContextLoading(false);
    }
  };

  const status: SyncStatus = loading ? "syncing" : "live";
  const isLive = !!uid && !isAnonymous && status === "live";

  const totalVocabCounts = useMemo(() => items.reduce((sum, it) => sum + (it.count || 0), 0), [items]);

  const backfillingState = useMemo(() => {
    const startIso = startingDate || DEFAULT_STARTING_DATE;
    const start = new Date(startIso);
    
    // Safety check for invalid date
    if (isNaN(start.getTime())) {
      console.warn("Invalid startingDate detected, falling back to today.");
      const fallback = new Date();
      fallback.setHours(0, 0, 0, 0);
      return {
        clearedDaysCount: 0,
        currentDayProgress: 0,
        currentTargetDate: fallback.toISOString().split('T')[0],
        dailyTarget: typeof rule === "number" ? rule : 500,
      };
    }
    
    start.setHours(0, 0, 0, 0);
    
    const totalHits = totalVocabCounts;
    const target = typeof rule === "number" ? rule : 500; // Single source of truth for compute
    
    // Prevent Division by Zero or NaN
    const clearedDaysCount = target > 0 ? Math.floor(totalHits / target) : 0;
    const currentDayProgress = target > 0 ? totalHits % target : 0;
    
    const currentTargetDate = new Date(start);
    currentTargetDate.setDate(start.getDate() + clearedDaysCount);
    
    return {
      clearedDaysCount,
      currentDayProgress,
      currentTargetDate: currentTargetDate.toISOString().split('T')[0],
      dailyTarget: target
    };
  }, [totalVocabCounts, startingDate, rule]);

  useEffect(() => {
    if (!uid) {
      setFailedIdsCount(0);
      setFailedIds([]);
      return;
    }

    const db = getFirebaseDb();
    const ref = doc(db, "users", uid, "settings", "failed_quiz");
    
    const unsub = onSnapshot(ref, (snap) => {
      if (snap.exists()) {
        const ids = (snap.data() as { ids?: string[] }).ids ?? [];
        setFailedIds(ids);
        setFailedIdsCount(ids.length);
      } else {
        setFailedIds([]);
        setFailedIdsCount(0);
      }
    });

    return () => unsub();
  }, [uid]);

  return useMemo(
    () => ({
      uid,
      isAnonymous,
      email,
      displayName,
      photoURL,
      items,
      loading,
      isLive,
      status,
      vocabError,
      aiApiKey,
      aiKeyLoading,
      updateAiApiKey,
      startingDate,
      goalsLoading,
      authInitializing,
      totalVocabCounts,
      backfillingState,
      rule,
      setRule,
      xDate,
      setXDate,
      vocabLogic,
      updateVocabLogic,
      userContext,
      updateUserContext,
      contextLoading,
      failedIdsCount,
      failedIds
    }),
    [
      uid,
      isAnonymous,
      email,
      displayName,
      photoURL,
      items,
      loading,
      isLive,
      status,
      vocabError,
      aiApiKey,
      aiKeyLoading,
      startingDate,
      goalsLoading,
      authInitializing,
      totalVocabCounts,
      backfillingState,
      rule,
      xDate,
      vocabLogic,
      userContext,
      contextLoading,
      failedIdsCount,
      failedIds
    ]
  );
}
