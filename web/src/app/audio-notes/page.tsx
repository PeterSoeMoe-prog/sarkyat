"use client";

import { motion, AnimatePresence } from "framer-motion";
import { useRouter } from "next/navigation";
import { useState, useRef, useEffect } from "react";
import { 
  LucideMic, 
  LucideMicOff, 
  LucideChevronLeft, 
  LucidePlay, 
  LucidePause, 
  LucideTrash2, 
  LucidePlus,
  LucideBrain,
  LucideCheck,
  LucideRotateCcw
} from "lucide-react";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { upsertVocabulary } from "@/lib/vocab/firestore";

interface TranscribedNote {
  id: string;
  thai: string;
  burmese: string;
  category: string;
  status: "pending" | "saving" | "saved";
}

export default function AudioNotesPage() {
  const router = useRouter();
  const { uid } = useVocabulary();
  
  const [isRecording, setIsRecording] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [notes, setNotes] = useState<TranscribedNote[]>([]);
  const [timer, setTimer] = useState(0);
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  // Web Speech API
  const recognitionRef = useRef<any>(null);

  useEffect(() => {
    if (typeof window !== 'undefined' && ('WebkitSpeechRecognition' in window || 'speechRecognition' in window)) {
      const SpeechRecognition = (window as any).WebkitSpeechRecognition || (window as any).speechRecognition;
      recognitionRef.current = new SpeechRecognition();
      recognitionRef.current.continuous = false;
      recognitionRef.current.interimResults = false;
      recognitionRef.current.lang = 'th-TH'; // Default to Thai for vocab

      recognitionRef.current.onresult = (event: any) => {
        const transcript = event.results[0][0].transcript;
        processTranscript(transcript);
      };

      recognitionRef.current.onend = () => {
        setIsRecording(false);
        stopTimer();
      };

      recognitionRef.current.onerror = (event: any) => {
        console.error("Speech recognition error", event.error);
        setIsRecording(false);
        stopTimer();
      };
    }

    return () => {
      if (recognitionRef.current) {
        recognitionRef.current.stop();
      }
    };
  }, []);

  const startTimer = () => {
    setTimer(0);
    timerRef.current = setInterval(() => {
      setTimer(prev => prev + 1);
    }, 1000);
  };

  const stopTimer = () => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
  };

  const toggleRecording = () => {
    if (isRecording) {
      recognitionRef.current?.stop();
    } else {
      setTimer(0);
      setIsRecording(true);
      startTimer();
      recognitionRef.current?.start();
    }
  };

  const processTranscript = async (transcript: string) => {
    setIsProcessing(true);
    // In a real implementation, we would send this to Gemini to parse into Thai/Burmese/Category
    // For now, we'll create a placeholder note
    const newNote: TranscribedNote = {
      id: crypto.randomUUID(),
      thai: transcript,
      burmese: "Processing...",
      category: "Audio",
      status: "pending"
    };
    
    setNotes(prev => [newNote, ...prev]);
    
    // Simulate AI processing
    setTimeout(() => {
      setNotes(prev => prev.map(n => n.id === newNote.id ? {
        ...n,
        burmese: "ဘာသာပြန်ဆိုချက် (Translation)",
        category: "General"
      } : n));
      setIsProcessing(false);
    }, 1500);
  };

  const handleSaveNote = async (note: TranscribedNote) => {
    if (!uid) return;
    
    setNotes(prev => prev.map(n => n.id === note.id ? { ...n, status: "saving" } : n));
    
    try {
      await upsertVocabulary(uid, {
        id: crypto.randomUUID(),
        thai: note.thai,
        burmese: note.burmese,
        category: note.category,
        count: 0,
        status: "queue",
        updatedAt: Date.now()
      });
      
      setNotes(prev => prev.map(n => n.id === note.id ? { ...n, status: "saved" } : n));
      setTimeout(() => {
        setNotes(prev => prev.filter(n => n.id !== note.id));
      }, 1000);
    } catch (err) {
      console.error("Save failed", err);
      setNotes(prev => prev.map(n => n.id === note.id ? { ...n, status: "pending" } : n));
    }
  };

  const handleDeleteNote = (id: string) => {
    setNotes(prev => prev.filter(n => n.id !== id));
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
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
            <div className="h-8 w-8 rounded-lg bg-gradient-to-br from-[#2CE08B] to-[#49D2FF] flex items-center justify-center shadow-lg shadow-[#2CE08B]/20">
              <LucideMic size={16} className="text-white" />
            </div>
            <h1 className="text-[18px] font-black tracking-tight">Audio Notes</h1>
          </div>
          <div className="w-10" />
        </div>
      </header>

      <main className="p-4 space-y-8 max-w-md mx-auto pb-48">
        {/* Record Section */}
        <div className="flex flex-col items-center justify-center space-y-6 pt-8">
          <div className="relative">
            <AnimatePresence>
              {isRecording && (
                <motion.div
                  initial={{ scale: 0.8, opacity: 0 }}
                  animate={{ scale: 1.5, opacity: [0, 0.2, 0] }}
                  exit={{ scale: 0.8, opacity: 0 }}
                  transition={{ duration: 1.5, repeat: Infinity, ease: "easeOut" }}
                  className="absolute inset-0 rounded-full bg-[#FF4D6D]"
                />
              )}
            </AnimatePresence>
            <button
              onClick={toggleRecording}
              className={`h-24 w-24 rounded-full flex items-center justify-center transition-all shadow-2xl relative z-10 ${
                isRecording 
                  ? "bg-[#FF4D6D] shadow-[#FF4D6D]/40 scale-110" 
                  : "bg-gradient-to-br from-[#2CE08B] to-[#49D2FF] shadow-[#2CE08B]/20"
              }`}
            >
              {isRecording ? <LucideMicOff size={40} /> : <LucideMic size={40} />}
            </button>
          </div>
          
          <div className="text-center space-y-2">
            <h2 className="text-[20px] font-black tracking-tight">
              {isRecording ? "Listening..." : "Tap to Speak"}
            </h2>
            <p className="text-[14px] text-white/40 font-medium">
              {isRecording ? `Recording ${formatTime(timer)}` : "Record Thai words to add instantly"}
            </p>
          </div>
        </div>

        {/* Notes List */}
        <div className="space-y-4">
          <div className="flex items-center justify-between px-2">
            <h3 className="text-[14px] font-black uppercase tracking-widest text-white/30">Transcribed Notes</h3>
            <span className="px-2 py-1 rounded-md bg-white/5 text-[10px] font-bold text-white/40">{notes.length} pending</span>
          </div>

          <AnimatePresence mode="popLayout">
            {notes.map((note, idx) => (
              <motion.div
                key={note.id}
                layout
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.9 }}
                className="bg-white/5 border border-white/5 rounded-3xl p-5 space-y-4 group"
              >
                <div className="flex items-start justify-between">
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <span className="text-[18px] font-bold text-white">{note.thai}</span>
                      <span className="px-2 py-0.5 rounded-full bg-white/5 text-[10px] font-black uppercase text-white/40">{note.category}</span>
                    </div>
                    <p className="text-[14px] text-white/40 font-medium">{note.burmese}</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => handleDeleteNote(note.id)}
                      className="h-10 w-10 rounded-xl bg-white/5 flex items-center justify-center text-white/20 hover:bg-[#FF4D6D]/10 hover:text-[#FF4D6D] transition-all"
                    >
                      <LucideTrash2 size={18} />
                    </button>
                    <button
                      disabled={note.status !== "pending"}
                      onClick={() => handleSaveNote(note)}
                      className={`h-10 w-10 rounded-xl flex items-center justify-center transition-all ${
                        note.status === "saved" 
                          ? "bg-[#2CE08B] text-white" 
                          : note.status === "saving"
                          ? "bg-white/10 text-white/40"
                          : "bg-[#2CE08B]/10 text-[#2CE08B] hover:bg-[#2CE08B]/20"
                      }`}
                    >
                      {note.status === "saved" ? <LucideCheck size={18} /> : 
                       note.status === "saving" ? <LucideRotateCcw size={18} className="animate-spin" /> : 
                       <LucidePlus size={18} />}
                    </button>
                  </div>
                </div>
              </motion.div>
            ))}
          </AnimatePresence>

          {notes.length === 0 && !isProcessing && (
            <div className="py-20 text-center space-y-4">
              <div className="h-20 w-20 rounded-full bg-white/5 flex items-center justify-center mx-auto text-white/10">
                <LucideMic size={40} />
              </div>
              <p className="text-white/20 font-bold max-w-[200px] mx-auto text-[14px]">
                Say a Thai word to see it transcribed here instantly
              </p>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
