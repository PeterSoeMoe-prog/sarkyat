"use client";

import React, { Component, ErrorInfo, ReactNode } from "react";

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export default class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
    error: null,
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error("Uncaught error:", error, errorInfo);
  }

  public render() {
    if (this.state.hasError) {
      return (
        <div className="flex min-h-screen flex-col items-center justify-center bg-[#0A0B0F] p-6 text-center">
          <div className="w-full max-w-md rounded-[2.5rem] border border-white/10 bg-white/5 p-10 backdrop-blur-2xl shadow-[0_40px_100px_rgba(0,0,0,0.5)]">
            <div className="mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded-2xl bg-red-500/10 text-red-500 text-[32px]">
              ⚠️
            </div>
            <h1 className="text-2xl font-bold text-white mb-3">Application Error</h1>
            <div className="mb-8 text-left">
              <p className="text-white/40 text-sm mb-2 uppercase tracking-widest font-bold">Error Details:</p>
              <pre className="overflow-auto rounded-xl bg-black/40 p-4 text-xs font-mono text-red-400 border border-red-500/20 whitespace-pre-wrap break-all">
                {this.state.error?.message || "Unknown error"}
              </pre>
            </div>
            <button
              onClick={() => window.location.reload()}
              className="w-full rounded-2xl bg-white/10 px-6 py-4 text-[15px] font-bold text-white transition-all hover:bg-white/20"
            >
              Reload Page
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
