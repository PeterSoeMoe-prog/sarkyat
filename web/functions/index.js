const functions = require("firebase-functions");
const admin = require("firebase-admin");
const textToSpeech = require("@google-cloud/text-to-speech");

admin.initializeApp();

function readServiceAccountJson() {
  const fromEnvB64 = process.env.GOOGLE_TTS_SERVICE_ACCOUNT_B64;
  if (fromEnvB64 && String(fromEnvB64).trim()) {
    return Buffer.from(String(fromEnvB64).trim(), "base64").toString("utf8");
  }

  const fromEnv = process.env.GOOGLE_TTS_SERVICE_ACCOUNT_JSON;
  if (fromEnv && String(fromEnv).trim()) return String(fromEnv);

  const cfg = functions.config && typeof functions.config === "function" ? functions.config() : null;
  const fromConfigB64 =
    cfg?.tts?.service_account_b64 || cfg?.tts?.serviceAccountB64 || cfg?.tts?.b64;
  if (fromConfigB64 && String(fromConfigB64).trim()) {
    return Buffer.from(String(fromConfigB64).trim(), "base64").toString("utf8");
  }
  const fromConfig = cfg?.tts?.service_account_json || cfg?.tts?.serviceAccountJson || cfg?.tts?.key;
  if (fromConfig && String(fromConfig).trim()) return String(fromConfig);

  return null;
}

let cachedClient = null;

function getTtsClient() {
  if (cachedClient) return cachedClient;

  const raw = readServiceAccountJson();
  if (raw) {
    const parsed = JSON.parse(raw);
    const credentials = {
      client_email: parsed.client_email,
      private_key: parsed.private_key,
    };
    cachedClient = new textToSpeech.TextToSpeechClient({
      projectId: parsed.project_id,
      credentials,
    });
    return cachedClient;
  }

  cachedClient = new textToSpeech.TextToSpeechClient();
  return cachedClient;
}

async function verifyAuth(req) {
  const header = String(req.headers.authorization || "");
  const token = header.startsWith("Bearer ") ? header.slice("Bearer ".length).trim() : "";
  if (!token) throw new Error("missing-auth");
  return admin.auth().verifyIdToken(token);
}

exports.tts = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "method-not-allowed" });
    return;
  }

  try {
    await verifyAuth(req);
  } catch {
    res.status(401).json({ error: "unauthorized" });
    return;
  }

  let body = req.body;
  if (!body || typeof body !== "object") {
    try {
      const raw = req.rawBody ? req.rawBody.toString("utf8") : "";
      body = raw ? JSON.parse(raw) : null;
    } catch {
      body = null;
    }
  }

  const text = String(body?.text ?? "").trim();
  if (!text) {
    res.status(400).json({ error: "missing-text" });
    return;
  }

  if (text.length > 400) {
    res.status(400).json({ error: "text-too-long" });
    return;
  }

  try {
    const client = getTtsClient();
    const [response] = await client.synthesizeSpeech({
      input: { text },
      voice: {
        languageCode: "th-TH",
        name: "th-TH-Standard-A",
      },
      audioConfig: {
        audioEncoding: "MP3",
      },
    });

    const audioContent = response.audioContent;
    if (!audioContent) {
      res.status(500).json({ error: "empty-audio" });
      return;
    }

    res.set("Content-Type", "audio/mpeg");
    res.set("Cache-Control", "no-store");
    res.status(200).send(Buffer.from(audioContent, "base64"));
  } catch (e) {
    const msg = (e && e.message) ? String(e.message) : "tts-failed";
    res.status(500).json({ error: msg });
  }
});
