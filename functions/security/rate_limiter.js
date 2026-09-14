"use strict";
/* eslint-disable require-jsdoc */

const {createHash} = require("node:crypto");

class RateLimitExceededError extends Error {
  constructor(retryAfterSeconds) {
    super("rate_limit_exceeded");
    this.name = "RateLimitExceededError";
    this.code = "rate-limit-exceeded";
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

function positiveInteger(value, field) {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new TypeError(`${field} must be a positive integer`);
  }
  return value;
}

function rateLimitDocumentId(action, subject) {
  const normalizedAction = String(action || "").trim();
  const normalizedSubject = String(subject || "").trim();
  if (!normalizedAction || !normalizedSubject) {
    throw new TypeError("action and subject are required");
  }
  if (normalizedAction.length > 80 || normalizedSubject.length > 512) {
    throw new TypeError("action or subject exceeds the safe length");
  }

  return createHash("sha256")
      .update(`natus-rate-limit-v1\0${normalizedAction}\0${normalizedSubject}`)
      .digest("hex");
}

function nextRateLimitState({current, nowMillis, limit, windowMillis}) {
  positiveInteger(nowMillis, "nowMillis");
  positiveInteger(limit, "limit");
  positiveInteger(windowMillis, "windowMillis");

  const storedStart = Number(current && current.windowStartedAtMillis);
  const storedCount = Number(current && current.count);
  const activeWindow = Number.isSafeInteger(storedStart) &&
    storedStart > 0 &&
    nowMillis >= storedStart &&
    nowMillis - storedStart < windowMillis;
  const windowStartedAtMillis = activeWindow ? storedStart : nowMillis;
  const count = activeWindow && Number.isSafeInteger(storedCount) &&
    storedCount >= 0 ? storedCount : 0;

  if (count >= limit) {
    const remainingMillis = Math.max(
        1,
        windowMillis - (nowMillis - windowStartedAtMillis),
    );
    throw new RateLimitExceededError(Math.ceil(remainingMillis / 1000));
  }

  return {
    count: count + 1,
    windowStartedAtMillis,
    expiresAt: new Date(windowStartedAtMillis + (windowMillis * 2)),
  };
}

async function consumeRateLimit({
  db,
  action,
  subjects,
  limit,
  windowSeconds,
  nowMillis = Date.now(),
}) {
  if (!db || typeof db.runTransaction !== "function") {
    throw new TypeError("A Firestore instance is required");
  }
  positiveInteger(limit, "limit");
  positiveInteger(windowSeconds, "windowSeconds");
  positiveInteger(nowMillis, "nowMillis");

  const uniqueSubjects = Array.from(new Set(
      (Array.isArray(subjects) ? subjects : [])
          .map((value) => String(value || "").trim())
          .filter(Boolean),
  ));
  if (uniqueSubjects.length === 0 || uniqueSubjects.length > 4) {
    throw new TypeError("Between one and four subjects are required");
  }

  const collection = db.collection("_backendRateLimits");
  const refs = uniqueSubjects.map((subject) =>
    collection.doc(rateLimitDocumentId(action, subject)),
  );
  const windowMillis = windowSeconds * 1000;

  await db.runTransaction(async (transaction) => {
    const snapshots = await Promise.all(
        refs.map((ref) => transaction.get(ref)),
    );
    const states = snapshots.map((snapshot) => nextRateLimitState({
      current: snapshot.exists ? snapshot.data() : null,
      nowMillis,
      limit,
      windowMillis,
    }));

    states.forEach((state, index) => {
      transaction.set(refs[index], {
        action: String(action || "").slice(0, 80),
        ...state,
      }, {merge: false});
    });
  });
}

module.exports = {
  RateLimitExceededError,
  consumeRateLimit,
  nextRateLimitState,
  rateLimitDocumentId,
};
