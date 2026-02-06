"use client";

import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocFromServer,
  getDocs,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  where,
  writeBatch,
  type FirestoreError,
  type QuerySnapshot,
  type Unsubscribe,
} from "firebase/firestore";

import { getFirebaseDb } from "@/lib/firebase/client";
import type { VocabularyEntry, VocabularyStatus } from "@/lib/vocab/types";

type VocabDoc = {
  id: string;
  thai: string;
  burmese?: string | null;
  count: number;
  hit?: number;
  status: VocabularyStatus;
  category?: string | null;
  ai_explanation?: string | null;
  createdAt?: unknown;
  updatedAt?: unknown;
};

function asMillis(ts: unknown): number {
  if (!ts) return 0;
  if (typeof ts === "number" && Number.isFinite(ts)) return ts;
  if (ts instanceof Date) return ts.getTime();
  const anyTs = ts as { toMillis?: () => number; seconds?: number; nanoseconds?: number };
  if (typeof anyTs?.toMillis === "function") {
    try {
      const v = anyTs.toMillis();
      return Number.isFinite(v) ? v : 0;
    } catch {
      return 0;
    }
  }
  if (typeof anyTs?.seconds === "number") {
    const seconds = anyTs.seconds;
    const nanos = typeof anyTs.nanoseconds === "number" ? anyTs.nanoseconds : 0;
    return Math.round(seconds * 1000 + nanos / 1e6);
  }
  return 0;
}

function normalizeDoc(data: VocabDoc): VocabularyEntry {
  return {
    id: data.id,
    thai: data.thai ?? "",
    burmese: data.burmese ?? null,
    count: Number.isFinite(Number(data.count))
      ? Number(data.count)
      : Number.isFinite(Number(data.hit))
        ? Number(data.hit)
        : 0,
    status: (data.status ?? "queue") as VocabularyStatus,
    category: data.category ?? null,
    updatedAt: asMillis(data.updatedAt),
    ai_explanation: typeof data.ai_explanation === "string" ? data.ai_explanation : null,
  };
}

export function vocabCollectionPath(uid: string) {
  return `users/${uid}/vocab`;
}

/**
 * AI API Key Storage
 */
export async function saveAiApiKey(uid: string, key: string): Promise<void> {
  if (!uid) return;
  const db = getFirebaseDb();
  const userRef = doc(db, "users", uid);
  await setDoc(userRef, { aiApiKey: key }, { merge: true });
}

export async function fetchAiApiKey(uid: string): Promise<string | null> {
  if (!uid) return null;
  const db = getFirebaseDb();
  const userRef = doc(db, "users", uid);
  const snap = await getDoc(userRef);
  if (snap.exists()) {
    return (snap.data() as { aiApiKey?: string }).aiApiKey ?? null;
  }
  return null;
}

/**
 * Study Goals Storage
 */
export type UserStudyGoals = {
  startingDate: string;
  userDailyGoal?: number;
};

export async function saveStudyGoals(uid: string, goals: UserStudyGoals): Promise<void> {
  if (!uid) return;
  const db = getFirebaseDb();
  const userRef = doc(db, "users", uid);
  await setDoc(userRef, goals, { merge: true });
}

export async function fetchStudyGoals(uid: string): Promise<UserStudyGoals | null> {
  if (!uid) return null;
  const db = getFirebaseDb();
  const userRef = doc(db, "users", uid);
  const snap = await getDoc(userRef);
  if (snap.exists()) {
    const data = snap.data();
    if (data.userDailyGoal !== undefined && data.startingDate !== undefined) {
      return {
        userDailyGoal: Number(data.userDailyGoal),
        startingDate: String(data.startingDate),
      };
    }
  }
  return null;
}


export type ListenVocabularyState = {
  items: VocabularyEntry[];
  fromCache: boolean;
};

