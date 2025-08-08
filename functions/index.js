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
  const { start, end, userId } = data;

  if (!start || !end || !userId) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields.");
  }

  try {
    const response = await axios.get("https://api.prod.whoop.com/developer/v1/activity", {
      headers: {
        Authorization: `Bearer ${process.env.WHOOP_ACCESS_TOKEN}`,
      },
      params: { start, end },
    });

    const activities = response.data;

    const whoopCals = Math.round(
      activities.reduce((sum, a) => sum + a.kilojoules / 4.184, 0)
    );

    const dateKey = start.split("T")[0]; // 'yyyy-MM-dd'

    const docRef = admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("dailyLogs")
      .doc(dateKey);

    const docSnap = await docRef.get();
    const dataExists = docSnap.exists ? docSnap.data() : {};
    const extraCals = dataExists.extra_cals || 0;

    const caloriesOut = whoopCals + extraCals;

    await docRef.set(
      {
        whoop_cals: whoopCals,
        calories_out: caloriesOut,
      },
      { merge: true }
    );

    return {
      whoop_cals: whoopCals,
      calories_out: caloriesOut,
    };

  } catch (error) {
    console.error("WHOOP fetch error:", error.response?.data || error.message);
    throw new functions.https.HttpsError("internal", "WHOOP API fetch failed.");
  }
});



