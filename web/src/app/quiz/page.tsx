"use client";

import { useEffect, useState, useMemo, useRef, useCallback } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { useVocabulary } from "@/lib/vocab/useVocabulary";
import { upsertVocabulary, saveFailedQuizIds, fetchFailedQuizIds } from "@/lib/vocab/firestore";
import confetti from "canvas-confetti";

interface QuizQuestion {
  vocabID: string;
  thai: string;
  correctBurmese: string;
  options: string[];
}

export default function QuizPage() {
  const router = useRouter();
  const { items, uid, loading } = useVocabulary();
  const [questions, setQuestions] = useState<QuizQuestion[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [selectedAnswer, setSelectedAnswer] = useState<string | null>(null);
  const [score, setScore] = useState(0);
  const [passedVocabIDs, setPassedVocabIDs] = useState<string[]>([]);
  const [failedVocabIDs, setFailedVocabIDs] = useState<string[]>([]);
  const [showResult, setShowResult] = useState(false);
  const [feedbackText, setFeedbackText] = useState<string | null>(null);
  const [timeRemaining, setTimeRemaining] = useState(5);
  const timerRef = useRef<NodeJS.Timeout | null>(null);
  const [isGenerating, setIsGenerating] = useState(false);
  const [dataReady, setDataReady] = useState(false);
  const correctAudioRef = useRef<HTMLAudioElement | null>(null);
  const wrongAudioRef = useRef<HTMLAudioElement | null>(null);

  useEffect(() => {
    if (!loading && items.length > 0) {
      setDataReady(true);
    }
  }, [loading, items]);

  useEffect(() => {
    correctAudioRef.current = new Audio("https://assets.mixkit.co/active_storage/sfx/2000/2000-preview.mp3");
    wrongAudioRef.current = new Audio("https://assets.mixkit.co/active_storage/sfx/2003/2003-preview.mp3");
  }, []);

  const ttsBusy = useRef(false);

  const playThaiTts = useCallback(async (text: string) => {
    if (!text || ttsBusy.current) return;
    ttsBusy.current = true;
    try {
      const auth = (await import("@/lib/firebase/client")).getFirebaseAuth();
      const token = await auth.currentUser?.getIdToken();
      if (!token) throw new Error("Not signed in");

      const res = await fetch("/api/tts", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ text }),
      });

      if (!res.ok) throw new Error("TTS failed");
      const buf = await res.arrayBuffer();
      const url = URL.createObjectURL(new Blob([buf], { type: "audio/mpeg" }));
      const audio = new Audio(url);
      audio.onended = () => {
        URL.revokeObjectURL(url);
        ttsBusy.current = false;
      };
      await audio.play();
    } catch (e) {
      console.error("TTS Error:", e);
      ttsBusy.current = false;
    }
  }, []);

  const generateQuiz = useCallback(() => {
    if (items.length < 3) {
      setIsGenerating(false);
      return;
    }

    const passedIDs = JSON.parse(localStorage.getItem("passed_quiz_ids") || "[]");
    const pool = items.filter(it => 
      it.burmese && 
      it.burmese.trim() !== "" && 
      !passedIDs.includes(it.id)
    );
    if (pool.length < 3) {
      setIsGenerating(false);
      return;
    }

    const shuffledPool = [...pool].sort(() => Math.random() - 0.5);
    const quizItems = shuffledPool.slice(0, 5);

    const generatedQuestions: QuizQuestion[] = quizItems.map((item) => {
      const correct = item.burmese!;
      const correctLen = correct.length;

      // Find distractors of similar length
      let distractors = pool
        .filter(it => it.id !== item.id)
        .filter(it => Math.abs(it.burmese!.length - correctLen) <= Math.max(2, Math.floor(correctLen * 0.3)))
        .sort(() => Math.random() - 0.5)
        .slice(0, 2)
        .map(it => it.burmese!);

      if (distractors.length < 2) {
        distractors = pool
          .filter(it => it.id !== item.id)
          .sort(() => Math.random() - 0.5)
          .slice(0, 2)
          .map(it => it.burmese!);
      }

      const options = [...distractors, correct].sort(() => Math.random() - 0.5);

      return {
        vocabID: item.id,
        thai: item.thai,
        correctBurmese: correct,
        options,
      };
    });

    setQuestions(generatedQuestions);
    setIsGenerating(false);
    setCurrentIndex(0);
    setScore(0);
    setShowResult(false);
    setSelectedAnswer(null);
    setFeedbackText(null);
    setTimeRemaining(5);
  }, [items]);

  const downgradeReadyToDrill = useCallback(async (vocabID: string) => {
    if (!uid) return;
    const item = items.find(it => it.id === vocabID);
    if (item && item.status === "ready") {
      await upsertVocabulary(uid, { ...item, status: "drill" });
    }
  }, [uid, items]);

  const handleTimeout = useCallback(() => {
    if (selectedAnswer !== null || showResult) return;
    
    const question = questions[currentIndex];
    setSelectedAnswer(""); // Indicates timeout
    setFeedbackText("TIME'S UP");
    
    wrongAudioRef.current?.play().catch(() => {});
    
    // Add to current session local state
    setFailedVocabIDs(prev => [...new Set([...prev, question.vocabID])]);
    
    // Add to persistent Firestore storage (merging with existing)
    if (uid) {
      fetchFailedQuizIds(uid).then(existingIds => {
        const combined = [...new Set([...existingIds, question.vocabID])];
        saveFailedQuizIds(uid, combined);
      });
    }
    
    downgradeReadyToDrill(question.vocabID);

    setTimeout(() => {
      setFeedbackText(null);
      setSelectedAnswer(null);
      if (currentIndex + 1 < questions.length) {
        setCurrentIndex(prev => prev + 1);
      } else {
        setShowResult(true);
      }
    }, 1500);
  }, [questions, currentIndex, selectedAnswer, showResult, downgradeReadyToDrill]);

  const startTimer = useCallback(() => {
    if (timerRef.current) clearInterval(timerRef.current);
    setTimeRemaining(5);
    timerRef.current = setInterval(() => {
      setTimeRemaining((prev) => {
        if (prev <= 1) {
          clearInterval(timerRef.current!);
          handleTimeout();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  }, [handleTimeout]);

  const answerSelected = useCallback(async (option: string) => {
    if (selectedAnswer !== null) return;
    if (timerRef.current) clearInterval(timerRef.current);

    const question = questions[currentIndex];
    const isCorrect = option === question.correctBurmese;
    
    setSelectedAnswer(option);
    setFeedbackText(isCorrect ? "TRUE" : "FALSE");

    if (isCorrect) {
      setScore(prev => prev + 1);
      setPassedVocabIDs(prev => [...new Set([...prev, question.vocabID])]);
      
      // Persist passed IDs so they are excluded from the next session
      const existingPassed = JSON.parse(localStorage.getItem("passed_quiz_ids") || "[]");
      localStorage.setItem("passed_quiz_ids", JSON.stringify([...new Set([...existingPassed, question.vocabID])]));
      
      correctAudioRef.current?.play().catch(() => {});
    } else {
      wrongAudioRef.current?.play().catch(() => {});
      
      // Add to current session local state
      setFailedVocabIDs(prev => [...new Set([...prev, question.vocabID])]);
      
      // Add to persistent Firestore storage (merging with existing)
      if (uid) {
        fetchFailedQuizIds(uid).then(existingIds => {
          const combined = [...new Set([...existingIds, question.vocabID])];
          saveFailedQuizIds(uid, combined);
        });
      }
      
      await downgradeReadyToDrill(question.vocabID);
    }

    setTimeout(() => {
      setFeedbackText(null);
      setSelectedAnswer(null);
      if (currentIndex + 1 < questions.length) {
        setCurrentIndex(prev => prev + 1);
      } else {
        setShowResult(true);
        if (isCorrect && score + 1 >= 4) {
          confetti({
            particleCount: 150,
            spread: 70,
            origin: { y: 0.6 }
          });
        }
      }
    }, 1000);
  }, [questions, currentIndex, selectedAnswer, score, downgradeReadyToDrill]);

  useEffect(() => {
    if (dataReady && questions.length === 0) {
      generateQuiz();
    }
  }, [dataReady, questions.length, generateQuiz]);

  useEffect(() => {
    if (questions.length > 0 && !showResult && selectedAnswer === null) {
      startTimer();
      playThaiTts(questions[currentIndex].thai);
    }
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [currentIndex, questions, showResult, selectedAnswer, startTimer, playThaiTts]);

  if (!dataReady || isGenerating) {
    return (
      <div className="min-h-screen bg-[#0A0B0F] flex items-center justify-center">
        <div className="text-white/60 font-bold tracking-widest uppercase">Loading Quiz...</div>
      </div>
    );
  }

  if (items.length < 3) {
    return (
      <div className="min-h-screen bg-[#0A0B0F] flex flex-col items-center justify-center p-6 text-center">
        <h2 className="text-2xl font-bold mb-4">Not enough vocabulary</h2>
        <p className="text-white/60 mb-8">You need at least 3 words with Burmese translations to start a quiz.</p>
        <Link href="/" className="px-8 py-4 rounded-2xl bg-white/5 border border-white/10 font-bold">Back Home</Link>
      </div>
    );
  }

  if (showResult) {
    return (
      <div className="min-h-screen bg-[#0A0B0F] text-white flex flex-col items-center justify-center p-6">
        <motion.div 
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="w-full max-w-md text-center"
        >
          <h1 className="text-3xl font-bold mb-2">Daily Quiz</h1>
          <div className="text-6xl font-black mb-8 bg-gradient-to-r from-[#FF4D6D] to-[#B36BFF] bg-clip-text text-transparent">
            {score} / {questions.length}
          </div>
          
          <div className="grid gap-4">
            {failedVocabIDs.length > 0 && (
              <button 
                onClick={() => {
                  localStorage.setItem("failed_quiz_ids", JSON.stringify(failedVocabIDs));
                  router.push("/failed-quiz");
                }}
                className="w-full py-4 rounded-2xl bg-white/5 border border-[#FF4D6D]/30 text-[#FF4D6D] font-black text-lg shadow-lg flex items-center justify-center gap-2"
              >
                <span>🔔</span> Quiz Notification ({failedVocabIDs.length})
              </button>
            )}
            <button 
              onClick={generateQuiz}
              className="w-full py-4 rounded-2xl bg-gradient-to-r from-[#FF4D6D] via-[#B36BFF] to-[#49D2FF] font-black text-lg shadow-lg"
            >
              More Quiz
            </button>
            <Link 
              href="/"
              className="w-full py-4 rounded-2xl bg-white/5 border border-white/10 font-bold text-lg"
            >
              Back Home
            </Link>
          </div>
        </motion.div>
      </div>
    );
  }

  const currentQuestion = questions[currentIndex];

  return (
    <div className="min-h-screen bg-[#0A0B0F] text-white">
      <div className="mx-auto w-full max-w-md px-4 pt-8 pb-20 flex flex-col min-h-screen">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <div className="text-white/40 font-bold uppercase tracking-widest text-xs">
            Question {currentIndex + 1} / {questions.length}
          </div>
          <div className={`flex items-center gap-2 px-3 py-1 rounded-full ${timeRemaining <= 2 ? 'bg-red-500/20 text-red-400' : 'bg-blue-500/20 text-blue-400'}`}>
            <span className="text-xs font-black">{timeRemaining}s</span>
          </div>
        </div>

        {/* Progress Bar */}
        <div className="flex gap-1.5 mb-12">
          {questions.map((_, i) => (
            <div 
              key={i} 
              className={`h-1.5 flex-1 rounded-full transition-all duration-300 ${i <= currentIndex ? 'bg-blue-500' : 'bg-white/10'}`}
            />
          ))}
        </div>

        {/* Question Card */}
        <div className="flex-1 flex flex-col items-center justify-center">
          <div className="w-full bg-white/5 border border-white/10 rounded-[32px] p-12 text-center relative overflow-hidden mb-12">
            <div className="text-5xl sm:text-6xl font-bold mb-6 tracking-tight">
              {currentQuestion?.thai}
            </div>
            <button 
              onClick={() => playThaiTts(currentQuestion.thai)}
              className="p-4 rounded-full bg-blue-500/10 text-blue-400 hover:bg-blue-500/20 transition-colors"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M11 5L6 9H2v6h4l5 4V5z"></path><path d="M19.07 4.93a10 10 0 0 1 0 14.14"></path><path d="M15.54 8.46a5 5 0 0 1 0 7.07"></path></svg>
            </button>
          </div>

          {/* Options */}
          <div className="w-full grid gap-4">
            {currentQuestion?.options.map((option, i) => (
              <button
                key={i}
                disabled={selectedAnswer !== null}
                onClick={() => answerSelected(option)}
                className={`w-full py-5 px-6 rounded-2xl font-bold text-xl transition-all duration-200 text-center shadow-lg active:scale-[0.98] ${
                  selectedAnswer !== null
                    ? option === currentQuestion.correctBurmese
                      ? 'bg-green-500 text-white'
                      : option === selectedAnswer
                        ? 'bg-red-500 text-white'
                        : 'bg-white/5 text-white/20 border-white/5'
                    : 'bg-gradient-to-r from-pink-500 via-purple-500 to-blue-500 text-white'
                }`}
              >
                {option}
              </button>
            ))}
          </div>
        </div>

        {/* Feedback Overlay */}
        <AnimatePresence>
          {feedbackText && (
            <motion.div 
              initial={{ opacity: 0, scale: 0.5 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.5 }}
              className="fixed inset-0 z-50 flex items-center justify-center pointer-events-none"
            >
              <div className="bg-white rounded-3xl p-12 shadow-2xl border-4 border-black/5">
                <div className={`text-7xl font-black ${feedbackText === 'TRUE' ? 'text-green-500' : 'text-red-500'}`}>
                  {feedbackText}
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
