"use client";

import { motion } from "framer-motion";
import { useRouter } from "next/navigation";

export default function AiPlusPage() {
  const router = useRouter();

  return (
    <div className="min-h-screen bg-[#0A0B0F] text-white flex flex-col items-center justify-center p-6 text-center">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="space-y-6"
      >
        <div className="text-[42px] font-black bg-gradient-to-r from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF] bg-clip-text text-transparent">
          AI+ Vocabs
        </div>
        <p className="text-white/40 font-bold uppercase tracking-widest text-[14px]">
          Coming Soon
        </p>
        <motion.button
          whileTap={{ scale: 0.95 }}
          onClick={() => router.push("/home")}
          className="px-8 py-3 rounded-2xl bg-white/5 border border-white/10 text-white/60 font-bold hover:bg-white/10 transition-colors"
        >
          Go Back
        </motion.button>
      </motion.div>
    </div>
  );
}
