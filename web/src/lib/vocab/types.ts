export type BookEntry = {
  id: string;
  name: string;
  writer?: string;
  createdAt: number;
};

export type BookSession = {
  id: string;
  bookId: string;
  name: string;
  createdAt: number;
  note?: string;
  order?: number;
  status?: SessionStatus;
};

export type SessionStatus = "drill" | "ready";

export type VocabularyStatus = "queue" | "drill" | "ready";

export type VocabularyEntry = {
  id: string;
  thai: string;
  burmese?: string | null;
  count: number;
  status: VocabularyStatus;
  category?: string | null;
  updatedAt?: number;
  ai_explanation?: string | null;
  ai_composition?: string | null;
  ai_sentence?: string | null;
};
