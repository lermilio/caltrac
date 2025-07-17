const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

exports.addEntryLog = functions.https.onCall(async (data, context) => {
  console.log("ADD ENTRY FUNCTION HIT");

  const userId = data.userId || data?.data?.userId;
  const dateString = data.dateString || data?.data?.dateString;
  const entryData = data.entryData || data?.data?.entryData;

  console.log("Data received:", { userId, dateString, entryData });

  if (!userId || !entryData || !dateString) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields");
  }

  const docRef = admin.firestore()
    .collection("users")
    .doc(userId)
    .collection("dailyLogs")
    .doc(dateString);

  await admin.firestore().runTransaction(async (transaction) => {
    const doc = await transaction.get(docRef);

    if (doc.exists) {
      const current = doc.data();
      transaction.update(docRef, {
        calories_in: (current.calories_in || 0) + entryData.calories,
        protein: (current.protein || 0) + entryData.protein,
        carbs: (current.carbs || 0) + entryData.carbs,
        fat: (current.fat || 0) + entryData.fat,
        meals: admin.firestore.FieldValue.arrayUnion(entryData),
      });
    } else {
      transaction.set(docRef, {
        date: dateString,
        calories_in: entryData.calories,
        calories_out: 0,
        net_calories: 0,
        protein: entryData.protein,
        carbs: entryData.carbs,
        fat: entryData.fat,
        alcohol: 0,
        meals: [entryData],
      });
    }
  });

  return { success: true };
});