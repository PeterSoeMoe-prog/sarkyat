"use client";

import { useEffect } from "react";

const STORAGE_KEY = "sar-kyat-theme";

export type Theme = "light" | "dark";

function applyTheme(theme: Theme) {
  const root = document.documentElement;
  if (theme === "dark") {
    root.classList.add("dark");
  } else {
    root.classList.remove("dark");
  }
}

export function ThemeBootstrap() {
  useEffect(() => {
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch {
      // ignore
    }

    const mql = window.matchMedia?.("(prefers-color-scheme: dark)");
    const prefersDark = !!mql?.matches;
    applyTheme(prefersDark ? "dark" : "light");

    const onChange = (ev: MediaQueryListEvent) => applyTheme(ev.matches ? "dark" : "light");

    mql?.addEventListener?.("change", onChange);
    return () => mql?.removeEventListener?.("change", onChange);
  }, []);

  return null;
}

export function setTheme(theme: Theme) {
  if (typeof window === "undefined") return;
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch {
    // ignore
  }

  const mql = window.matchMedia?.("(prefers-color-scheme: dark)");
  applyTheme(mql?.matches ? "dark" : "light");
}

export function getTheme(): Theme {
  if (typeof window === "undefined") return "light";
  try {
    return document.documentElement.classList.contains("dark") ? "dark" : "light";
  } catch {
    return "light";
  }
}
