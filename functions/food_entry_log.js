const { randomUUID } = require("node:crypto");

// Dependencies are passed in so tests can use an in-memory transaction.
async function addFoodEntry(data, { db, HttpsError }) {
  const payload = data?.data || data;
  const { userId, dateString, entryData } = payload || {};
  if (!userId || !dateString || !entryData || typeof entryData !== "object" || Array.isArray(entryData)) {
    throw new HttpsError("invalid-argument", "Missing required fields");
  }
  if (entryData.id !== undefined && (typeof entryData.id !== "string" || !entryData.id.trim())) {
    throw new HttpsError("invalid-argument", "Invalid entry ID");
  }

  // Older clients have no ID. Give each of their calls a distinct identity.
  // Updated clients supply a stable ID, which also makes retries safe.
  const entry = { ...entryData, id: entryData.id ?? randomUUID() };
  const docRef = db.collection("users").doc(userId)
    .collection("dailyLogs").doc(dateString);

  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(docRef);
    const current = doc.exists ? doc.data() : {};
    const meals = current.meals || [];
    const existing = meals.find((meal) => meal.id === entry.id);
    if (existing) {
      const sameEntry = ["input", "calories", "protein", "carbs", "fat"]
        .every((key) => (existing[key] ?? 0) === (entry[key] ?? 0));
      if (!sameEntry) {
        throw new HttpsError("already-exists", "Entry ID already belongs to a different meal");
      }
      return; // This save already committed. Do not increment totals again.
    }

    const update = {
      calories_in: (current.calories_in || 0) + (entry.calories || 0),
      protein: (current.protein || 0) + (entry.protein || 0),
      carbs: (current.carbs || 0) + (entry.carbs || 0),
      fat: (current.fat || 0) + (entry.fat || 0),
      meals: [...meals, entry],
    };
    if (doc.exists) {
      transaction.update(docRef, update);
    } else {
      transaction.set(docRef, {
        date: dateString,
        calories_out: 0,
        net_calories: 0,
        whoop_cals: 0,
        extra_cals: 0,
        ...update,
      });
    }
  });
  return { success: true };
}

module.exports = { addFoodEntry };
