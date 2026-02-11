import { Suspense } from "react";

import BookDetailClient from "./BookDetailClient";

export default function BookDetailPage() {
  return (
    <Suspense>
      <BookDetailClient />
    </Suspense>
  );
}
