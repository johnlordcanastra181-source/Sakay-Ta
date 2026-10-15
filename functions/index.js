const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();

/**
 * Validates whether the caller has Super Admin privileges or is initializing the first admin.
 * @param {functions.https.CallableContext} context
 * @returns {Promise<boolean>}
 */
async function verifySuperAdminCaller(context) {
  // If not authenticated, reject unless system bootstrapping (empty admins collection)
  if (!context.auth) {
    const adminSnapshot = await db.collection("admins").limit(1).get();
    if (adminSnapshot.empty) {
      // Bootstrap mode: allow first admin creation when database is fresh
      return true;
    }
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication is required to perform admin management operations."
    );
  }

  const callerUid = context.auth.uid;
  
  // Check custom claims
  if (context.auth.token && (context.auth.token.super_admin === true || context.auth.token.role === "super_admin")) {
    return true;
  }

  // Check Firestore admins collection for caller's role
  const callerDoc = await db.collection("admins").doc(callerUid).get();
  if (callerDoc.exists && callerDoc.data().role === "super_admin") {
    return true;
  }

  // Also check developer root email or system bootstrap
  const callerUser = await auth.getUser(callerUid);
  if (
    callerUser.email === "superadmin@sakayta.ph" ||
    callerUser.email === "admin@sakayta.ph" ||
    callerUser.email === "developer@sakayta.ph"
  ) {
    return true;
  }

  throw new functions.https.HttpsError(
    "permission-denied",
    "Only authorized Super Admins and System Owners can manage administrator accounts."
  );
}

/**
 * Cloud Function: createAdminAccount (HTTPS Callable)
 * Securely creates an admin account in Firebase Authentication and stores the admin
 * profile in Cloud Firestore 'admins' collection. Passwords are NEVER saved to Firestore.
 */
exports.createAdminAccount = functions.https.onCall(async (data, context) => {
  try {
    await verifySuperAdminCaller(context);

    const { name, email, password, role = "admin", status = "active" } = data;

    // 1. Validation
    if (!name || typeof name !== "string" || name.trim().length < 2) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "A valid full name (minimum 2 characters) is required."
      );
    }

    if (!email || typeof email !== "string" || !email.includes("@")) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "A valid email address is required."
      );
    }

    if (!password || typeof password !== "string" || password.length < 6) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "A secure password of at least 6 characters is required."
      );
    }

    const normalizedEmail = email.trim().toLowerCase();
    const cleanName = name.trim();
    const cleanRole = role === "super_admin" ? "super_admin" : "admin";
    const cleanStatus = status === "disabled" ? "disabled" : "active";

    // 2. Check duplicate email in Firebase Authentication
    try {
      const existingAuthUser = await auth.getUserByEmail(normalizedEmail);
      if (existingAuthUser) {
        throw new functions.https.HttpsError(
          "already-exists",
          `An account with email '${normalizedEmail}' already exists in Firebase Authentication.`
        );
      }
    } catch (err) {
      if (err.code !== "auth/user-not-found") {
        throw err;
      }
    }

    // 3. Create user in Firebase Authentication
    const userRecord = await auth.createUser({
      email: normalizedEmail,
      password: password,
      displayName: cleanName,
      disabled: cleanStatus === "disabled",
      emailVerified: true,
    });

    // 4. Set Custom Claims for fast security rule evaluation & RBAC
    await auth.setCustomUserClaims(userRecord.uid, {
      admin: true,
      role: cleanRole,
      super_admin: cleanRole === "super_admin",
    });

    // 5. Store admin profile in Cloud Firestore 'admins' collection (NO PASSWORD STORED)
    const now = admin.firestore.FieldValue.serverTimestamp();
    const adminProfile = {
      uid: userRecord.uid,
      name: cleanName,
      email: normalizedEmail,
      role: cleanRole,
      status: cleanStatus,
      createdAt: now,
      updatedAt: now,
    };

    await db.collection("admins").doc(userRecord.uid).set(adminProfile);

    // Also mirror to 'users' collection for system-wide profile resolution
    await db.collection("users").doc(userRecord.uid).set(
      {
        uid: userRecord.uid,
        name: cleanName,
        email: normalizedEmail,
        role: cleanRole,
        status: cleanStatus,
        updatedAt: now,
      },
      { merge: true }
    );

    return {
      success: true,
      message: `Admin account '${normalizedEmail}' created successfully.`,
      admin: {
        uid: userRecord.uid,
        name: cleanName,
        email: normalizedEmail,
        role: cleanRole,
        status: cleanStatus,
      },
    };
  } catch (error) {
    console.error("Error creating admin account:", error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      "internal",
      error.message || "An unexpected error occurred while creating the admin account."
    );
  }
});

/**
 * Cloud Function: updateAdminStatus (HTTPS Callable)
 * Enables or disables an administrator account in both Firebase Auth and Firestore.
 */
