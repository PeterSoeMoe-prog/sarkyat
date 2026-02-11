"use client";

import { motion, AnimatePresence } from "framer-motion";
import { useRouter, useSearchParams } from "next/navigation";
import { useState, useEffect } from "react";
import {
  LucideChevronLeft,
  LucidePlus,
  LucideX,
  LucideLayers,
  LucideTrash2,
  LucidePencil,
  LucideFlame,
  LucideGem,
} from "lucide-react";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { saveSession, listenSessions, deleteSession, fetchBook, updateBook } from "@/lib/vocab/firestore";
import { BookEntry, BookSession, SessionStatus } from "@/lib/vocab/types";

export default function BookDetailClient() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const bookId = searchParams.get("id") ?? "";
  const { uid } = useVocabulary();

  const [book, setBook] = useState<BookEntry | null>(null);
  const [sessions, setSessions] = useState<BookSession[]>([]);
  const [showAddModal, setShowAddModal] = useState(false);
  const [newSessionName, setNewSessionName] = useState("");
  const [newSessionNote, setNewSessionNote] = useState("");
  const [newSessionStatus, setNewSessionStatus] = useState<SessionStatus>("drill");
  const [loading, setLoading] = useState(true);
  const [showEditModal, setShowEditModal] = useState(false);
  const [editBookName, setEditBookName] = useState("");
  const [editBookWriter, setEditBookWriter] = useState("");
  const isNewSessionReady = newSessionStatus === "ready";

  useEffect(() => {
    if (!uid || !bookId) return;

    fetchBook(uid, bookId).then((b) => {
      setBook(b);
      if (b) {
        setEditBookName(b.name ?? "");
        setEditBookWriter(b.writer ?? "");
      }
    });

    const unsub = listenSessions(uid, bookId, (data) => {
      setSessions(data);
      setLoading(false);
    });

    return () => unsub();
  }, [uid, bookId]);

  const handleAddSession = async () => {
    if (!uid || !bookId || !newSessionName.trim()) return;

    try {
      const sessionId = Date.now().toString();
      await saveSession(uid, bookId, {
        id: sessionId,
        bookId,
        name: newSessionName.trim(),
        note: newSessionNote.trim().slice(0, 1000),
        order: sessions.length + 1,
        status: newSessionStatus,
      });

      setShowAddModal(false);
      setNewSessionName("");
      setNewSessionNote("");
      setNewSessionStatus("drill");
    } catch (err) {
      console.error("Error creating session:", err);
      alert("Failed to create session. Please try again.");
    }
  };

  const handleDeleteSession = async (e: React.MouseEvent, sessionId: string) => {
    e.stopPropagation();
    if (!uid || !bookId) return;
    if (confirm("Are you sure you want to delete this session?")) {
      await deleteSession(uid, bookId, sessionId);
    }
  };

  const handleSaveBook = async () => {
    if (!uid || !bookId) return;
    const name = editBookName.trim();
    const writer = editBookWriter.trim();
    if (!name) return;

    try {
      await updateBook(uid, bookId, { name, writer });
      setBook((prev) => (prev ? { ...prev, name, writer } : prev));
      setShowEditModal(false);
    } catch (err) {
      console.error("Error updating book:", err);
      alert("Failed to update book. Please try again.");
    }
  };

  if (!bookId) {
    return (
      <div className="min-h-screen bg-[#0A0B0F] text-white">
        <header className="px-4 pt-[calc(env(safe-area-inset-top)+10px)] pb-4 border-b border-white/5 bg-black/20 backdrop-blur-xl sticky top-0 z-50">
          <div className="max-w-md mx-auto flex items-center justify-between w-full">
            <button
              onClick={() => router.push("/pages/")}
              className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 active:scale-95 transition-all"
              type="button"
            >
              <LucideChevronLeft size={20} />
            </button>
            <div className="flex flex-col items-center flex-1 px-4 min-w-0">
              <h1 className="text-[16px] font-black tracking-tight truncate w-full text-center">Book Details</h1>
            </div>
            <div className="h-10 w-10" />
          </div>
        </header>

        <main className="p-4 max-w-md mx-auto pb-32">
          <div className="py-20 text-center">
            <p className="text-white/20 font-bold text-[14px]">Missing book id.</p>
          </div>
        </main>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0A0B0F] text-white">
      <header className="px-4 pt-[calc(env(safe-area-inset-top)+10px)] pb-4 border-b border-white/5 bg-black/20 backdrop-blur-xl sticky top-0 z-50">
        <div className="max-w-md mx-auto flex items-center justify-between w-full">
          <button
            onClick={() => router.push("/pages/")}
            className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 active:scale-95 transition-all"
            type="button"
          >
            <LucideChevronLeft size={20} />
          </button>
          <div className="flex flex-col items-center flex-1 px-4 min-w-0">
            <h1 className="text-[16px] font-black tracking-tight truncate w-full text-center">
              {book?.name || "Book Details"}
            </h1>
            {book?.writer && (
              <p className="text-[11px] font-bold text-white/40 truncate w-full text-center">{book.writer}</p>
            )}
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setShowEditModal(true)}
              className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 active:scale-95 transition-all"
              type="button"
              aria-label="Edit book"
            >
              <LucidePencil size={18} />
            </button>
            <button
              onClick={() => setShowAddModal(true)}
              className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 active:scale-95 transition-all"
              type="button"
            >
              <LucidePlus size={20} />
            </button>
          </div>
        </div>
      </header>

      <main className="p-4 space-y-4 max-w-md mx-auto pb-32">
        <div className="flex items-center justify-between px-2">
          <h2 className="text-[14px] font-black uppercase tracking-widest text-white/40">Sessions</h2>
          <span className="px-2 py-0.5 rounded-full bg-white/5 text-[10px] font-bold text-white/40 border border-white/5">
            {sessions.length} TOTAL
          </span>
        </div>

        {loading ? (
          <div className="py-20 text-center">
            <p className="text-white/20 font-bold text-[14px] animate-pulse">Loading sessions...</p>
          </div>
        ) : sessions.length === 0 ? (
          <div className="py-20 text-center space-y-4">
            <div className="h-16 w-16 bg-white/5 rounded-full flex items-center justify-center mx-auto mb-4">
              <LucideLayers size={32} className="text-white/10" />
            </div>
            <p className="text-white/20 font-bold max-w-[200px] mx-auto text-[14px]">
              No sessions added yet. Tap + to create your first session.
            </p>
          </div>
        ) : (
          <div className="grid gap-3">
            {sessions.map((session) => (
              <motion.div
                key={session.id}
                layout
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                className="group relative bg-[#1A1B23] border border-white/5 rounded-2xl p-4 active:scale-[0.98] transition-all hover:border-white/10"
                onClick={() =>
                  router.push(
                    `/pages/detail/session/?bookId=${encodeURIComponent(bookId)}&sessionId=${encodeURIComponent(session.id)}`
                  )
                }
              >
                <div className="flex items-center gap-4">
                  <div className="h-12 w-12 rounded-xl bg-gradient-to-br from-[#10B981]/20 to-[#3B82F6]/20 flex items-center justify-center border border-white/5">
                    <LucideLayers size={24} className="text-[#10B981]" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <h3 className="text-[16px] font-bold text-white truncate">{session.name}</h3>
                    {session.note && (
                      <p className="text-[12px] text-white/50 mt-1 line-clamp-2 break-words">
                        {session.note}
                      </p>
                    )}
                  </div>
                  <div className="flex items-center gap-1.5 rounded-xl bg-white/5 border border-white/10 px-2.5 py-1">
                    {session.status === "ready" ? (
                      <LucideGem size={14} className="text-[#34D399]" />
                    ) : (
                      <LucideFlame size={14} className="text-[#F59E0B]" />
                    )}
                    <span className="text-[11px] font-black uppercase tracking-wide text-white/65">
                      {session.status === "ready" ? "ready" : "drill"}
                    </span>
                  </div>
                  <button
                    onClick={(e) => handleDeleteSession(e, session.id)}
                    className="h-10 w-10 flex items-center justify-center rounded-xl bg-red-500/10 text-red-400 opacity-0 group-hover:opacity-100 transition-opacity active:scale-90"
                    type="button"
                  >
                    <LucideTrash2 size={18} />
                  </button>
                </div>
              </motion.div>
            ))}
          </div>
        )}
      </main>

      <AnimatePresence>
        {showEditModal && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60 backdrop-blur-sm p-6"
          >
            <motion.div
              initial={{ scale: 0.9, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.9, opacity: 0, y: 20 }}
              className="relative w-full max-w-sm bg-[#1A1B23] rounded-[32px] border border-white/10 p-8 flex flex-col shadow-[0_20px_50px_rgba(0,0,0,0.5)]"
            >
              <button
                onClick={() => setShowEditModal(false)}
                className="absolute top-6 right-6 h-10 w-10 flex items-center justify-center rounded-full bg-white/5 hover:bg-white/10 transition-all active:scale-90"
                type="button"
              >
                <LucideX size={20} className="text-white/40" />
              </button>

              <h2 className="text-[24px] font-black text-white mb-6 tracking-tight">Edit Book</h2>

              <div className="space-y-4">
                <div className="space-y-1.5">
                  <label className="text-[11px] font-bold uppercase text-white/40 ml-1">Book Name</label>
                  <input
                    value={editBookName}
                    onChange={(e) => setEditBookName(e.target.value)}
                    placeholder="Enter book title"
                    className="w-full rounded-2xl bg-white/5 border border-white/10 px-5 py-4 text-[16px] outline-none focus:border-white/20 transition-colors"
                  />
                </div>

                <div className="space-y-1.5">
                  <label className="text-[11px] font-bold uppercase text-white/40 ml-1">Writer</label>
                  <input
                    value={editBookWriter}
                    onChange={(e) => setEditBookWriter(e.target.value)}
                    placeholder="Enter writer name"
                    className="w-full rounded-2xl bg-white/5 border border-white/10 px-5 py-4 text-[16px] outline-none focus:border-white/20 transition-colors"
                  />
                </div>

                <button
                  onClick={handleSaveBook}
                  disabled={!editBookName.trim()}
                  className="w-full mt-4 py-4 rounded-2xl bg-gradient-to-r from-[#60A5FA] to-[#B36BFF] text-white font-black text-[16px] active:scale-[0.98] transition-all disabled:opacity-50"
                  type="button"
                >
                  Save Changes
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      <AnimatePresence>
        {showAddModal && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60 backdrop-blur-sm p-6"
          >
            <motion.div
              initial={{ scale: 0.9, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.9, opacity: 0, y: 20 }}
              className="relative w-full max-w-sm bg-[#1A1B23] rounded-[32px] border border-white/10 p-8 flex flex-col shadow-[0_20px_50px_rgba(0,0,0,0.5)]"
            >
              <button
                onClick={() => setShowAddModal(false)}
                className="absolute top-6 right-6 h-10 w-10 flex items-center justify-center rounded-full bg-white/5 hover:bg-white/10 transition-all active:scale-90"
                type="button"
              >
                <LucideX size={20} className="text-white/40" />
              </button>

              <h2 className="text-[24px] font-black text-white mb-6 tracking-tight">New Session</h2>

              <div className="space-y-4">
                <div className="space-y-1.5">
                  <label className="text-[11px] font-bold uppercase text-white/40 ml-1">Session Name</label>
                  <input
                    autoFocus
                    value={newSessionName}
                    onChange={(e) => setNewSessionName(e.target.value)}
                    placeholder="e.g. Lesson 1: Basic Greetings"
                    className="w-full rounded-2xl bg-white/5 border border-white/10 px-5 py-4 text-[16px] outline-none focus:border-white/20 transition-colors"
                    onKeyDown={(e) => e.key === "Enter" && handleAddSession()}
                  />
                </div>

                <div className="space-y-1.5">
                  <label className="text-[11px] font-bold uppercase text-white/40 ml-1">Status</label>
                  <button
                    type="button"
                    onClick={() => setNewSessionStatus((prev) => (prev === "ready" ? "drill" : "ready"))}
                    className={`h-11 w-11 flex items-center justify-center rounded-xl border transition-all active:scale-95 ${
                      isNewSessionReady
                        ? "bg-[#10B981]/20 border-[#10B981]/35 text-[#34D399]"
                        : "bg-[#F59E0B]/20 border-[#F59E0B]/35 text-[#FCD34D]"
                    }`}
                    aria-label={`Toggle status. Current: ${isNewSessionReady ? "ready" : "drill"}`}
                    title={`Tap to change status (${isNewSessionReady ? "ready" : "drill"})`}
                  >
                    {isNewSessionReady ? <LucideGem size={16} /> : <LucideFlame size={16} />}
                  </button>
                </div>

                <div className="space-y-1.5">
                  <label className="text-[11px] font-bold uppercase text-white/40 ml-1 flex items-center justify-between">
                    <span>Notes (optional)</span>
                    <span className="text-white/30 text-[10px] font-bold">
                      {newSessionNote.length}/1000
                    </span>
                  </label>
                  <textarea
                    value={newSessionNote}
                    onChange={(e) => setNewSessionNote(e.target.value.slice(0, 1000))}
                    placeholder="Add up to 1000 characters about this session"
                    className="w-full min-h-[110px] rounded-2xl bg-white/5 border border-white/10 px-5 py-4 text-[15px] outline-none focus:border-white/20 transition-colors resize-none"
                  />
                </div>

                <button
                  onClick={handleAddSession}
                  disabled={!newSessionName.trim()}
                  className="w-full mt-4 py-4 rounded-2xl bg-gradient-to-r from-[#10B981] to-[#3B82F6] text-white font-black text-[16px] active:scale-[0.98] transition-all disabled:opacity-50"
                  type="button"
                >
                  Create Session
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
