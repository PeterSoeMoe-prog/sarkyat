export default function OfflinePage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-[var(--background)] px-6 text-[color:var(--foreground)]">
      <div className="w-full max-w-md text-center">
        <h1 className="text-2xl font-semibold tracking-tight">You’re offline</h1>
        <p className="mt-3 text-sm text-[color:var(--muted)]">
          Please reconnect to continue syncing your vocabulary.
        </p>
      </div>
    </div>
  );
}
