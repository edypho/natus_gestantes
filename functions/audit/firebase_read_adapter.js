/* eslint-disable require-jsdoc */
"use strict";

const {FieldPath} = require("firebase-admin/firestore");

const {
  AUDIT_FIELD_PATHS,
  CANONICAL_CLINIC_COLLECTIONS,
  CANONICAL_PATIENT_COLLECTIONS,
  ROOT_COLLECTIONS,
} = require("./multi_tenant_manifest");

class FirebaseReadAdapter {
  constructor(options) {
    this._db = options.db;
    this._auth = options.auth || null;
    this._pageSize = options.pageSize || 500;
    this._maxDocuments = options.maxDocuments || 0;
    this._maxReferences = options.maxReferences || 10000;
    this._maxDepth = options.maxDepth || 8;
    this._documentsRead = 0;
    this._limitReached = false;
    this._referencesListed = 0;
    this._referencesVisited = 0;
    this._referenceLimitReached = false;
    this._depthLimitReached = false;
    this._unknownCanonicalCollections = new Set();
    this._unknownLegacySubcollections = new Set();
    this._missingCanonicalParents = new Map();
  }

  get scanState() {
    const referenceLimitReached = this._referenceLimitReached ||
      this._referencesVisited >= this._maxReferences;
    return {
      complete: !this._limitReached && !referenceLimitReached &&
        !this._depthLimitReached,
      documentsRead: this._documentsRead,
      limitReached: this._limitReached,
      referencesListed: this._referencesListed,
      referencesVisited: this._referencesVisited,
      referenceLimitReached,
      depthLimitReached: this._depthLimitReached,
      unknownCanonicalCollections: [
        ...this._unknownCanonicalCollections,
      ].sort(),
      unknownLegacySubcollections: [
        ...this._unknownLegacySubcollections,
      ].sort(),
      missingCanonicalParents: [
        ...this._missingCanonicalParents.values(),
      ].sort((left, right) => left.path.localeCompare(right.path)),
    };
  }

  async listRootCollections() {
    const references = await this._db.listCollections();
    return references.map((reference) => reference.id).sort();
  }

  _remainingLimit() {
    if (!this._maxDocuments) return Number.MAX_SAFE_INTEGER;
    return Math.max(0, this._maxDocuments - this._documentsRead);
  }

  _remainingReferenceLimit() {
    return Math.max(0, this._maxReferences - this._referencesVisited);
  }

  _visitReference() {
    if (this._remainingReferenceLimit() === 0) {
      this._referenceLimitReached = true;
      return false;
    }
    this._referencesVisited += 1;
    return true;
  }

  async _readCollection(reference) {
    const documents = [];
    const snapshots = [];
    let cursor = null;

    while (!this._limitReached) {
      const remaining = this._remainingLimit();
      if (remaining === 0) {
        this._limitReached = true;
        break;
      }

      const limit = Math.min(this._pageSize, remaining);
      let query = reference.orderBy(FieldPath.documentId());
      if (cursor) query = query.startAfter(cursor);
      query = query.limit(limit).select(...AUDIT_FIELD_PATHS);

      const page = await query.get();
      for (const snapshot of page.docs) {
        documents.push({
          id: snapshot.id,
          path: snapshot.ref.path,
          data: snapshot.data() || {},
        });
        snapshots.push(snapshot);
        this._documentsRead += 1;
      }

      if (page.size < limit) break;
      cursor = page.docs[page.docs.length - 1];
      if (this._remainingLimit() === 0) {
        this._limitReached = true;
        break;
      }
    }

    return {documents, snapshots};
  }

  async scanRootCollection(name) {
    return this._readCollection(this._db.collection(name));
  }

  _expectedCanonicalCollections(parentPath) {
    const parts = parentPath.split("/");
    if (parts.length === 2 && parts[0] === "clinicas") {
      return new Set(CANONICAL_CLINIC_COLLECTIONS);
    }
    if (parts.length === 4 && parts[0] === "clinicas" &&
        parts[2] === "pacientes") {
      return new Set(CANONICAL_PATIENT_COLLECTIONS);
    }
    return null;
  }

  _patientIdForDocument(parentPatientId, collection, reference) {
    if (parentPatientId) return parentPatientId;
    const parts = collection.path.split("/");
    if (parts.length === 3 && parts[0] === "clinicas" &&
        parts[2] === "pacientes") {
      return reference.id;
    }
    return "";
  }

  _recordMissingCanonicalParent(reference, context) {
    const parts = reference.path.split("/");
    let kind = "document";
    if (parts.length === 2 && parts[0] === "clinicas") {
      kind = "clinic";
    } else if (parts.length === 4 && parts[0] === "clinicas" &&
        parts[2] === "pacientes") {
      kind = "patient";
    }

    this._missingCanonicalParents.set(reference.path, {
      path: reference.path,
      kind,
      ancestorTenantId: context.tenantId,
      ancestorPatientId: context.patientId,
    });
  }

  _orderedDocumentReferences(references, snapshots) {
    const byPath = new Map();
    for (const reference of references) {
      byPath.set(reference.path, reference);
    }
    for (const snapshot of snapshots) {
      byPath.set(snapshot.ref.path, snapshot.ref);
    }
    return [...byPath.values()].sort((left, right) =>
      left.path.localeCompare(right.path));
  }

  async _listDocumentReferences(collection, snapshots = []) {
    const remaining = this._remainingReferenceLimit();
    if (remaining === 0) {
      this._referenceLimitReached = true;
      return [];
    }

    const listed = await collection.listDocuments();
    this._referencesListed += listed.length;
    const ordered = this._orderedDocumentReferences(listed, snapshots);
    if (ordered.length > remaining) {
      this._referenceLimitReached = true;
    }
    return ordered.slice(0, remaining);
  }

