"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import { Mail, Github, Chrome, LogIn, UserCircle, ArrowRight } from "lucide-react";
import { signInWithGoogle, signInAnonymouslyUser } from "@/lib/firebase/auth";
import { useRouter } from "next/navigation";

export default function AuthScreen() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [isEmailView, setIsEmailView] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleGoogleSignIn = async () => {
    console.log("handleGoogleSignIn clicked");
    setLoading(true);
    try {
      console.log("Calling signInWithGoogle utility...");
      await signInWithGoogle();
      console.log("signInWithGoogle utility completed successfully, redirecting...");
      router.push("/home");
    } catch (error: any) {
      console.error("handleGoogleSignIn error caught in component:", error);
      alert(`Sign in failed: ${error.code || error.message || "Unknown error"}`);
    } finally {
      setLoading(false);
    }
  };

  const handleAnonymousSignIn = async () => {
    console.log("handleAnonymousSignIn clicked");
    setLoading(true);
    try {
      console.log("Calling signInAnonymouslyUser utility...");
      await signInAnonymouslyUser();
      console.log("signInAnonymouslyUser utility completed successfully, redirecting...");
      router.push("/home");
    } catch (error: any) {
      console.error("handleAnonymousSignIn error caught in component:", error);
      alert(`Guest access failed: ${error.code || error.message || "Unknown error"}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-[#0A0B0F] p-4 overflow-hidden">
      {/* Background Gradients */}
      <div 
        className="absolute inset-0 pointer-events-none"
        style={{
          background: "radial-gradient(circle at 50% 10%, rgba(255, 83, 145, 0.15), transparent 40%), radial-gradient(circle at 80% 80%, rgba(73, 210, 255, 0.1), transparent 50%)"
        }}
      />
      
      <motion.div 
        initial={{ opacity: 0, y: 20, scale: 0.95 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
        className="relative w-full max-w-md"
      >
        <div className="rounded-[2.5rem] border border-white/10 bg-white/5 p-8 backdrop-blur-2xl shadow-[0_40px_100px_rgba(0,0,0,0.5)]">
          {/* Header */}
          <div className="mb-10 text-center">
            <motion.div 
              initial={{ scale: 0.8, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={{ delay: 0.2 }}
              className="mx-auto mb-6 flex h-20 w-20 items-center justify-center rounded-3xl bg-gradient-to-br from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF] p-[2px] shadow-lg shadow-purple-500/20"
            >
              <div className="flex h-full w-full items-center justify-center rounded-[calc(1.5rem-2px)] bg-[#12141A]">
                <LogIn className="h-10 w-10 text-white" />
              </div>
            </motion.div>
            <h1 className="text-3xl font-bold tracking-tight text-white mb-2">Thai Vocab Trainer</h1>
            <p className="text-white/40 font-medium">Elevate your language journey</p>
          </div>

          <div className="space-y-4">
            {!isEmailView ? (
              <>
                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={handleGoogleSignIn}
                  disabled={loading}
                  className="flex w-full items-center justify-center gap-3 rounded-2xl bg-white px-6 py-4 text-[17px] font-bold text-black transition-all hover:bg-white/90 disabled:opacity-50 shadow-xl shadow-white/5"
                >
                  <Chrome className="h-5 w-5" />
                  Continue with Google
                </motion.button>

                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={() => setIsEmailView(true)}
                  disabled={loading}
                  className="flex w-full items-center justify-center gap-3 rounded-2xl border border-white/10 bg-white/5 px-6 py-4 text-[17px] font-bold text-white transition-all hover:bg-white/10 disabled:opacity-50"
                >
                  <Mail className="h-5 w-5 text-white/70" />
                  Sign in with Email
                </motion.button>

                <div className="relative my-8 flex items-center gap-4">
                  <div className="h-[1px] flex-1 bg-white/10" />
                  <span className="text-[13px] font-bold uppercase tracking-widest text-white/20">or</span>
                  <div className="h-[1px] flex-1 bg-white/10" />
                </div>

                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={handleAnonymousSignIn}
                  disabled={loading}
                  className="flex w-full items-center justify-center gap-3 rounded-2xl border border-white/5 bg-white/5 px-6 py-4 text-[17px] font-bold text-white/70 transition-all hover:bg-white/10 hover:text-white disabled:opacity-50"
                >
                  <UserCircle className="h-5 w-5" />
                  Try as Guest
                </motion.button>
              </>
            ) : (
              <motion.div 
                initial={{ opacity: 0, x: 20 }}
                animate={{ opacity: 1, x: 0 }}
                className="space-y-4"
              >
                <div className="space-y-2">
                  <label className="text-[13px] font-bold uppercase tracking-widest text-white/30 ml-2">Email Address</label>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="name@example.com"
                    className="w-full rounded-2xl border border-white/10 bg-white/5 px-6 py-4 text-white outline-none ring-offset-0 transition-all focus:border-[#B36BFF]/50 focus:bg-white/10"
                  />
                </div>
                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  className="flex w-full items-center justify-center gap-3 rounded-2xl bg-gradient-to-r from-[#FF4D6D] to-[#B36BFF] px-6 py-4 text-[17px] font-bold text-white shadow-xl shadow-pink-500/20 transition-all"
                >
                  Continue
                  <ArrowRight className="h-5 w-5" />
                </motion.button>
                <button
                  onClick={() => setIsEmailView(false)}
                  className="w-full text-center text-[14px] font-semibold text-white/30 hover:text-white/60 transition-colors pt-2"
                >
                  Back to options
                </button>
              </motion.div>
            )}
          </div>

          <p className="mt-10 text-center text-[13px] font-medium text-white/20 px-4">
            By continuing, you agree to our Terms of Service and Privacy Policy.
          </p>
        </div>
      </motion.div>
    </div>
  );
}
