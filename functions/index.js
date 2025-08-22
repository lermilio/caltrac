const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

exports.addEntryLog = functions.https.onCall(async (data, context) => { // Define the func to add an entry log

  const userId = data.userId || data?.data?.userId;
  const dateString = data.dateString || data?.data?.dateString;         // Extract userId and dateString from data
  const entryData = data.entryData || data?.data?.entryData;

  console.log("Data received:", { userId, dateString, entryData });

  if (!userId || !entryData || !dateString) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields");  // Validate input data
  }

  const docRef = admin.firestore()                 // Create a reference to the document
    .collection("users")
    .doc(userId)
    .collection("dailyLogs")
    .doc(dateString);

  await admin.firestore().runTransaction(async (transaction) => {   // Updating the document in a transaction
    const doc = await transaction.get(docRef);

    if (doc.exists) {
      const current = doc.data();
      transaction.update(docRef, {
        calories_in: (current.calories_in || 0) + (entryData.calories || 0),
        protein:     (current.protein     || 0) + (entryData.protein  || 0),
        carbs:       (current.carbs       || 0) + (entryData.carbs    || 0),
        fat:         (current.fat         || 0) + (entryData.fat      || 0),
        meals: admin.firestore.FieldValue.arrayUnion(entryData),
      });
    } else {
      transaction.set(docRef, {
        date: dateString,
        calories_in: entryData.calories || 0,
        calories_out: 0,
        net_calories: 0,
        protein: entryData.protein || 0,
        carbs: entryData.carbs || 0,
        fat: entryData.fat || 0,
        meals: [entryData],
        whoop_cals: 0,
        extra_cals: 0,
      });
    }
  });

  return { success: true };
});

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



exports.fetchWhoopCalories = functions.https.onCall(async (data, context) => {
  const start = data.start || data?.data?.start;
  const end = data.end || data?.data?.end;
  const userId = data.userId || data?.data?.userId;

  if (!start || !end || !userId) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields.");
  }

  // 1) Always get a valid access token for this user
  let accessToken;
  try {
    accessToken = await getFreshAccessToken(userId);
  } catch (e) {
    // If we can’t refresh because there’s no refresh_token yet, tell the client to re-auth
    if (e?.code === "failed-precondition") {
      throw new functions.https.HttpsError("failed-precondition", "reauth_required");
    }
    throw e;
  }

  try {
    // 2) Call WHOOP with the user-scoped token
    const response = await axios.get("https://api.prod.whoop.com/developer/v2/cycle", {      headers: { Authorization: `Bearer ${accessToken}` },
      params: { start, end },
    });

    const activities = Array.isArray(response.data.records) ? response.data.records : [];
    console.log("WHOOP /cycle response:", response.data); 
    const targetDate = start.split("T")[0]; // e.g., '2025-08-19'
    const filtered = activities.filter(a => a.start && a.start.startsWith(targetDate));
    const whoopCals = Math.round(
      filtered.reduce((sum, a) => sum + (a.score?.kilojoule || 0) / 4.184, 0)
    );

    // 3) Write to Firestore and compute calories_out = whoop_cals + extra_cals
    const dateKey = start.split("T")[0]; // 'yyyy-MM-dd'
    const docRef = admin.firestore()
      .collection("users").doc(userId)
      .collection("dailyLogs").doc(dateKey);

    const snap = await docRef.get();
    const extraCals = (snap.exists ? (snap.data().extra_cals || 0) : 0);
    const caloriesOut = whoopCals + extraCals;

    await docRef.set(
      { whoop_cals: whoopCals, calories_out: caloriesOut },
      { merge: true }
    );

    return { whoop_cals: whoopCals, calories_out: caloriesOut };
  } catch (err) {
    // If the token somehow went bad between refresh and call, try one silent refresh then retry once.
    if (err?.response?.status === 401) {
      try {
        const retryToken = await getFreshAccessToken(userId); // will refresh if needed
        const retryResp = await axios.get("https://api.prod.whoop.com/developer/v2/cycle", {
          headers: { Authorization: `Bearer ${retryToken}` },
          params: { start, end },
        });

        console.log("WHOOP /cycle response:", response.data); 

        const activities = Array.isArray(retryResp.data.records) ? retryResp.data.records : [];
        console.log("WHOOP /cycle records:", JSON.stringify(activities, null, 2));
        const filtered = activities.filter(a => a.start && a.start.startsWith(targetDate));
        const whoopCals = Math.round(
          filtered.reduce((sum, a) => sum + (a.score?.kilojoule || 0) / 4.184, 0)
        );

        const dateKey = start.split("T")[0];
        const docRef = admin.firestore()
          .collection("users").doc(userId)
          .collection("dailyLogs").doc(dateKey);
        const snap = await docRef.get();
        const extraCals = (snap.exists ? (snap.data().extra_cals || 0) : 0);
        const caloriesOut = whoopCals + extraCals;

        await docRef.set({ whoop_cals: whoopCals, calories_out: caloriesOut }, { merge: true });
        return { whoop_cals: whoopCals, calories_out: caloriesOut };
      } catch (e2) {
        console.error("WHOOP retry failed:", e2.response?.data || e2.message);
      }
    }

    console.error("WHOOP fetch error:", err.response?.data || err.message);
    throw new functions.https.HttpsError("internal", "WHOOP API fetch failed.");
  }
});


const WHOOP_TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token";

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

async function getFreshAccessToken(userId) {
  const docRef = db.collection("users").doc(userId).collection("integrations").doc("whoop");
  const snap = await docRef.get();

  if (!snap.exists) {
    throw new functions.https.HttpsError("failed-precondition", "No WHOOP tokens found for this user.");
  }

  const { access_token, refresh_token, expires_at } = snap.data();

  if (expires_at && Date.now() < expires_at - 60_000) {
    return access_token;
  }

  if (!refresh_token) {
    throw new functions.https.HttpsError("failed-precondition", "reauth_required");
  }

  const { id, secret } = getWhoopClientCreds();

  try {
    const resp = await axios.post(
      "https://api.prod.whoop.com/oauth/oauth2/token",
      new URLSearchParams({
        grant_type: "refresh_token",
        refresh_token,
        client_id: id,
        client_secret: secret,
      }),
      { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
    );

    const { access_token: newAccess, refresh_token: newRefresh, expires_in } = resp.data;

    await docRef.set({
      access_token: newAccess,
      refresh_token: newRefresh || refresh_token,
      expires_at: Date.now() + (expires_in ?? 3600) * 1000,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return newAccess;
  } catch (err) {
    console.error("WHOOP token refresh failed:", err.response?.data || err.message);
    throw new functions.https.HttpsError("failed-precondition", "reauth_required");
  }
}