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
    const response = await axios.get("https://api.prod.whoop.com/developer/v1/activity", {
      headers: { Authorization: `Bearer ${accessToken}` },
      params: { start, end },
    });

    const activities = response.data || [];

    // Convert kJ -> kcal and sum
    const whoopCals = Math.round(activities.reduce((sum, a) => sum + (a.kilojoules || 0) / 4.184, 0));

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
        const retryResp = await axios.get("https://api.prod.whoop.com/developer/v1/activity", {
          headers: { Authorization: `Bearer ${retryToken}` },
          params: { start, end },
        });
        const activities = retryResp.data || [];
        const whoopCals = Math.round(activities.reduce((sum, a) => sum + (a.kilojoules || 0) / 4.184, 0));

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

exports.exchangeWhoopCode = functions.https.onCall(async (data, context) => {
  const { code, userId } = data || {};
  if (!code || !userId) {
    throw new functions.https.HttpsError("invalid-argument", "Missing code or userId.");
  }

  try {
    const resp = await axios.post(
      WHOOP_TOKEN_URL,
      new URLSearchParams({
        grant_type: "authorization_code",
        code,
        redirect_uri: "http://localhost:8080/callback",
        client_id: process.env.WHOOP_CLIENT_ID,
        client_secret: process.env.WHOOP_CLIENT_SECRET,
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

  // If token is still valid for > 1 min, just return it
  if (expires_at && Date.now() < expires_at - 60_000) {
    return access_token;
  }

  // Can't refresh if no refresh token stored yet
  if (!refresh_token) {
    throw new functions.https.HttpsError("failed-precondition", "reauth_required");
  }

  try {
    const resp = await axios.post(
      WHOOP_TOKEN_URL,
      new URLSearchParams({
        grant_type: "refresh_token",
        refresh_token,
        client_id: process.env.WHOOP_CLIENT_ID,
        client_secret: process.env.WHOOP_CLIENT_SECRET,
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

