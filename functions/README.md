# Sakay Ta - Developer-Controlled Admin Account Management

This directory contains the Firebase Cloud Functions backend and developer CLI tools for managing administrator accounts for the **Sakay Ta Flutter Web Admin Portal**.

---

## 🔒 Security Architecture

1. **No Public Admin Self-Registration**:
   - The Flutter Web Admin Portal strictly permits existing administrators to sign in.
   - There is no public sign-up or open registration link.
   - All administrator accounts are created and provisioned directly by the developer / system owner.

2. **Firebase Authentication Credentials**:
   - The developer chooses and enters the administrator's chosen full name, email address, password, role, and initial status (Active/Disabled).
   - Firebase Authentication creates and secures the administrator's credentials.
   - Custom claims (`admin: true`, `role: 'super_admin' | 'admin'`) are set on the Auth record.

3. **Cloud Firestore Profile (`admins/{uid}`)**:
   - The admin profile is stored in the existing Cloud Firestore database under `admins/{uid}`, using the Firebase Authentication UID as the document ID.
   - Profile fields:
     - `uid`: Firebase Authentication UID
     - `name`: Full Name
     - `email`: Email Address
     - `role`: `'super_admin'` or `'admin'`
     - `status`: `'active'` or `'disabled'`
     - `createdAt`: Timestamp
     - `updatedAt`: Timestamp
   - **CRITICAL SECURITY GUARANTEE**: Passwords are used solely for Firebase Authentication user creation and are **NEVER** stored in Cloud Firestore.

4. **Instant Sign-In**:
   - As soon as the developer creates the account, the administrator can immediately sign in to the Flutter Web Admin Portal using the email and password provided by the developer, without any further registration or verification steps.

---

## 🛠️ Workflows

### Option 1: Using the Flutter Web Admin Portal UI

1. Open the Flutter Web Admin Portal and sign in with your Super Admin account.
2. From the navigation sidebar, select **Admin Accounts**.
3. Click the **Create Admin Account** button at the top right.
4. In the dialog, enter:
   - **Full Name**: e.g. `Maria Clara Santos`
   - **Email Address**: e.g. `maria.santos@sakayta.ph`
   - **Password**: Secure password (at least 6 characters)
   - **Administrator Role**: `Super Admin` (full system access) or `Admin / Staff` (operations & verification)
   - **Initial Status**: `Active` (can sign in immediately) or `Disabled` (blocked until activated)
   - **Department / Unit**: e.g. `Operations`, `Compliance`
5. Click **Create Admin Account**.
6. A **Credential Handover Modal** will appear showing the created details. Click **Copy Credentials** to copy a pre-formatted message with login instructions to provide securely to the administrator.

### Option 2: Using the Developer CLI Tool

You can also provision administrator accounts directly from your command line:

```bash
# Navigate to the functions directory
cd functions

# Run interactively (prompts for name, email, password, role)
npm run create-admin

# Or run with command-line flags:
node create-admin-cli.js --name "Jose Rizal" --email "jose.rizal@sakayta.ph" --password "SecurePassword123!" --role "super_admin" --status "active"
```

### Option 3: Deploying Firebase Cloud Functions

To deploy the functions to your existing Firebase project (`sakay-ta`):

```bash
# Install dependencies
cd functions
npm install

# Deploy Cloud Functions
firebase deploy --only functions
```

Deployed Callable Functions:
- `createAdminAccount`: Secure HTTPS callable endpoint (Super Admin authorized).
- `updateAdminStatus`: Activate or deactivate an administrator.
- `deleteAdminAccount`: Permanently delete an administrator.
- `createAdminAccountRest`: REST endpoint for CI/CD or automation scripts.
