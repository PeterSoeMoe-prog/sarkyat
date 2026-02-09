"use client";

import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";

export function InstallPrompt() {
  const [deferredPrompt, setDeferredPrompt] = useState<any>(null);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const handler = (e: any) => {
      // Prevent the mini-infobar from appearing on mobile
      e.preventDefault();
      // Stash the event so it can be triggered later.
      setDeferredPrompt(e);
      // Show the custom install prompt
      setIsVisible(true);
    };

    window.addEventListener("beforeinstallprompt", handler);

    // Check if already installed
    if (window.matchMedia("(display-mode: standalone)").matches) {
      setIsVisible(false);
    }

    return () => {
      window.removeEventListener("beforeinstallprompt", handler);
    };
  }, []);

  const handleInstall = async () => {
    if (!deferredPrompt) return;

    // Show the native install prompt
    deferredPrompt.prompt();

    // Wait for the user to respond to the prompt
    const { outcome } = await deferredPrompt.userChoice;
    
    if (outcome === "accepted") {
      console.log("User accepted the install prompt");
    } else {
      console.log("User dismissed the install prompt");
    }

    // Clear the deferred prompt
    setDeferredPrompt(null);
    setIsVisible(false);
  };

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ opacity: 0, y: 50 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: 50 }}
          className="fixed bottom-24 left-4 right-4 z-[100] mx-auto max-w-md"
        >
          <div className="bg-[#1A1B23] border border-white/10 rounded-2xl p-4 shadow-2xl backdrop-blur-xl">
            <div className="flex items-center gap-4">
              <div className="h-12 w-12 rounded-xl bg-gradient-to-br from-[#FF4D6D] to-[#B36BFF] flex items-center justify-center text-2xl shadow-lg">
                ✨
              </div>
              <div className="flex-1">
                <h3 className="text-white font-bold text-[15px]">Install Sar Kyat Pro</h3>
                <p className="text-white/50 text-[12px]">Add to your home screen for a better experience and offline access.</p>
              </div>
              <div className="flex flex-col gap-2">
                <button
                  onClick={handleInstall}
                  className="px-4 py-2 bg-white text-black text-[12px] font-black rounded-lg hover:bg-white/90 transition-colors"
                >
                  Install
                </button>
                <button
                  onClick={() => setIsVisible(false)}
                  className="text-white/30 text-[10px] font-bold uppercase tracking-widest"
                >
                  Later
                </button>
              </div>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
