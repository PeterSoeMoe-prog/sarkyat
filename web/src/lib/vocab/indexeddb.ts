import { openDB, IDBPDatabase } from 'idb';
import type { VocabularyEntry } from './types';

const DB_NAME = 'sar-kyat-pro-db';
const STORE_NAME = 'vocabulary';
const DB_VERSION = 1;

let dbPromise: Promise<IDBPDatabase> | null = null;

function getDB() {
  if (!dbPromise && typeof window !== 'undefined') {
    dbPromise = openDB(DB_NAME, DB_VERSION, {
      upgrade(db) {
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          db.createObjectStore(STORE_NAME, { keyPath: 'id' });
        }
      },
    });
  }
  return dbPromise;
}

export async function saveVocabToIndexedDB(items: VocabularyEntry[]) {
  const db = await getDB();
  if (!db) return;
  const tx = db.transaction(STORE_NAME, 'readwrite');
  const store = tx.objectStore(STORE_NAME);
  await Promise.all(items.map(item => store.put(item)));
  await tx.done;
}

export async function getVocabFromIndexedDB(): Promise<VocabularyEntry[]> {
  const db = await getDB();
  if (!db) return [];
  return db.getAll(STORE_NAME);
}

export async function clearIndexedDB() {
  const db = await getDB();
  if (!db) return;
  const tx = db.transaction(STORE_NAME, 'readwrite');
  await tx.objectStore(STORE_NAME).clear();
  await tx.done;
}