export function listenVocabulary(
  uid: string,
  onData: (state: ListenVocabularyState) => void,
  onError?: (err: FirestoreError) => void
): Unsubscribe {
  const db = getFirebaseDb();
  const col = collection(db, vocabCollectionPath(uid));
  const q = query(col, orderBy("updatedAt", "desc"));

  return onSnapshot(
    q,
    { includeMetadataChanges: true },
    (snap: QuerySnapshot) => {
      const items = snap.docs
        .map((d) => d.data() as VocabDoc)
        .filter((d) => !!d && typeof d.id === "string")
        .map(normalizeDoc);
      onData({ items, fromCache: snap.metadata.fromCache });
    },
    (err) => {
      onError?.(err);
    }
  );
}

export async function upsertVocabulary(uid: string, entry: VocabularyEntry) {
  const db = getFirebaseDb();
  const ref = doc(db, vocabCollectionPath(uid), entry.id);
  const payload: VocabDoc = {
    id: entry.id,
    thai: entry.thai,
    burmese: entry.burmese ?? null,
    count: entry.count ?? 0,
    status: entry.status ?? "queue",
    category: entry.category ?? null,
    ai_explanation: entry.ai_explanation ?? null,
    updatedAt: serverTimestamp(),
  };

  await setDoc(ref, payload, { merge: true });
}

export async function deleteVocabulary(uid: string, id: string) {
  const db = getFirebaseDb();
  const ref = doc(db, vocabCollectionPath(uid), id);
  await deleteDoc(ref);
}

export async function fetchVocabularyEntryFromServer(
  uid: string,
  id: string
): Promise<VocabularyEntry | null> {
  const db = getFirebaseDb();
  const ref = doc(db, vocabCollectionPath(uid), id);
  const snap = await getDocFromServer(ref);
  if (!snap.exists()) return null;
  return normalizeDoc(snap.data() as VocabDoc);
}

export type ImportVocabularyRow = {
  thai: string;
  burmese?: string | null;
  count?: number | string | null;
  category?: string | null;
  status?: VocabularyStatus | string | null;
};

export async function clearVocabulary(uid: string) {
  const db = getFirebaseDb();
  const col = collection(db, vocabCollectionPath(uid));
  const snap = await getDocs(col);

  const chunkSize = 450;
  for (let start = 0; start < snap.docs.length; start += chunkSize) {
    const batch = writeBatch(db);
    for (const d of snap.docs.slice(start, start + chunkSize)) {
      batch.delete(d.ref);
    }
    await batch.commit();
  }
}

export async function importVocabularyRows(uid: string, rows: ImportVocabularyRow[]) {
  const db = getFirebaseDb();

  const normalized = rows
    .map((r) => ({
      thai: (r.thai ?? "").trim(),
      burmese: (r.burmese ?? null)?.toString().trim() || null,
      category: (r.category ?? null)?.toString().trim() || null,
      count: Number.isFinite(Number(r.count)) ? Number(r.count) : 0,
      status:
        String(r.status ?? "") === "drill" || String(r.status ?? "") === "ready"
          ? (String(r.status) as VocabularyStatus)
          : "queue",
    }))
    .filter((r) => r.thai.length > 0);

  const chunkSize = 450;
  let firstId: string | null = null;
  for (let start = 0; start < normalized.length; start += chunkSize) {
    const chunk = normalized.slice(start, start + chunkSize);
    const batch = writeBatch(db);

    for (const r of chunk) {
      const id = globalThis.crypto?.randomUUID?.() ?? String(Date.now()) + Math.random();
      const ref = doc(db, vocabCollectionPath(uid), String(id));

      if (!firstId) firstId = ref.id;

      batch.set(
        ref,
        {
          id: ref.id,
          thai: r.thai,
          burmese: r.burmese,
          count: r.count,
          status: r.status,
          category: r.category,
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      );
    }

    await batch.commit();
  }

  return { importedCount: normalized.length, firstId };
}
