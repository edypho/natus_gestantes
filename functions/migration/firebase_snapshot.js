/* eslint-disable require-jsdoc */
"use strict";

async function readCollections(db, definitions) {
  const collections = {};
  for (const definition of definitions) {
    const snapshot = await db.collection(definition.name).get();
    collections[definition.name] = snapshot.docs.map((document) => ({
      id: document.id,
      path: document.ref.path,
      data: document.data() || {},
    }));
  }
  return collections;
}

async function readAuthUsers(auth) {
  const users = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    users.push(...page.users.map((user) => ({
      uid: user.uid,
      disabled: user.disabled === true,
      email: user.email || "",
      emailVerified: user.emailVerified === true,
      displayName: user.displayName || "",
      phoneNumber: user.phoneNumber || "",
      photoURL: user.photoURL || "",
      customClaims: user.customClaims || {},
      providerData: user.providerData || [],
    })));
    pageToken = page.pageToken;
  } while (pageToken);
  return users;
}

async function preflightCanonicalDestinations(db, sets) {
  const blockers = [];
  const canonical = sets.filter(
      (operation) => operation.path.startsWith("clinicas/") &&
        operation.path.split("/").length > 2,
  );
  for (let offset = 0; offset < canonical.length; offset += 100) {
    const slice = canonical.slice(offset, offset + 100);
    const references = slice.map((item) => db.doc(item.path));
    const snapshots = await db.getAll(...references);
    for (let index = 0; index < snapshots.length; index += 1) {
      const snapshot = snapshots[index];
      if (!snapshot.exists) continue;
      const incoming = String(
          slice[index].data.migracaoOrigem || "",
      ).trim();
      const existing = String(
          snapshot.data().migracaoOrigem || "",
      ).trim();
      if (!existing || !incoming || existing === incoming) continue;
      blockers.push({
        code: "CANONICAL_DESTINATION_CONFLICT",
        path: snapshot.ref.path,
      });
    }
  }
  return blockers;
}

async function applyFirestoreSets(db, sets) {
  const writer = db.bulkWriter();
  const errors = [];
  writer.onWriteError((error) => {
    errors.push({path: error.documentRef.path, code: error.code});
    return error.failedAttempts < 3;
  });
  for (const operation of sets) {
    writer.set(db.doc(operation.path), operation.data, {merge: true});
  }
  await writer.close();
  if (errors.length > 0) {
    throw new Error(
        `Falha ao aplicar ${errors.length} gravações Firestore.`,
    );
  }
}

async function applyAuthUpdates(auth, updates) {
  for (const update of updates) {
    await auth.setCustomUserClaims(update.uid, update.customClaims || {});
    await auth.updateUser(update.uid, {disabled: update.disabled === true});
  }
}

module.exports = {
  applyAuthUpdates,
  applyFirestoreSets,
  preflightCanonicalDestinations,
  readAuthUsers,
  readCollections,
};
