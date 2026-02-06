"use client";

import { useEffect, useMemo, useState } from "react";
import { onAuthStateChanged } from "firebase/auth";

import { getFirebaseAuth, isFirebaseConfigured } from "@/lib/firebase/client";
import { fetchAiApiKey, fetchStudyGoals, listenVocabulary, saveAiApiKey, saveStudyGoals, type UserStudyGoals } from "@/lib/vocab/firestore";
import type { VocabularyEntry } from "@/lib/vocab/types";

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
  const [dailyTarget, setDailyTarget] = useState(500);
  const [startingDate, setStartingDate] = useState(() => new Date().toISOString().split("T")[0]);
  const [goalsLoading, setGoalsLoading] = useState(false);

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
      if (!uid || isAnonymous) return;
      setGoalsLoading(true);
      try {
        const goals = await fetchStudyGoals(uid);
        if (goals) {
          setDailyTarget(goals.dailyTarget);
          setStartingDate(goals.startingDate);
        }
      } catch (e) {
        console.error("Failed to load study goals:", e);
      } finally {
        setGoalsLoading(false);
      }
    };

    void loadKey();
    void loadGoals();
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

  const updateStudyGoals = async (goals: UserStudyGoals) => {
    if (!uid) return;
    setGoalsLoading(true);
    try {
      await saveStudyGoals(uid, goals);
      setDailyTarget(goals.dailyTarget);
      setStartingDate(goals.startingDate);
    } finally {
      setGoalsLoading(false);
    }
  };

  useEffect(() => {
    // RE-ENABLED FOR PERSISTENCE: Firebase listener
    if (!isFirebaseConfigured) {
      setUid(null);
      setItems([]);
      setLoading(false);
      setFromCache(true);
      return;
    }

    const auth = getFirebaseAuth();
    
    // Check current user immediately
    const user = auth.currentUser;
    if (user) {
      setUid(user.uid);
      setIsAnonymous(user.isAnonymous);
      setEmail(user.email);
      setDisplayName(user.displayName);
      setPhotoURL(user.photoURL);
    }

    const unsub = onAuthStateChanged(auth, (user) => {
      setUid(user?.uid ?? null);
      setIsAnonymous(user?.isAnonymous ?? false);
      setEmail(user?.email ?? null);
      setDisplayName(user?.displayName ?? null);
      setPhotoURL(user?.photoURL ?? null);
    });
    return () => unsub();
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const onOnline = () => setOnline(true);
    const onOffline = () => setOnline(false);
    setOnline(navigator.onLine);
    window.addEventListener("online", onOnline);
    window.addEventListener("offline", onOffline);
    return () => {
      window.removeEventListener("online", onOnline);
      window.removeEventListener("offline", onOffline);
    };
  }, []);

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

  const status: SyncStatus = !online
    ? "offline"
    : loading || fromCache
      ? "syncing"
      : "live";

  const isLive = !!uid && !isAnonymous && status === "live";

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
      dailyTarget,
      startingDate,
      goalsLoading,
      updateStudyGoals,
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
      dailyTarget,
      startingDate,
      goalsLoading,
    ]
  );
}
