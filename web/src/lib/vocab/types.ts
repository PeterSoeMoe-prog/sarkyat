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
};
