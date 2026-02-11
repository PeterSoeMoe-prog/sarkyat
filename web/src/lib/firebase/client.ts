"use client";

import { initializeApp, getApp, getApps } from "firebase/app";
import { getAuth, type Auth } from "firebase/auth";
import { getStorage, type FirebaseStorage } from "firebase/storage";
import {
  enableIndexedDbPersistence,
  getFirestore,
  type Firestore,
} from "firebase/firestore";

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || "sar-kyat.firebaseapp.com",
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

const hasFirebaseConfig = Object.values(firebaseConfig).every((v) => !!v);

if (typeof window !== "undefined") {
  console.log("Firebase Config Status:", hasFirebaseConfig);
  if (!hasFirebaseConfig) {
    console.warn("Firebase configuration is incomplete. Check environment variables.");
  }
}

export const isFirebaseConfigured = hasFirebaseConfig;

export const firebaseApp = hasFirebaseConfig
  ? getApps().length
    ? getApp()
    : initializeApp(firebaseConfig)
  : null;

let _auth: Auth | null = null;
let _db: Firestore | null = null;
let _storage: FirebaseStorage | null = null;
let didEnablePersistence = false;

export function getFirebaseAuth(): Auth {
  if (!firebaseApp) {
    throw new Error(
      "Firebase is not configured. Set NEXT_PUBLIC_FIREBASE_* environment variables."
    );
  }
  if (!_auth) {
    _auth = getAuth(firebaseApp);
  }
  return _auth;
}

export function getFirebaseStorage(): FirebaseStorage {
  if (!firebaseApp) {
    throw new Error(
      "Firebase is not configured. Set NEXT_PUBLIC_FIREBASE_* environment variables."
    );
  }
  if (!_storage) {
    _storage = getStorage(firebaseApp);
  }
  return _storage;
}

export function getFirebaseDb(): Firestore {
  if (!firebaseApp) {
    throw new Error(
      "Firebase is not configured. Set NEXT_PUBLIC_FIREBASE_* environment variables."
    );
  }
  if (!_db) {
    _db = getFirestore(firebaseApp);
  }

  /* 
  if (!didEnablePersistence && typeof window !== "undefined") {
    didEnablePersistence = true;
    enableIndexedDbPersistence(_db).catch(() => {});
  }
  */

  return _db;
}
