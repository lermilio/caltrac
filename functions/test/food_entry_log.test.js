const test = require('node:test');
const assert = require('node:assert/strict');
const { addFoodEntry } = require('../food_entry_log');

class HttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const meal = { input: 'Chicken breast', calories: 200, protein: 30, carbs: 5, fat: 7 };
const request = (id) => ({
  userId: 'test-user', dateString: '2026-11-10',
  entryData: { ...meal, ...(id === undefined ? {} : { id }) },
});

// Only the transaction boundary is substituted; no Firebase initialization or network.
function memoryDatabase(initial, concurrentWrite) {
  let document = structuredClone(initial);
  let writes = 0;
  const ref = {};
  const logs = { doc(date) { assert.equal(date, '2026-11-10'); return ref; } };
  const user = { collection(name) { assert.equal(name, 'dailyLogs'); return logs; } };
  const users = { doc(id) { assert.equal(id, 'test-user'); return user; } };
  const db = {
    collection(name) { assert.equal(name, 'users'); return users; },
    async runTransaction(callback) {
      let pending;
      const transaction = {
        async get(actualRef) {
          assert.equal(actualRef, ref);
          const snapshot = structuredClone(document);
          return { exists: snapshot !== undefined, data: () => snapshot };
        },
        update(actualRef, data) {
          assert.equal(actualRef, ref);
          pending = { ...document, ...data };
        },
        set(actualRef, data) {
          assert.equal(actualRef, ref);
          pending = data;
        },
      };
      await callback(transaction);
      if (concurrentWrite !== undefined) {
        // Model Firestore rerunning the callback after another writer commits.
        document = structuredClone(concurrentWrite);
        concurrentWrite = undefined;
        pending = undefined;
        await callback(transaction);
      }
      if (pending !== undefined) {
        document = structuredClone(pending);
        writes++;
      }
    },
  };
  return { db, read: () => structuredClone(document), writes: () => writes };
}

async function save(store, data) {
  return addFoodEntry(data, { db: store.db, HttpsError });
}

function assertNutrition(document, count) {
  assert.equal(document.meals.length, count);
  assert.equal(document.calories_in, 200 * count);
  assert.equal(document.protein, 30 * count);
  assert.equal(document.carbs, 5 * count);
  assert.equal(document.fat, 7 * count);
}

test('first entry initializes the daily log and retains its ID', async () => {
  const store = memoryDatabase();
  assert.deepEqual(await save(store, request('first')), { success: true });
  assertNutrition(store.read(), 1);
  assert.equal(store.read().meals[0].id, 'first');
  assert.equal(store.read().date, '2026-11-10');
  for (const key of ['whoop_cals', 'extra_cals', 'calories_out', 'net_calories']) {
    assert.equal(store.read()[key], 0);
  }
});

test('two identical meals with different IDs both appear and both count', async () => {
  const store = memoryDatabase();
  await save(store, request('first'));
  await save(store, request('second'));
  assertNutrition(store.read(), 2);
  assert.deepEqual(store.read().meals.map((entry) => entry.id), ['first', 'second']);
});

test('retrying the same ID does not write or increment totals again', async () => {
  const store = memoryDatabase();
  await save(store, request('first'));
  const before = store.read();
  assert.deepEqual(await save(store, request('first')), { success: true });
  assert.deepEqual(store.read(), before);
  assert.equal(store.writes(), 1);
});

test('a reused ID with different nutrition fails without changing the log', async () => {
  const store = memoryDatabase();
  await save(store, request('first'));
  const before = store.read();
  const changed = request('first');
  changed.entryData.calories = 500;
  await assert.rejects(save(store, changed), { code: 'already-exists' });
  assert.deepEqual(store.read(), before);
});

test('old meals without IDs and expenditure fields survive a new entry', async () => {
  const initial = {
    meals: [meal], calories_in: 200, protein: 30, carbs: 5, fat: 7,
    whoop_cals: 1800, extra_cals: 200, calories_out: 2000,
  };
  const store = memoryDatabase(initial);
  await save(store, request('new'));
  assertNutrition(store.read(), 2);
  assert.deepEqual(store.read().meals[0], meal);
  assert.equal(store.read().calories_out, 2000);
  assert.equal(store.read().whoop_cals, 1800);
  assert.equal(store.read().extra_cals, 200);
});

test('older clients without IDs can still log identical meals twice', async () => {
  const store = memoryDatabase();
  await save(store, request());
  await save(store, request());
  assertNutrition(store.read(), 2);
  assert.notEqual(store.read().meals[0].id, store.read().meals[1].id);
});

test('transaction rerun observes another request already saving the same ID', async () => {
  const committed = {
    meals: [{ ...meal, id: 'first' }], calories_in: 200, protein: 30, carbs: 5, fat: 7,
  };
  const store = memoryDatabase(undefined, committed);
  await save(store, request('first'));
  assert.deepEqual(store.read(), committed);
  assert.equal(store.writes(), 0);
});

test('transaction rerun preserves a different meal added concurrently', async () => {
  const committed = {
    meals: [{ ...meal, id: 'other' }], calories_in: 200, protein: 30, carbs: 5, fat: 7,
  };
  const store = memoryDatabase(undefined, committed);
  await save(store, request('first'));
  assertNutrition(store.read(), 2);
  assert.deepEqual(store.read().meals.map((entry) => entry.id), ['other', 'first']);
});

test('missing required fields and invalid IDs are rejected without writes', async () => {
  const store = memoryDatabase();
  for (const data of [null, {}, request(''), request(42), { ...request('first'), entryData: [] }]) {
    await assert.rejects(save(store, data), { code: 'invalid-argument' });
  }
  assert.equal(store.writes(), 0);
});

test('nested callable payload is accepted', async () => {
  const store = memoryDatabase();
  await save(store, { data: request('nested') });
  assertNutrition(store.read(), 1);
});

test('transaction failures reach the caller', async () => {
  const error = new Error('Database unavailable');
  const store = memoryDatabase();
  store.db.runTransaction = async () => { throw error; };
  await assert.rejects(save(store, request('first')), (actual) => actual === error);
});
