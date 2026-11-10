const CYCLE_URL = "https://api.prod.whoop.com/developer/v2/cycle";
const TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token";

// Tests supply local HTTP/database substitutes instead of live services.
function createWhoopService({
  db, http, getClientCredentials, serverTimestamp, HttpsError, now = Date.now,
}) {
  async function getFreshAccessToken(userId, { forceRefresh = false } = {}) {
    const docRef = db.collection("users").doc(userId)
      .collection("integrations").doc("whoop");
    const snap = await docRef.get();
    if (!snap.exists) {
      throw new HttpsError("failed-precondition", "reauth_required");
    }

    const { access_token, refresh_token, expires_at } = snap.data();
    if (!forceRefresh && access_token && expires_at && now() < expires_at - 60_000) {
      return access_token;
    }
    if (!refresh_token) {
      throw new HttpsError("failed-precondition", "reauth_required");
    }

    try {
      const { id, secret } = getClientCredentials();
      const response = await http.post(
        TOKEN_URL,
        new URLSearchParams({
          grant_type: "refresh_token",
          refresh_token,
          client_id: id,
          client_secret: secret,
        }),
        { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
      );
      const { access_token: newAccess, refresh_token: newRefresh, expires_in } = response.data;
      if (!newAccess) throw new Error("Missing access token in refresh response");

      await docRef.set({
        access_token: newAccess,
        refresh_token: newRefresh || refresh_token,
        expires_at: now() + (expires_in ?? 3600) * 1000,
        updated_at: serverTimestamp(),
      }, { merge: true });
      return newAccess;
    } catch (_) {
      throw new HttpsError("failed-precondition", "reauth_required");
    }
  }

  async function fetchWhoopCalories(data) {
    const { start, end, userId } = data?.data || data || {};
    if (!start || !end || !userId) {
      throw new HttpsError("invalid-argument", "Missing required fields.");
    }

    const accessToken = await getFreshAccessToken(userId);
    const requestCycles = (token) => http.get(CYCLE_URL, {
      headers: { Authorization: `Bearer ${token}` },
      params: { start, end },
    });

    try {
      let response;
      try {
        response = await requestCycles(accessToken);
      } catch (error) {
        if (error?.response?.status !== 401) throw error;
        // WHOOP rejected this token, even if our stored expiry looks valid.
        const retryToken = await getFreshAccessToken(userId, { forceRefresh: true });
        response = await requestCycles(retryToken); // Exactly one retry.
      }

      // Both the initial request and retry use this one processing/write path.
      const records = Array.isArray(response.data.records) ? response.data.records : [];
      const dateKey = start.split("T")[0];
      const matching = records.filter((record) => record.start && record.start.startsWith(dateKey));
      const whoopCals = Math.round(
        matching.reduce((sum, record) => sum + (record.score?.kilojoule || 0) / 4.184, 0)
      );

      const docRef = db.collection("users").doc(userId)
        .collection("dailyLogs").doc(dateKey);
      const snap = await docRef.get();
      const extraCals = snap.exists ? (snap.data().extra_cals || 0) : 0;
      const result = { whoop_cals: whoopCals, calories_out: whoopCals + extraCals };
      await docRef.set(result, { merge: true });
      return result;
    } catch (error) {
      if (error?.code === "failed-precondition") throw error;
      throw new HttpsError("internal", "WHOOP API fetch failed.");
    }
  }

  return { getFreshAccessToken, fetchWhoopCalories };
}

module.exports = { createWhoopService };
