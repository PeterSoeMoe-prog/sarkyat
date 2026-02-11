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
  updateDoc,
  where,
  writeBatch,
  type FirestoreError,
  type QuerySnapshot,
  type Unsubscribe,
} from "firebase/firestore";

import { getFirebaseDb } from "@/lib/firebase/client";
import type { VocabularyEntry, VocabularyStatus, BookEntry, BookSession, SessionStatus } from "@/lib/vocab/types";
import { DEFAULT_STARTING_DATE } from "@/lib/constants";

type VocabDoc = {
  id: string;
  thai: string;
  burmese?: string | null;
  count: number;
  hit?: number;
  status: VocabularyStatus;
  category?: string | null;
  ai_explanation?: string | null;
  ai_composition?: string | null;
  ai_sentence?: string | null;
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
  const count = Number.isFinite(Number(data.count))
    ? Number(data.count)
    : Number.isFinite(Number(data.hit))
      ? Number(data.hit)
      : 0;
  
  return {
    id: data.id,
    thai: data.thai ?? "",
    burmese: data.burmese ?? null,
    count,
    status: (data.status ?? "queue") as VocabularyStatus,
    category: data.category ?? null,
    updatedAt: asMillis(data.updatedAt),
    ai_explanation: typeof data.ai_explanation === "string" ? data.ai_explanation : null,
    ai_composition: typeof data.ai_composition === "string" ? data.ai_composition : null,
    ai_sentence: typeof data.ai_sentence === "string" ? data.ai_sentence : null,
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
  startingDate?: string;
  rule?: number;
  xDate?: string;
};

function normalizeGoalDate(raw: unknown): string {
  if (typeof raw !== "string") return DEFAULT_STARTING_DATE;
  const value = raw.trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) return value;
  const dmy = value.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
  if (dmy) {
    const [, dd, mm, yyyy] = dmy;
    return `${yyyy}-${mm}-${dd}`;
  }
  return DEFAULT_STARTING_DATE;
}

function normalizeGoalsDoc(data: Record<string, unknown> | undefined): UserStudyGoals | null {
  if (!data) return null;
  const startingDateRaw = data.startingDate;
  const hasDate = startingDateRaw !== undefined && startingDateRaw !== null;
  const hasRule = data.rule !== undefined && data.rule !== null;
  const hasXDate = data.xDate !== undefined && data.xDate !== null;
  if (!hasDate && !hasRule && !hasXDate) return null;

  return {
    startingDate: hasDate ? normalizeGoalDate(startingDateRaw) : undefined,
    rule: data.rule !== undefined ? Number(data.rule) : undefined,
    xDate: data.xDate !== undefined ? normalizeGoalDate(data.xDate) : undefined,
  };
}

export async function saveStudyGoals(uid: string, goals: UserStudyGoals): Promise<void> {
  if (!uid) return;
  const db = getFirebaseDb();
  const normalizedStartingDate =
    goals.startingDate !== undefined ? normalizeGoalDate(goals.startingDate) : undefined;

  // Fixed path to sub-document for goals
  const goalRef = doc(db, "users", uid, "settings", "goals");
  await setDoc(
    goalRef,
    {
      ...(normalizedStartingDate !== undefined ? { startingDate: normalizedStartingDate } : {}),
      ...(goals.rule !== undefined ? { rule: Number(goals.rule) } : {}),
      ...(goals.xDate !== undefined ? { xDate: normalizeGoalDate(goals.xDate) } : {}),
    },
    { merge: true }
  );
}

