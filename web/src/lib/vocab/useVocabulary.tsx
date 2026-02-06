"use client";

import { useEffect, useMemo, useState } from "react";
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
  where 
} from "firebase/firestore";
import { onAuthStateChanged } from "firebase/auth";
import { getFirebaseAuth, getFirebaseDb, isFirebaseConfigured } from "@/lib/firebase/client";
import { fetchAiApiKey, fetchStudyGoals, listenVocabulary, saveAiApiKey, saveStudyGoals, type UserStudyGoals } from "@/lib/vocab/firestore";
import type { VocabularyEntry } from "@/lib/vocab/types";

import { DEFAULT_STARTING_DATE } from "@/lib/constants";

export type SyncStatus = "offline" | "syncing" | "live";

export function useVocabulary() {
  const [uid, setUid] = useState<string | null>(null);
  const [isAnonymous, setIsAnonymous] = useState(false);
  const [email, setEmail] = useState<string | null>(null);
  const [displayName, setDisplayName] = useState<string | null>(null);
  const [photoURL, setPhotoURL] = useState<string | null>(null);
  const [items, setItems] = useState<VocabularyEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [fromCache, setFromCache] = useState(true);
  const [online, setOnline] = useState(true);
  const [vocabError, setVocabError] = useState<string | null>(null);
  const [aiApiKey, setAiApiKey] = useState<string | null>(null);
  const [aiKeyLoading, setAiKeyLoading] = useState(false);
  const [userDailyGoal, setUserDailyGoal] = useState<number>(() => {
    if (typeof window !== "undefined") {
      const local = localStorage.getItem("userDailyGoal");
      return local ? parseInt(local, 10) : 500;
    }
    return 500;
  });
  const [startingDate, setStartingDate] = useState<string>(DEFAULT_STARTING_DATE);
  const [goalsLoading, setGoalsLoading] = useState(false);
  const [lastSavedGoals, setLastSavedGoals] = useState<{ dailyTarget: number; startingDate: string } | null>(null);
  const [authInitializing, setAuthInitializing] = useState(true);

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
      if (!uid) return;
      setGoalsLoading(true);
      try {
        // Tier 1: Local Storage (Instant)
        const localGoal = localStorage.getItem("userDailyGoal");
        if (localGoal) {
          setUserDailyGoal(parseInt(localGoal, 10));
        }

        // Tier 2: Firestore Sync
        const goals = await fetchStudyGoals(uid);
        if (goals) {
          if (goals.userDailyGoal) {
            setUserDailyGoal(goals.userDailyGoal);
            localStorage.setItem("userDailyGoal", goals.userDailyGoal.toString());
          }
          if (goals.startingDate) setStartingDate(goals.startingDate);
        }
      } catch (err) {
        console.error("Error fetching study goals:", err);
      } finally {
        setGoalsLoading(false);
      }
    };

    void loadKey();
    void loadGoals();
  }, [uid, isAnonymous]);

  useEffect(() => {
    if (!uid || isAnonymous) return;

    const db = getFirebaseDb();
    const docRef = doc(db, "users", uid, "settings", "goals");
    const unsubscribe = onSnapshot(docRef, (docSnap: any) => {
      if (docSnap.exists()) {
        const data = docSnap.data();
        if (data.userDailyGoal) {
          setUserDailyGoal(data.userDailyGoal);
          localStorage.setItem("userDailyGoal", data.userDailyGoal.toString());
        }
        if (data.startingDate) setStartingDate(data.startingDate);
      }
    }, (err) => {
      console.error("Firestore goals listener error:", err);
    });

    return () => unsubscribe();
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

    try {
      const unsub = listenVocabulary(
        uid,
        (next) => {
          setItems(next.items);
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

      return () => unsub();
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

  const updateStudyGoalsLocal = async (newGoal: number, newDate: string) => {
    if (!uid) return;
    setGoalsLoading(true);
    try {
      // 1. Local Storage Update (Instant)
      localStorage.setItem("userDailyGoal", newGoal.toString());
      
      // 2. Global State Update
      setUserDailyGoal(newGoal);
      setStartingDate(newDate);

      // 3. Firestore Atomic Update
      const db = getFirebaseDb();
      const docRef = doc(db, "users", uid, "settings", "goals");
      await setDoc(docRef, {
        userDailyGoal: newGoal,
        startingDate: newDate,
        updatedAt: Date.now()
      }, { merge: true });

      console.log('Target Saved Successfully:', newGoal);
    } catch (err) {
      console.error("Error saving study goals:", err);
    } finally {
      setGoalsLoading(false);
    }
  };

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

    try {
      const unsub = listenVocabulary(
        uid,
        (next) => {
          setItems(next.items);
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

      return () => unsub();
    } catch (e: unknown) {
      const err = e as { message?: string };
      setVocabError(err?.message ? String(err.message) : "Failed to start Firestore listener.");
      setItems([]);
      setFromCache(true);
      setLoading(false);
      return;
    }
  }, [uid, isAnonymous]);

  const status: SyncStatus = loading ? "syncing" : "live";
  const isLive = !!uid && !isAnonymous && status === "live";

  const totalVocabCounts = useMemo(() => items.reduce((sum, it) => sum + (it.count || 0), 0), [items]);

  const backfillingState = useMemo(() => {
    if (!startingDate) return null;
    const start = new Date(startingDate);
    start.setHours(0, 0, 0, 0);
    
    const totalHits = totalVocabCounts;
    const target = userDailyGoal;
    const clearedDaysCount = Math.floor(totalHits / target);
    const currentDayProgress = totalHits % target;
    
    const currentTargetDate = new Date(start);
    currentTargetDate.setDate(start.getDate() + clearedDaysCount);
    
    return {
      clearedDaysCount,
      currentDayProgress,
      currentTargetDate: currentTargetDate.toISOString().split('T')[0],
      dailyTarget: target
    };
  }, [totalVocabCounts, startingDate, userDailyGoal]);

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
      userDailyGoal,
      startingDate,
      goalsLoading,
      updateStudyGoals: updateStudyGoalsLocal,
      authInitializing,
      totalVocabCounts,
      backfillingState
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
      userDailyGoal,
      startingDate,
      goalsLoading,
      authInitializing,
      totalVocabCounts,
      backfillingState
    ]
  );
}
