"use client";

import AuthScreen from "@/components/AuthScreen";
import { isFirebaseConfigured } from "@/lib/firebase/client";
import { useState } from "react";
import { AlertCircle, Eye } from "lucide-react";

export default function AuthPage() {
  const [showMock, setShowMock] = useState(false);

  if (!isFirebaseConfigured && !showMock) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0A0B0F] p-4 text-center">
        <div className="w-full max-w-md rounded-[2.5rem] border border-white/10 bg-white/5 p-10 backdrop-blur-2xl shadow-[0_40px_100px_rgba(0,0,0,0.5)]">
          <div className="mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded-2xl bg-amber-500/10 text-amber-500">
            <AlertCircle className="h-8 w-8" />
          </div>
          <h1 className="text-2xl font-bold text-white mb-3">Configuration Required</h1>
          <p className="text-white/40 mb-8 leading-relaxed">
            Firebase environment variables are missing. Please add <code className="text-amber-500/80 bg-white/5 px-1.5 py-0.5 rounded">NEXT_PUBLIC_FIREBASE_*</code> keys to your deployment dashboard.
          </p>
          <button
            onClick={() => setShowMock(true)}
            className="flex w-full items-center justify-center gap-2 rounded-2xl bg-white/10 px-6 py-4 text-[15px] font-bold text-white transition-all hover:bg-white/20"
          >
            <Eye className="h-5 w-5 opacity-70" />
            Preview Design (Mock Mode)
          </button>
        </div>
      </div>
    );
  }

  return <AuthScreen />;
}
