#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const PROJECT_ID = "sar-kyat";
const DEFAULT_DB = "(default)";

function parseArgs(argv) {
  const out = {
    uids: [],
    allUsers: false,
    dryRun: false,
  };

  for (const arg of argv) {
    if (arg.startsWith("--uids=")) {
      out.uids = arg
        .slice("--uids=".length)
        .split(",")
        .map((v) => v.trim())
        .filter(Boolean);
      continue;
    }
    if (arg === "--all-users") {
      out.allUsers = true;
      continue;
    }
    if (arg === "--dry-run") {
      out.dryRun = true;
    }
  }

  return out;
}

function readFirebaseCliToken() {
  const configPath = path.join(
    process.env.HOME || "",
    ".config",
    "configstore",
    "firebase-tools.json"
  );
  const raw = fs.readFileSync(configPath, "utf8");
  const parsed = JSON.parse(raw);
  const token = parsed?.tokens?.access_token;
  if (!token) {
    throw new Error("Missing Firebase CLI token. Run `firebase login` first.");
  }
  return token;
}

function firestoreBaseUrl() {
  return `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/${DEFAULT_DB}/documents`;
}

async function listCollectionDocs(token, collectionPath) {
  let url = `${firestoreBaseUrl()}/${collectionPath}?pageSize=1000`;
  const docs = [];
  while (url) {
    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const text = await res.text();
    if (!res.ok) {
      throw new Error(`List failed (${res.status}): ${text.slice(0, 300)}`);
    }
    const data = JSON.parse(text);
    if (Array.isArray(data.documents)) docs.push(...data.documents);
    url = data.nextPageToken
      ? `${firestoreBaseUrl()}/${collectionPath}?pageSize=1000&pageToken=${encodeURIComponent(
          data.nextPageToken
        )}`
      : null;
  }
  return docs;
}

async function listUserIds(token) {
  const users = await listCollectionDocs(token, "users");
  return users
    .map((d) => d.name.split("/").pop())
    .filter(Boolean);
}

function needsQueueToDrillUpdate(doc) {
  const statusField = doc?.fields?.status;
  if (!statusField) return true;
  if (statusField.nullValue !== undefined) return true;
  const value = typeof statusField.stringValue === "string" ? statusField.stringValue : "";
  return value === "" || value === "queue";
}

async function batchWriteStatus(token, documentNames) {
  for (let i = 0; i < documentNames.length; i += 500) {
    const chunk = documentNames.slice(i, i + 500);
    const body = {
      writes: chunk.map((name) => ({
        update: {
          name,
          fields: {
            status: { stringValue: "drill" },
          },
        },
        updateMask: { fieldPaths: ["status"] },
        currentDocument: { exists: true },
      })),
    };

    const res = await fetch(
      `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/${DEFAULT_DB}/documents:batchWrite`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      }
    );

    const text = await res.text();
    if (!res.ok) {
      throw new Error(`batchWrite failed (${res.status}): ${text.slice(0, 300)}`);
    }
    const data = JSON.parse(text);
    const statuses = Array.isArray(data.status) ? data.status : [];
    const firstError = statuses.find((s) => s && s.code && s.code !== 0);
    if (firstError) {
      throw new Error(`batchWrite status error: ${JSON.stringify(firstError)}`);
    }
  }
}

async function migrateUid(token, uid, dryRun) {
  const docs = await listCollectionDocs(token, `users/${uid}/vocab`);
  const targets = docs.filter(needsQueueToDrillUpdate).map((d) => d.name);
  if (!dryRun && targets.length > 0) {
    await batchWriteStatus(token, targets);
  }
  return {
    uid,
    total: docs.length,
    updated: targets.length,
    skipped: docs.length - targets.length,
    dryRun,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.allUsers && args.uids.length === 0) {
    throw new Error("Pass --uids=<uid1,uid2> or --all-users");
  }

  const token = readFirebaseCliToken();
  const uids = args.allUsers ? await listUserIds(token) : args.uids;

  const rows = [];
  for (const uid of uids) {
    rows.push(await migrateUid(token, uid, args.dryRun));
  }

  console.log(`Project: ${PROJECT_ID}`);
  for (const row of rows) {
    console.log(
      `${row.uid} total=${row.total} updated=${row.updated} skipped=${row.skipped}${
        row.dryRun ? " (dry-run)" : ""
      }`
    );
  }
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
