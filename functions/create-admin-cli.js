#!/usr/bin/env node

/**
 * Sakay Ta - Developer Admin Account Provisioning CLI
 * 
 * Secure developer-only script to create administrator accounts directly in
 * Firebase Authentication and Cloud Firestore using the Firebase Admin SDK.
 * 
 * Usage:
 *   node create-admin-cli.js --name "Admin Name" --email "admin@sakayta.ph" --password "Password123" --role "super_admin"
 * 
 * Or run interactively:
 *   npm run create-admin
 */

const readline = require("readline");
const path = require("path");
const fs = require("fs");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
function initFirebase() {
  if (admin.apps.length > 0) return;

  const serviceAccountArg = getArgValue("--service-account") || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (serviceAccountArg && fs.existsSync(serviceAccountArg)) {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountArg, "utf8"));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id || "sakay-ta",
    });
    console.log(`[INFO] Initialized Firebase Admin using service account: ${serviceAccountArg}`);
  } else {
    // Check if local serviceAccountKey.json exists in functions directory
    const localKeyPath = path.join(__dirname, "serviceAccountKey.json");
    if (fs.existsSync(localKeyPath)) {
      const serviceAccount = JSON.parse(fs.readFileSync(localKeyPath, "utf8"));
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: serviceAccount.project_id || "sakay-ta",
      });
      console.log(`[INFO] Initialized Firebase Admin using local serviceAccountKey.json`);
    } else {
      // Default to Application Default Credentials or standard project config
      admin.initializeApp({
        projectId: "sakay-ta",
      });
      console.log(`[INFO] Initialized Firebase Admin with default credentials for project 'sakay-ta'`);
    }
  }
}

function getArgValue(flag) {
  const index = process.argv.indexOf(flag);
  if (index !== -1 && index + 1 < process.argv.length) {
    return process.argv[index + 1];
  }
  return null;
}

function askQuestion(query) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) => {
    rl.question(query, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

async function main() {
  console.log("\n=======================================================");
  console.log("   Sakay Ta - Developer Admin Account Creator CLI     ");
  console.log("=======================================================\n");

  try {
    initFirebase();
  } catch (err) {
    console.error("[ERROR] Failed to initialize Firebase Admin SDK:", err.message);
    console.error("\nPlease make sure you have either:");
    console.error("1. Placed 'serviceAccountKey.json' in the functions directory, or");
    console.error("2. Set the GOOGLE_APPLICATION_CREDENTIALS environment variable, or");
    console.error("3. Logged in with 'gcloud auth application-default login'.\n");
    process.exit(1);
  }

  const auth = admin.auth();
  const db = admin.firestore();

  // Read arguments or prompt interactively
  let name = getArgValue("--name");
  let email = getArgValue("--email");
  let password = getArgValue("--password");
  let role = getArgValue("--role");
  let status = getArgValue("--status") || "active";

  if (!name) {
    name = await askQuestion("Enter Administrator Full Name: ");
  }
  if (!email) {
    email = await askQuestion("Enter Administrator Email: ");
  }
  if (!password) {
    password = await askQuestion("Enter Administrator Password (min 6 characters): ");
  }
  if (!role) {
    const roleChoice = await askQuestion("Select Role (1 for 'super_admin', 2 for 'admin') [default: 2]: ");
    role = roleChoice === "1" ? "super_admin" : "admin";
  }

  // Validate inputs
  if (!name || name.length < 2) {
    console.error("[ERROR] Name must be at least 2 characters long.");
    process.exit(1);
  }
  if (!email || !email.includes("@")) {
    console.error("[ERROR] A valid email address is required.");
    process.exit(1);
  }
  if (!password || password.length < 6) {
    console.error("[ERROR] Password must be at least 6 characters long.");
    process.exit(1);
  }

  const normalizedEmail = email.trim().toLowerCase();
  const cleanName = name.trim();
  const cleanRole = role === "super_admin" ? "super_admin" : "admin";
  const cleanStatus = status === "disabled" ? "disabled" : "active";

  console.log("\nProvisioning administrator account...");
  console.log(`- Name:     ${cleanName}`);
  console.log(`- Email:    ${normalizedEmail}`);
  console.log(`- Role:     ${cleanRole}`);
  console.log(`- Status:   ${cleanStatus}`);

  try {
    // 1. Check if user already exists
    try {
      const existing = await auth.getUserByEmail(normalizedEmail);
      if (existing) {
        console.error(`\n[ERROR] An account with email '${normalizedEmail}' already exists (UID: ${existing.uid}).`);
        process.exit(1);
      }
    } catch (err) {
      if (err.code !== "auth/user-not-found") throw err;
    }

    // 2. Create in Firebase Authentication
    const userRecord = await auth.createUser({
      email: normalizedEmail,
      password: password,
      displayName: cleanName,
      disabled: cleanStatus === "disabled",
      emailVerified: true,
    });

    console.log(`[OK] Firebase Auth user created (UID: ${userRecord.uid})`);

    // 3. Set Custom User Claims
    await auth.setCustomUserClaims(userRecord.uid, {
      admin: true,
      role: cleanRole,
      super_admin: cleanRole === "super_admin",
    });
    console.log(`[OK] Custom claims assigned (role: ${cleanRole})`);

    // 4. Create Firestore Admin Profile (Never store password in Firestore!)
    const now = admin.firestore.FieldValue.serverTimestamp();
    const adminData = {
      uid: userRecord.uid,
      name: cleanName,
      email: normalizedEmail,
      role: cleanRole,
      status: cleanStatus,
      createdAt: now,
      updatedAt: now,
    };

    await db.collection("admins").doc(userRecord.uid).set(adminData);
    console.log(`[OK] Firestore profile saved to 'admins/${userRecord.uid}'`);

    // 5. Mirror to 'users' collection
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
    console.log(`[OK] Mirrored to 'users/${userRecord.uid}' collection`);

    console.log("\n=======================================================");
    console.log("   ADMIN ACCOUNT CREATED SUCCESSFULLY!                ");
    console.log("=======================================================");
    console.log(`UID:      ${userRecord.uid}`);
    console.log(`Email:    ${normalizedEmail}`);
    console.log(`Role:     ${cleanRole}`);
    console.log(`Status:   ${cleanStatus}`);
    console.log("-------------------------------------------------------");
    console.log("The administrator can now sign in directly at the");
    console.log("Sakay Ta Flutter Web Admin Portal using these credentials.");
    console.log("=======================================================\n");

    process.exit(0);
  } catch (error) {
    console.error("\n[FAILED] Error creating administrator account:", error);
    process.exit(1);
  }
}

main();
