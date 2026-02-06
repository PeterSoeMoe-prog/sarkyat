"use client";

import Home from "@/app/page";

export default function CategoryPage() {
  return (
    <div className="min-h-screen bg-[#0A0B0F] text-white">
      <div
        className="min-h-screen"
        style={{
          background:
            "radial-gradient(1200px 800px at 50% 10%, rgba(255,255,255,0.08), rgba(0,0,0,0) 55%), radial-gradient(900px 600px at 50% 60%, rgba(255,83,145,0.09), rgba(0,0,0,0) 60%), #0A0B0F",
        }}
      >
        <div className="mx-auto w-full max-w-md px-4 pt-[calc(env(safe-area-inset-top)+20px)] pb-[calc(env(safe-area-inset-bottom)+118px)]">
          <Home />
        </div>
      </div>
    </div>
  );
}
