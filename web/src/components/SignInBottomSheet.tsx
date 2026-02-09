"use client";

import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { 
  getAuth, 
  signInWithEmailAndPassword, 
  createUserWithEmailAndPassword,
  updateProfile,
  signInAnonymously
} from "firebase/auth";
import { getFirebaseDb } from "@/lib/firebase/client";
import { doc, setDoc, serverTimestamp } from "firebase/firestore";

interface SignInBottomSheetProps {
  onClose: () => void;
}

export function SignInBottomSheet({ onClose }: SignInBottomSheetProps) {
  const [mode, setLoginMode] = useState<"login" | "register">("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const auth = getAuth();
      if (mode === "login") {
        await signInWithEmailAndPassword(auth, email, password);
      } else {
        const userCredential = await createUserWithEmailAndPassword(auth, email, password);
        await updateProfile(userCredential.user, { displayName: name });
        
        // Initialize user doc
        const db = getFirebaseDb();
        await setDoc(doc(db, "users", userCredential.user.uid), {
          email,
          displayName: name,
          createdAt: serverTimestamp(),
        }, { merge: true });
      }
      onClose();
    } catch (err: any) {
      console.error("Auth error:", err);
      setError(err.message || "Authentication failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-end justify-center sm:items-center p-0 sm:p-4">
      {/* Backdrop */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        onClick={onClose}
        className="absolute inset-0 bg-black/60 backdrop-blur-sm"
      />

      {/* Sheet */}
      <motion.div
        initial={{ y: "100%" }}
        animate={{ y: 0 }}
        exit={{ y: "100%" }}
        transition={{ type: "spring", damping: 25, stiffness: 200 }}
        className="relative w-full max-w-md bg-[#1A1B23] border-t sm:border border-white/10 rounded-t-[32px] sm:rounded-[32px] shadow-[0_-20px_80px_rgba(0,0,0,0.5)] overflow-hidden"
      >
        <div className="p-8">
          <div className="flex justify-between items-center mb-8">
            <h2 className="text-2xl font-black text-white">
              {mode === "login" ? "Welcome Back" : "Create Account"}
            </h2>
            <button 
              onClick={onClose}
              className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 hover:bg-white/10 transition-colors"
            >
              <span className="text-[20px] text-white/40">✕</span>
            </button>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            {mode === "register" && (
              <div className="space-y-1.5">
                <label className="text-[10px] font-black text-white/20 uppercase tracking-widest px-1">Display Name</label>
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Your Name"
                  className="w-full bg-black/20 rounded-xl px-4 py-3 text-[15px] font-medium text-white/80 border border-white/5 focus:outline-none focus:ring-1 focus:ring-[#B36BFF]/30 transition-all placeholder:text-white/10"
                />
              </div>
            )}

            <div className="space-y-1.5">
              <label className="text-[10px] font-black text-white/20 uppercase tracking-widest px-1">Email</label>
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
                className="w-full bg-black/20 rounded-xl px-4 py-3 text-[15px] font-medium text-white/80 border border-white/5 focus:outline-none focus:ring-1 focus:ring-[#B36BFF]/30 transition-all placeholder:text-white/10"
              />
            </div>

            <div className="space-y-1.5">
              <label className="text-[10px] font-black text-white/20 uppercase tracking-widest px-1">Password</label>
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full bg-black/20 rounded-xl px-4 py-3 text-[15px] font-medium text-white/80 border border-white/5 focus:outline-none focus:ring-1 focus:ring-[#B36BFF]/30 transition-all placeholder:text-white/10"
              />
            </div>

            {error && (
              <p className="text-red-400 text-xs px-1 font-medium">{error}</p>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full py-4 mt-4 rounded-2xl bg-gradient-to-r from-[#B36BFF] to-[#49D2FF] text-white font-black text-[16px] shadow-lg shadow-[#B36BFF]/20 active:scale-[0.98] transition-all disabled:opacity-50"
            >
              {loading ? "Processing..." : mode === "login" ? "Sign In" : "Sign Up"}
            </button>
          </form>

          <div className="mt-6 text-center">
            <button
              onClick={() => setLoginMode(mode === "login" ? "register" : "login")}
              className="text-[13px] font-bold text-white/40 hover:text-white/60 transition-colors"
            >
              {mode === "login" ? "New here? Create an account" : "Already have an account? Sign in"}
            </button>
          </div>
        </div>
      </motion.div>
    </div>
  );
}
