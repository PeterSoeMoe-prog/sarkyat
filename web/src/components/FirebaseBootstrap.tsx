"use client";

import { useEffect } from "react";
import {
  browserLocalPersistence,
  browserSessionPersistence,
  getRedirectResult,
  onAuthStateChanged,
  setPersistence,
  signOut,
  signInWithCredential,
  GoogleAuthProvider,
} from "firebase/auth";
import { getFirebaseAuth, isFirebaseConfigured } from "@/lib/firebase/client";

const REDIRECT_PENDING_KEY = "sar-kyat-auth-redirect-pending";
const REDIRECT_TS_KEY = "sar-kyat-auth-redirect-ts";
const REDIRECT_ERROR_KEY = "sar-kyat-auth-redirect-error";

export function FirebaseBootstrap() {
  useEffect(() => {
    if (!isFirebaseConfigured) return;
    const auth = getFirebaseAuth();

    let redirectHandled = false;

    (async () => {
      try {
        await setPersistence(auth, browserLocalPersistence);
      } catch {
        try {
          await setPersistence(auth, browserSessionPersistence);
        } catch {
          // ignore
        }
      }

      try {
        const res = await getRedirectResult(auth);

        if (typeof window !== "undefined") {
          if (res) {
            sessionStorage.removeItem(REDIRECT_PENDING_KEY);
            sessionStorage.removeItem(REDIRECT_TS_KEY);
            sessionStorage.removeItem(REDIRECT_ERROR_KEY);
          } else {
            const pending = sessionStorage.getItem(REDIRECT_PENDING_KEY) === "1";
            if (pending) {
              sessionStorage.removeItem(REDIRECT_PENDING_KEY);
              const ts = Number(sessionStorage.getItem(REDIRECT_TS_KEY) ?? "0");
              sessionStorage.removeItem(REDIRECT_TS_KEY);
              const ageSec = ts ? Math.round((Date.now() - ts) / 1000) : null;
              sessionStorage.setItem(
                REDIRECT_ERROR_KEY,
                `auth/no-redirect-result: Google returned no sign-in result${
                  ageSec != null ? ` after ${ageSec}s` : ""
                }. (Common causes: cookies blocked, unauthorized domain, provider disabled.)`
              );
            }
          }
        }
      } catch (e: unknown) {
        const err = e as { code?: string };
        const code = String(err?.code ?? "");

        if (typeof window !== "undefined") {
          sessionStorage.removeItem(REDIRECT_PENDING_KEY);
          sessionStorage.removeItem(REDIRECT_TS_KEY);
          const message = (e as { message?: string })?.message;
          sessionStorage.setItem(
            REDIRECT_ERROR_KEY,
            `${code || "auth/redirect-error"}: ${message || ""}`.trim()
          );
        }

        if (
          code.includes("credential-already-in-use") ||
          code.includes("email-already-in-use")
        ) {
          const credential = GoogleAuthProvider.credentialFromError(e as never);
          if (credential) {
            try {
              await signInWithCredential(auth, credential);
            } catch {
              // ignore
            }
          }
        }
      } finally {
        redirectHandled = true;
      }
    })();

    const unsub = onAuthStateChanged(auth, (user) => {
      if (!user) return;
      if (user.isAnonymous) {
        if (!redirectHandled) return;
        signOut(auth).catch(() => {});
      }
    });

    return () => unsub();
  }, []);

  return null;
}