export async function fetchStudyGoals(uid: string): Promise<UserStudyGoals | null> {
  if (!uid) return null;
  const db = getFirebaseDb();
  const goalsRef = doc(db, "users", uid, "settings", "goals");
  
  try {
    // Single source of truth: users/{uid}/settings/goals.
    const goalsSnap = await getDocFromServer(goalsRef);
    const normalizedGoals = normalizeGoalsDoc(goalsSnap.exists() ? goalsSnap.data() : undefined);
    if (normalizedGoals) {
      return normalizedGoals;
    }
  } catch (error) {
    console.error("Error fetching study goals from server:", error);
    // Fallback to cache if server is unavailable.
    const goalsSnap = await getDoc(goalsRef);
    const normalizedGoals = normalizeGoalsDoc(goalsSnap.exists() ? goalsSnap.data() : undefined);
    if (normalizedGoals) {
      return normalizedGoals;
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

export function booksCollectionPath(uid: string) {
  return `users/${uid}/books`;
}

export async function saveBook(uid: string, book: Omit<BookEntry, "createdAt">) {
  const db = getFirebaseDb();
  const ref = doc(db, booksCollectionPath(uid), book.id);
  await setDoc(ref, {
    ...book,
    createdAt: serverTimestamp(),
  }, { merge: true });
}

export function listenBooks(
  uid: string,
  onData: (books: BookEntry[]) => void,
  onError?: (err: FirestoreError) => void
): Unsubscribe {
  const db = getFirebaseDb();
  const col = collection(db, booksCollectionPath(uid));
  const q = query(col, orderBy("createdAt", "desc"));

  return onSnapshot(
    q,
    (snap: QuerySnapshot) => {
      const books = snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          name: data.name ?? "",
          writer: data.writer ?? "",
          createdAt: asMillis(data.createdAt),
        } as BookEntry;
      });
      onData(books);
    },
    (err) => onError?.(err)
  );
}

export async function deleteBook(uid: string, bookId: string) {
  const db = getFirebaseDb();
  const ref = doc(db, booksCollectionPath(uid), bookId);
  await deleteDoc(ref);
}

export async function updateBook(
  uid: string,
  bookId: string,
  data: { name?: string; writer?: string }
) {
  const db = getFirebaseDb();
  const ref = doc(db, booksCollectionPath(uid), bookId);
  await updateDoc(ref, {
    ...(data.name !== undefined ? { name: data.name } : {}),
    ...(data.writer !== undefined ? { writer: data.writer } : {}),
    updatedAt: serverTimestamp(),
  });
}

export function sessionsCollectionPath(uid: string, bookId: string) {
  return `users/${uid}/books/${bookId}/sessions`;
}

export async function saveSession(uid: string, bookId: string, session: Omit<BookSession, "createdAt">) {
  const db = getFirebaseDb();
  const ref = doc(db, sessionsCollectionPath(uid, bookId), session.id);
  const note = session.note ? String(session.note).slice(0, 1000) : undefined;
  const order = Number.isFinite(session.order) ? Number(session.order) : undefined;
  const status: SessionStatus = session.status === "ready" ? "ready" : "drill";
  await setDoc(ref, {
    ...session,
    ...(note !== undefined ? { note } : {}),
    ...(order !== undefined ? { order } : {}),
    status,
    createdAt: serverTimestamp(),
  }, { merge: true });
}

export function listenSessions(
  uid: string,
  bookId: string,
  onData: (sessions: BookSession[]) => void,
  onError?: (err: FirestoreError) => void
): Unsubscribe {
  const db = getFirebaseDb();
  const col = collection(db, sessionsCollectionPath(uid, bookId));
  const q = query(col, orderBy("createdAt", "desc"));

  return onSnapshot(
    q,
    (snap: QuerySnapshot) => {
      const sessions = snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          bookId: data.bookId,
          name: data.name ?? "",
          note: typeof data.note === "string" ? data.note : undefined,
          order: Number.isFinite(Number(data.order)) ? Number(data.order) : undefined,
          status: data.status === "ready" ? "ready" : "drill",
          createdAt: asMillis(data.createdAt),
        } as BookSession;
      });
      onData(sessions);
    },
    (err) => onError?.(err)
  );
}

export async function deleteSession(uid: string, bookId: string, sessionId: string) {
  const db = getFirebaseDb();
  const ref = doc(db, sessionsCollectionPath(uid, bookId), sessionId);
  await deleteDoc(ref);
}

export async function fetchSession(uid: string, bookId: string, sessionId: string): Promise<BookSession | null> {
  const db = getFirebaseDb();
  const ref = doc(db, sessionsCollectionPath(uid, bookId), sessionId);
  const snap = await getDoc(ref);
  if (!snap.exists()) return null;
  const data = snap.data();
  return {
    id: snap.id,
    bookId: data.bookId,
    name: data.name ?? "",
    note: typeof data.note === "string" ? data.note : undefined,
    order: Number.isFinite(Number(data.order)) ? Number(data.order) : undefined,
    status: data.status === "ready" ? "ready" : "drill",
    createdAt: asMillis(data.createdAt),
  } as BookSession;
}

