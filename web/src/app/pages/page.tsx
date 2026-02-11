"use client";

import { motion } from "framer-motion";
import { useRouter } from "next/navigation";
import { 
  LucideChevronLeft, 
  LucideBookOpen, 
  LucideLayout, 
  LucideSettings, 
  LucideZap
} from "lucide-react";

export default function PagesIndex() {
  const router = useRouter();

  return (
    <div className="min-h-screen bg-[#0A0B0F] text-white">
      {/* Header */}
      <header className="px-4 pt-[calc(env(safe-area-inset-top)+10px)] pb-4 border-b border-white/5 bg-black/20 backdrop-blur-xl sticky top-0 z-50">
        <div className="max-w-md mx-auto flex items-center justify-between w-full">
          <button onClick={() => router.push("/home")} className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 active:scale-95 transition-all">
            <LucideChevronLeft size={20} />
          </button>
          <div className="flex items-center gap-2">
            <h1 className="text-[18px] font-black tracking-tight">Pages</h1>
          </div>
          <div className="w-10" />
        </div>
      </header>

      <main className="p-4 space-y-6 max-w-md mx-auto pb-32">
        <div className="py-20 text-center space-y-4">
          <p className="text-white/20 font-bold max-w-[200px] mx-auto text-[14px]">
            New pages are under development
          </p>
        </div>
      </main>
    </div>
  );
}
