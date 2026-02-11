This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## PWA + Firebase Setup

### 1) Create `.env.local`

Copy the example file and fill in values from your Firebase Console (Project Settings -> Your apps -> Web app):

```bash
cp .env.local.example .env.local
```

Required variables:

- `NEXT_PUBLIC_FIREBASE_API_KEY`
- `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN`
- `NEXT_PUBLIC_FIREBASE_PROJECT_ID`
- `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET`
- `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID`
- `NEXT_PUBLIC_FIREBASE_APP_ID`

### 2) Enable Anonymous Auth

In Firebase Console:

- Authentication -> Sign-in method -> enable **Anonymous**.

### 3) Firestore

In Firebase Console:

- Create a Firestore database
- Set up Security Rules (we’ll lock this down to `users/{uid}` shortly)

This app uses Firestore realtime listeners and enables IndexedDB persistence in the browser for offline support.

#### Recommended (starter) Security Rules

This stores vocabulary under `users/{uid}/vocab/{vocabId}`:

```txt
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/vocab/{docId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 4) PWA

- PWA manifest: `public/manifest.webmanifest`
- Service worker: `public/sw.js` (registered only in production builds)
- iOS “Add to Home Screen” metadata is configured in `src/app/layout.tsx`

## Getting Started

First, run the development server:

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
# or
bun dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

## One-time Queue -> Drill Migration

For bulk status updates, use the built-in script that targets Firebase project `sar-kyat` using your Firebase CLI login token (no service-account JSON required):

```bash
# Dry run for one user
npm run migrate:queue-to-drill:dry -- --uids=<uid>

# Execute for one or multiple users
npm run migrate:queue-to-drill -- --uids=<uid1,uid2>

# Dry run for all users
npm run migrate:queue-to-drill:dry -- --all-users
```

If needed, login first:

```bash
firebase login
```

You can start editing the page by modifying `app/page.tsx`. The page auto-updates as you edit the file.

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.
