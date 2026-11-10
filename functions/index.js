const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();
const { addFoodEntry } = require("./food_entry_log");

exports.addEntryLog = functions.https.onCall((data) =>
  addFoodEntry(data, { db, HttpsError: functions.https.HttpsError })
);

exports.addWeightLog = functions.https.onCall(async (data, context) => { // Define the func to add a weight log

  const userId = data.userId || data?.data?.userId;
  const dateString = data.dateString || data?.data?.dateString;
  const weight = data.weight || data?.data?.weight;

  console.log("Data received:", { userId, dateString, weight });

  if (!userId || !dateString || !weight) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields");  // Validate input data
  }

  const docRef = admin.firestore()                 // Create a reference to the document
    .collection("users")
    .doc(userId)
    .collection("weightLogs")
    .doc(dateString);

  await admin.firestore().runTransaction(async (transaction) => {   // Updating the document in a transaction
    const doc = await transaction.get(docRef);
    if (doc.exists) {
      // Reject if a weight log for this date already exists
      throw new functions.https.HttpsError(
        "already-exists",
        `A weight entry already exists for ${dateString}`
      );
    }

    // Otherwise, create the weight log
    transaction.set(docRef, {
      date: admin.firestore.Timestamp.fromDate(new Date(dateString)),
      weight: parseFloat(weight),
    });
  });
});

const axios = require("axios");
require("dotenv").config();

const { defineString } = require("firebase-functions/params");

// Define runtime params (Gen2-friendly)
const WHOOP_CLIENT_ID_PARAM = defineString("WHOOP_CLIENT_ID");
const WHOOP_CLIENT_SECRET_PARAM = defineString("WHOOP_CLIENT_SECRET");

// Helper: read creds from params OR plain env, then build Basic auth
function getBasicAuth() {
  const id =
    WHOOP_CLIENT_ID_PARAM.value() || process.env.WHOOP_CLIENT_ID || "";
  const secret =
    WHOOP_CLIENT_SECRET_PARAM.value() || process.env.WHOOP_CLIENT_SECRET || "";

  console.log("WHOOP env present?", { id: !!id, secret: !!secret });
  return "Basic " + Buffer.from(`${id}:${secret}`).toString("base64");
}



const { createWhoopService } = require("./whoop_calories");
const whoopService = createWhoopService({
  db,
  http: axios,
  getClientCredentials: getWhoopClientCreds,
  serverTimestamp: () => admin.firestore.FieldValue.serverTimestamp(),
  HttpsError: functions.https.HttpsError,
});

exports.fetchWhoopCalories = functions.https.onCall(whoopService.fetchWhoopCalories);

function getWhoopClientCreds() {
  const id = WHOOP_CLIENT_ID_PARAM.value() || process.env.WHOOP_CLIENT_ID || "";
  const secret = WHOOP_CLIENT_SECRET_PARAM.value() || process.env.WHOOP_CLIENT_SECRET || "";
  return { id, secret };
}

exports.exchangeWhoopCode = functions.https.onCall(async (data, context) => {
  const { code, userId } = data || {};
  if (!code || !userId) {
    throw new functions.https.HttpsError("invalid-argument", "Missing code or userId.");
  }

  const { id, secret } = getWhoopClientCreds();

  try {
    const resp = await axios.post(
      "https://api.prod.whoop.com/oauth/oauth2/token",
      new URLSearchParams({
        grant_type: "authorization_code",
        code,
        redirect_uri: "http://localhost:8080/callback",
        client_id: id,
        client_secret: secret,
      }),
      { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
    );

    const { access_token, refresh_token, expires_in } = resp.data;

    await db.collection("users").doc(userId)
      .collection("integrations").doc("whoop")
      .set({
        access_token,
        refresh_token: refresh_token || null,
        expires_at: Date.now() + (expires_in ?? 3600) * 1000,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

    return {
      ok: true,
      hasRefresh: !!refresh_token,
      expires_in,
    };
  } catch (err) {
    console.error("exchangeWhoopCode error:", err.response?.data || err.message);
    throw new functions.https.HttpsError("internal", "WHOOP code exchange failed.");
  }
});
