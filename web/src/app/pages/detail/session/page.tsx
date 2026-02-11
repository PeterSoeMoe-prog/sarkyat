import { Suspense } from "react";
import SessionDetailClient from "./SessionDetailClient";

export default function SessionDetailPage() {
  return (
    <Suspense>
      <SessionDetailClient />
    </Suspense>
  );
}
