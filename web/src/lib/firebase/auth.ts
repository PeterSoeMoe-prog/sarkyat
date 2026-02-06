"use client";

import { GoogleAuthProvider, signInWithPopup, signInAnonymously } from "firebase/auth";
import { getFirebaseAuth } from "./client";

export async function signInWithGoogle() {
  console.log("Starting signInWithGoogle process...");
  try {
    const auth = getFirebaseAuth();
    const provider = new GoogleAuthProvider();
    provider.setCustomParameters({ prompt: 'select_account' });
    console.log("Calling signInWithPopup...");
    const result = await signInWithPopup(auth, provider);
    console.log("Sign-in successful, result:", result.user.email);
    return result;
  } catch (error: any) {
    console.error("Firebase Auth Error Code:", error.code);
    console.error("Firebase Auth Error Message:", error.message);
    throw error;
  }
}

export async function signInAnonymouslyUser() {
  console.log("Starting signInAnonymouslyUser process...");
  try {
    const auth = getFirebaseAuth();
    const result = await signInAnonymously(auth);
    console.log("Anonymous sign-in successful, uid:", result.user.uid);
    return result;
  } catch (error: any) {
    console.error("Anonymous Sign-in Error:", error);
    throw error;
  }
}