exports.updateAdminStatus = functions.https.onCall(async (data, context) => {
  try {
    await verifySuperAdminCaller(context);

    const { uid, status } = data;
    if (!uid) {
      throw new functions.https.HttpsError("invalid-argument", "Administrator UID is required.");
    }

    const cleanStatus = status === "disabled" ? "disabled" : "active";
    const isDisabled = cleanStatus === "disabled";

    // 1. Update Firebase Authentication
    await auth.updateUser(uid, { disabled: isDisabled });

    // 2. Update Firestore
    const now = admin.firestore.FieldValue.serverTimestamp();
    await db.collection("admins").doc(uid).update({
      status: cleanStatus,
      updatedAt: now,
    });

    await db.collection("users").doc(uid).set(
      {
        status: cleanStatus,
        updatedAt: now,
      },
      { merge: true }
    );

    return {
      success: true,
      uid,
      status: cleanStatus,
      message: `Admin account has been ${isDisabled ? "disabled" : "activated"}.`,
    };
  } catch (error) {
    console.error("Error updating admin status:", error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      "internal",
      error.message || "Failed to update admin account status."
    );
  }
});

/**
 * Cloud Function: deleteAdminAccount (HTTPS Callable)
 * Permanently deletes an administrator from Firebase Authentication and Firestore.
 */
exports.deleteAdminAccount = functions.https.onCall(async (data, context) => {
  try {
    await verifySuperAdminCaller(context);

    const { uid } = data;
    if (!uid) {
      throw new functions.https.HttpsError("invalid-argument", "Administrator UID is required.");
    }

    // 1. Delete from Firebase Authentication
    try {
      await auth.deleteUser(uid);
    } catch (err) {
      console.warn("User may not exist in Firebase Auth or was already removed:", err.message);
    }

    // 2. Delete from Firestore 'admins' and 'users'
    await db.collection("admins").doc(uid).delete();
    await db.collection("users").doc(uid).delete();

    return {
      success: true,
      uid,
      message: `Admin account ${uid} permanently deleted.`,
    };
  } catch (error) {
    console.error("Error deleting admin account:", error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      "internal",
      error.message || "Failed to delete admin account."
    );
  }
});

/**
 * HTTP REST API Endpoint for Developer/Automation tools
 * POST /createAdminAccountRest
 */
exports.createAdminAccountRest = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Developer-Secret");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method Not Allowed. Use POST." });
    return;
  }

  try {
    const { name, email, password, role = "admin", status = "active", developerSecret } = req.body;

    // Check optional developer secret or bearer auth token
    const authHeader = req.headers.authorization || "";
    let isAuthorized = false;

    if (developerSecret && developerSecret === process.env.DEVELOPER_SECRET) {
      isAuthorized = true;
    } else if (authHeader.startsWith("Bearer ")) {
      const idToken = authHeader.split("Bearer ")[1];
      const decoded = await auth.verifyIdToken(idToken);
      if (decoded.super_admin === true || decoded.role === "super_admin") {
        isAuthorized = true;
      }
    } else {
      // Check if bootstrap mode
      const adminSnapshot = await db.collection("admins").limit(1).get();
      if (adminSnapshot.empty) {
        isAuthorized = true;
      }
    }

    if (!isAuthorized) {
      res.status(403).json({ error: "Unauthorized: Invalid credentials or developer token." });
      return;
    }

    if (!name || !email || !password || password.length < 6) {
      res.status(400).json({ error: "Invalid input. name, email, and password (min 6 chars) required." });
      return;
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanRole = role === "super_admin" ? "super_admin" : "admin";
    const cleanStatus = status === "disabled" ? "disabled" : "active";

    const userRecord = await auth.createUser({
      email: cleanEmail,
      password: password,
      displayName: name.trim(),
      disabled: cleanStatus === "disabled",
      emailVerified: true,
    });

    await auth.setCustomUserClaims(userRecord.uid, {
      admin: true,
      role: cleanRole,
      super_admin: cleanRole === "super_admin",
    });

    const now = admin.firestore.FieldValue.serverTimestamp();
    const adminDoc = {
      uid: userRecord.uid,
      name: name.trim(),
      email: cleanEmail,
      role: cleanRole,
      status: cleanStatus,
      createdAt: now,
      updatedAt: now,
    };

    await db.collection("admins").doc(userRecord.uid).set(adminDoc);
    await db.collection("users").doc(userRecord.uid).set(
      {
        uid: userRecord.uid,
        name: name.trim(),
        email: cleanEmail,
        role: cleanRole,
        status: cleanStatus,
        updatedAt: now,
      },
      { merge: true }
    );

    res.status(201).json({
      success: true,
      message: "Admin account created successfully.",
      admin: {
        uid: userRecord.uid,
        name: name.trim(),
        email: cleanEmail,
        role: cleanRole,
        status: cleanStatus,
      },
    });
  } catch (error) {
    console.error("REST create admin error:", error);
    res.status(500).json({ error: error.message || "Failed to create admin account." });
  }
});