export async function updateSession(
  uid: string,
  bookId: string,
  sessionId: string,
  data: { name?: string; note?: string; order?: number; status?: SessionStatus }
) {
  const db = getFirebaseDb();
  const ref = doc(db, sessionsCollectionPath(uid, bookId), sessionId);
  const payload: Record<string, unknown> = {};
  if (data.name !== undefined) payload.name = data.name;
  if (data.note !== undefined) payload.note = typeof data.note === "string" ? data.note.slice(0, 1000) : data.note;
  if (data.order !== undefined && Number.isFinite(data.order)) payload.order = data.order;
  if (data.status !== undefined) payload.status = data.status === "ready" ? "ready" : "drill";
  payload.updatedAt = serverTimestamp();
  await updateDoc(ref, payload);
}

export async function fetchBook(uid: string, bookId: string): Promise<BookEntry | null> {
  const db = getFirebaseDb();
  const ref = doc(db, booksCollectionPath(uid), bookId);
  const snap = await getDoc(ref);
  if (!snap.exists()) return null;
  const data = snap.data();
  return {
    id: snap.id,
    name: data.name ?? "",
    writer: data.writer ?? "",
    createdAt: asMillis(data.createdAt),
  } as BookEntry;
}

export async function upsertVocabulary(uid: string, entry: VocabularyEntry) {
  const db = getFirebaseDb();
  const ref = doc(db, vocabCollectionPath(uid), entry.id);
  const payload: Partial<VocabDoc> = {
    id: entry.id,
    thai: entry.thai,
    burmese: entry.burmese ?? null,
    count: entry.count ?? 0,
    status: entry.status ?? "queue",
    category: entry.category ?? null,
    ai_explanation: entry.ai_explanation ?? null,
    ai_composition: entry.ai_composition ?? null,
    ai_sentence: entry.ai_sentence ?? null,
    updatedAt: serverTimestamp(),
  };

  await setDoc(ref, payload, { merge: true });
}

export async function updateAiExplanation(uid: string, vocabId: string, payload: { ai_composition?: string | null, ai_sentence?: string | null, ai_explanation?: string | null }) {
  const db = getFirebaseDb();
  const ref = doc(db, vocabCollectionPath(uid), vocabId);
  await updateDoc(ref, {
    ...payload,
    updatedAt: serverTimestamp(),
  });
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

/**
 * Persistent Settings Storage
 */
export type VocabLogic = {
  consonants?: string;
  vowels?: string;
  tones?: string;
};

export async function saveVocabLogic(uid: string, logic: VocabLogic): Promise<void> {
  if (!uid) return;
  const db = getFirebaseDb();
  const ref = doc(db, "users", uid, "settings", "vocab_logic");
  await setDoc(ref, { ...logic, updatedAt: serverTimestamp() }, { merge: true });
}

export async function fetchVocabLogic(uid: string): Promise<VocabLogic | null> {
  if (!uid) return null;
  const db = getFirebaseDb();
  const ref = doc(db, "users", uid, "settings", "vocab_logic");
  const snap = await getDoc(ref);
  if (snap.exists()) {
    const data = snap.data();
    return {
      consonants: data.consonants ?? "",
      vowels: data.vowels ?? "",
      tones: data.tones ?? "",
    };
  }
  return null;
}

export async function saveFailedQuizIds(uid: string, ids: string[]): Promise<void> {
  if (!uid) return;
  const db = getFirebaseDb();
  const ref = doc(db, "users", uid, "settings", "failed_quiz");
  await setDoc(ref, { ids, updatedAt: serverTimestamp() }, { merge: true });
}

export async function fetchFailedQuizIds(uid: string): Promise<string[]> {
  if (!uid) return [];
  const db = getFirebaseDb();
  const ref = doc(db, "users", uid, "settings", "failed_quiz");
  const snap = await getDoc(ref);
  if (snap.exists()) {
    return (snap.data() as { ids?: string[] }).ids ?? [];
  }
  return [];
}

export type UserContext = {
  profession?: string;
  interests?: string;
  updatedAt?: unknown;
};

export async function saveUserContext(uid: string, context: UserContext): Promise<void> {
  if (!uid) return;
  const db = getFirebaseDb();
  const ref = doc(db, "users", uid, "settings", "user_context");
  await setDoc(ref, { ...context, updatedAt: serverTimestamp() }, { merge: true });
}

export async function fetchUserContext(uid: string): Promise<UserContext | null> {
  if (!uid) return null;
  const db = getFirebaseDb();
  const ref = doc(db, "users", uid, "settings", "user_context");
  const snap = await getDoc(ref);
  if (snap.exists()) {
    return snap.data() as UserContext;
  }
  return null;
}