  async _scanCanonicalCollection(collection, context, output) {
    const result = await this._readCollection(collection);
    const snapshotsByPath = new Map(result.snapshots.map((snapshot) => [
      snapshot.ref.path,
      snapshot,
    ]));
    const documentsByPath = new Map(result.documents.map((document) => [
      document.path,
      document,
    ]));

    for (const snapshot of result.snapshots) {
      const patientId = this._patientIdForDocument(
          context.patientId,
          collection,
          snapshot.ref,
      );
      output.push({
        ...documentsByPath.get(snapshot.ref.path),
        collection: collection.id,
        ancestorTenantId: context.tenantId,
        ancestorPatientId: patientId,
      });
    }
    if (this._limitReached) return;

    const references = await this._listDocumentReferences(
        collection,
        result.snapshots,
    );
    for (const reference of references) {
      if (!this._visitReference()) return;
      const patientId = this._patientIdForDocument(
          context.patientId,
          collection,
          reference,
      );
      if (!snapshotsByPath.has(reference.path)) {
        this._recordMissingCanonicalParent(reference, {
          tenantId: context.tenantId,
          patientId,
        });
      }
      await this._scanCanonicalChildren(reference, {
        tenantId: context.tenantId,
        patientId,
        depth: context.depth + 1,
      }, output);
      if (this._limitReached || this._remainingReferenceLimit() === 0) return;
    }
  }

  async _scanCanonicalChildren(parentReference, context, output) {
    const collections = await parentReference.listCollections();
    if (collections.length === 0) return;

    const orderedCollections = [...collections].sort((left, right) =>
      left.path.localeCompare(right.path));
    const expected = this._expectedCanonicalCollections(parentReference.path);
    for (const collection of orderedCollections) {
      if (!expected || !expected.has(collection.id)) {
        this._unknownCanonicalCollections.add(collection.path);
      }
    }

    if (context.depth >= this._maxDepth) {
      this._depthLimitReached = true;
      return;
    }

    for (const collection of orderedCollections) {
      if (this._remainingReferenceLimit() === 0) {
        this._referenceLimitReached = true;
        return;
      }
      await this._scanCanonicalCollection(collection, context, output);
      if (this._limitReached || this._remainingReferenceLimit() === 0) return;
    }
  }

  async scanCanonicalHierarchy(clinicSnapshots) {
    const documents = [];
    const clinicCollection = this._db.collection("clinicas");
    const snapshotsByPath = new Map(clinicSnapshots.map((snapshot) => [
      snapshot.ref.path,
      snapshot,
    ]));
    const ordered = await this._listDocumentReferences(
        clinicCollection,
        clinicSnapshots,
    );

    for (const clinicReference of ordered) {
      if (!this._visitReference()) break;
      if (!snapshotsByPath.has(clinicReference.path)) {
        this._recordMissingCanonicalParent(clinicReference, {
          tenantId: clinicReference.id,
          patientId: "",
        });
      }
      await this._scanCanonicalChildren(clinicReference, {
        tenantId: clinicReference.id,
        patientId: "",
        depth: 0,
      }, documents);
      if (this._limitReached || this._remainingReferenceLimit() === 0) break;
    }
    return documents;
  }

  async _scanLegacyChildren(parentReference, depth) {
    const collections = await parentReference.listCollections();
    if (collections.length === 0) return;

    const orderedCollections = [...collections].sort((left, right) =>
      left.path.localeCompare(right.path));
    for (const collection of orderedCollections) {
      this._unknownLegacySubcollections.add(collection.path);
    }
    if (depth >= this._maxDepth) {
      this._depthLimitReached = true;
      return;
    }

    for (const collection of orderedCollections) {
      if (this._remainingReferenceLimit() === 0) {
        this._referenceLimitReached = true;
        return;
      }
      const references = await this._listDocumentReferences(collection);
      for (const reference of references) {
        if (!this._visitReference()) return;
        await this._scanLegacyChildren(reference, depth + 1);
        if (this._remainingReferenceLimit() === 0) return;
      }
    }
  }

  async scanLegacySubcollections(rootSnapshots) {
    const snapshots = rootSnapshots || {};
    const names = ROOT_COLLECTIONS
        .map((definition) => definition.name)
        .filter((name) => name !== "clinicas")
        .sort();

    for (const name of names) {
      if (this._remainingReferenceLimit() === 0) {
        this._referenceLimitReached = true;
        return;
      }
      const collection = this._db.collection(name);
      const references = await this._listDocumentReferences(
          collection,
          snapshots[name] || [],
      );
      for (const reference of references) {
        if (!this._visitReference()) return;
        await this._scanLegacyChildren(reference, 0);
        if (this._remainingReferenceLimit() === 0) return;
      }
    }
  }

  async listAuthenticationUsers() {
    if (!this._auth) return null;

    const users = [];
    let pageToken;
    do {
      const page = await this._auth.listUsers(1000, pageToken);
      for (const user of page.users) {
        users.push({
          uid: user.uid,
          disabled: user.disabled === true,
          superAdmin: Boolean(
              user.customClaims && user.customClaims.superAdmin === true,
          ),
        });
      }
      pageToken = page.pageToken;
    } while (pageToken);

    users.sort((left, right) => left.uid.localeCompare(right.uid));
    return users;
  }
}

module.exports = {
  FirebaseReadAdapter,
};
