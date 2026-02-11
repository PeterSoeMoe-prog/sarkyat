"use client";

import { useEffect } from "react";

export function AntiZoom() {
  useEffect(() => {
    const handleTouchStart = (e: TouchEvent) => {
      if (e.touches.length > 1) {
        e.preventDefault();
      }
    };

    const handleGestureStart = (e: any) => {
      e.preventDefault();
    };

    // Prevent double tap zoom by checking time between touches
    let lastTouchEnd = 0;
    const handleTouchEnd = (e: TouchEvent) => {
      const now = Date.now();
      if (now - lastTouchEnd <= 300) {
        e.preventDefault();
      }
      lastTouchEnd = now;
    };

    document.addEventListener("touchstart", handleTouchStart, { passive: false });
    document.addEventListener("touchend", handleTouchEnd, false);
    document.addEventListener("gesturestart", handleGestureStart);

    return () => {
      document.removeEventListener("touchstart", handleTouchStart);
      document.removeEventListener("touchend", handleTouchEnd);
      document.removeEventListener("gesturestart", handleGestureStart);
    };
  }, []);

  return null;
}
