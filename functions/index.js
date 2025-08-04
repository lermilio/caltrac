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

const fetch = require("node-fetch");

// Secure: pulls token from Firebase env config (set it with CLI)
const WHOOP_ACCESS_TOKEN = functions.config().whoop.token;

exports.fetchWhoopCalories = functions.https.onCall(async (data, context) => {
  try {
    const { date, userId } = data;
    console.log("🔥 fetchWhoopCalories called", date, userId);

    const start = `${date}T00:00:00.000Z`;
    const end = `${date}T23:59:59.999Z`;

    const url = `https://api.prod.whoop.com/users/me/activities?start=${start}&end=${end}`;

    const response = await fetch(url, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${WHOOP_ACCESS_TOKEN}`,
      },
    });

    const json = await response.json();

    let totalCalories = 0;
    if (Array.isArray(json)) {
      json.forEach((activity) => {
        totalCalories += activity.score_calories || 0;
      });
    }

    // Write to /users/{userId}/dailyLogs/{date}/whoop_cals
    const docRef = db
      .collection("users")
      .doc(userId)
      .collection("dailyLogs")
      .doc(date);

    await docRef.set({ whoop_cals: totalCalories }, { merge: true });

    return { success: true, whoop_cals: totalCalories };
  } catch (error) {
    console.error("WHOOP fetch error:", error);
    return { success: false, error: error.message };
  }
});

