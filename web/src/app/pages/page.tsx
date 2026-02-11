"use client";

import { motion, AnimatePresence } from "framer-motion";
import { useRouter } from "next/navigation";
import { useState, useEffect } from "react";
import { 
  LucideChevronLeft, 
  LucideBookOpen, 
  LucideLayout, 
  LucideSettings, 
  LucideZap,
  LucidePlus,
  LucideX,
  LucideBook,
  LucideTrash2
} from "lucide-react";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { saveBook, listenBooks, deleteBook } from "@/lib/vocab/firestore";
import { BookEntry } from "@/lib/vocab/types";

export default function PagesIndex() {
  const router = useRouter();
  const { uid } = useVocabulary();
  const [books, setBooks] = useState<BookEntry[]>([]);
  const [showAddModal, setShowAddModal] = useState(false);
  const [newBookName, setNewBookName] = useState("");
  const [newBookWriter, setNewBookWriter] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!uid) return;
    const unsub = listenBooks(uid, (data) => {
      setBooks(data);
      setLoading(false);
    });
    return () => unsub();
  }, [uid]);

  const handleAddBook = async () => {
    if (!uid || !newBookName.trim()) return;
    
    try {
      const bookId = Date.now().toString();
      await saveBook(uid, {
        id: bookId,
        name: newBookName.trim(),
        writer: newBookWriter.trim(),
      });
      
      console.log("Book created successfully:", bookId);
      setShowAddModal(false);
      setNewBookName("");
      setNewBookWriter("");
    } catch (err) {
      console.error("Error creating book:", err);
      alert("Failed to create book. Please try again.");
    }
  };

  const handleDeleteBook = async (e: React.MouseEvent, bookId: string) => {
    e.stopPropagation();
    if (!uid) return;
    if (confirm("Are you sure you want to delete this book?")) {
      await deleteBook(uid, bookId);
    }
  };

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
          <button onClick={() => setShowAddModal(true)} className="h-10 w-10 flex items-center justify-center rounded-full bg-white/5 active:scale-95 transition-all">
            <LucidePlus size={20} />
          </button>
        </div>
      </header>

      <main className="p-4 space-y-4 max-w-md mx-auto pb-32">
        {loading ? (
          <div className="py-20 text-center">
            <p className="text-white/20 font-bold text-[14px] animate-pulse">Loading books...</p>
          </div>
        ) : books.length === 0 ? (
          <div className="py-20 text-center space-y-4">
            <div className="h-16 w-16 bg-white/5 rounded-full flex items-center justify-center mx-auto mb-4">
              <LucideBook size={32} className="text-white/10" />
            </div>
            <p className="text-white/20 font-bold max-w-[200px] mx-auto text-[14px]">
              No books added yet. Tap + to create your first book.
            </p>
          </div>
        ) : (
          <div className="grid gap-3">
            {books.map((book) => (
              <motion.button
                key={book.id}
                layout
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                className="group relative bg-[#1A1B23] border border-white/5 rounded-2xl p-4 active:scale-[0.98] transition-all hover:border-white/10 cursor-pointer"
                type="button"
                onClick={() => router.push(`/pages/detail/?id=${encodeURIComponent(book.id)}`)}
              >
                <div className="flex items-center gap-4">
                  <div className="h-12 w-12 rounded-xl bg-gradient-to-br from-[#60A5FA]/20 to-[#B36BFF]/20 flex items-center justify-center border border-white/5">
                    <LucideBook size={24} className="text-[#60A5FA]" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <h3 className="text-[16px] font-bold text-white truncate">{book.name}</h3>
                    <p className="text-[13px] font-medium text-white/40 truncate">{book.writer || "Unknown Writer"}</p>
                  </div>
                  <button
                    onClick={(e) => handleDeleteBook(e, book.id)}
                    className="h-10 w-10 flex items-center justify-center rounded-xl bg-red-500/10 text-red-400 opacity-0 group-hover:opacity-100 transition-opacity active:scale-90"
                  >
                    <LucideTrash2 size={18} />
                  </button>
                </div>
              </motion.button>
            ))}
          </div>
        )}
      </main>

      {/* Add New Book Modal */}
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
              >
                <LucideX size={20} className="text-white/40" />
              </button>

              <h2 className="text-[24px] font-black text-white mb-6 tracking-tight">New Book</h2>
              
              <div className="space-y-4">
                <div className="space-y-1.5">
                  <label className="text-[11px] font-bold uppercase text-white/40 ml-1">Book Name</label>
                  <input 
                    autoFocus
                    value={newBookName}
                    onChange={(e) => setNewBookName(e.target.value)}
                    placeholder="Enter book title"
                    className="w-full rounded-2xl bg-white/5 border border-white/10 px-5 py-4 text-[16px] outline-none focus:border-white/20 transition-colors"
                  />
                </div>

                <div className="space-y-1.5">
                  <label className="text-[11px] font-bold uppercase text-white/40 ml-1">Writer</label>
                  <input 
                    value={newBookWriter}
                    onChange={(e) => setNewBookWriter(e.target.value)}
                    placeholder="Enter writer name"
                    className="w-full rounded-2xl bg-white/5 border border-white/10 px-5 py-4 text-[16px] outline-none focus:border-white/20 transition-colors"
                  />
                </div>

                <button 
                  onClick={handleAddBook}
                  disabled={!newBookName.trim()}
                  className="w-full mt-4 py-4 rounded-2xl bg-gradient-to-r from-[#60A5FA] to-[#B36BFF] text-white font-black text-[16px] active:scale-[0.98] transition-all disabled:opacity-50"
                >
                  Create Book
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
