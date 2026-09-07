# Android installation conflict · recovery edition 3.5.1

The APKs previously delivered used ephemeral debug signing keys. The source workflow retained no private keys. A new signature cannot update those old installs, and a certificate extracted from an APK is not the signing private key.

## Immediate non-destructive path
The recovery APK is named **Sauna Stilo Nueva**, with package **com.saunastilo.personal**. It installs alongside **com.saunastylo.saunastylo**. This is a separate installation, NOT a migration or in-place update. The original app and its local-only data remain untouched. Sign in with the existing account to consult server-held data. Old drafts, preferences and locally stored course progress do not automatically move.

The package utility verifies the SHA-256 of the exact reviewed 3.5.0 APK, changes only manifest identity, provider authorities, the app-specific signature permission, label and version, and verifies that every DEX, native library, Flutter asset and other payload file is unchanged. MainActivity retains its original fully qualified class. Android's own zipalign and apksigner verify the result. This does not change business records, Firebase rules, zones, roles, billing, alerts or the web app.

Firebase resources remain those of the existing app. Native Firebase initialization and package/API restrictions are checked in the emulator; a complete real-account sign-in, notifications and uploads still require acceptance on staff phones. Before a long-term native distribution, register the recovery package and its certificate in the project's Firebase/Google configuration where required. Do not claim Play Store approval, all-phone certification or offline draft migration.

## Retain the signing identity
The recovery signing private key and its password are generated once in a temporary directory and exported only inside an RSA-OAEP/AES-GCM envelope encrypted to the owner's transport public key. No plaintext private signing key or password is committed or uploaded to public Actions artifacts. The receiving private transport key stays outside GitHub. Deliver the decrypted signing backup privately to the owner for secure retention; never share it with staff together with the APK. Future recovery updates require this same retained key and package ID.

Ordinary main pushes no longer generate fresh debug-signed APKs. The normal Android release workflow is manual and refuses to build or distribute without protected signing secrets and the expected public fingerprint. Its default application ID is still the legacy ID: do NOT configure the recovery key for that legacy identity or call it an update. Register/configure the new Firebase package and matching build variant for future recovery source builds. The unavailable legacy key cannot be repaired by renaming an APK file.

## Required evidence
Run the recovery workflow on an isolated emulator only. Install the legacy APK; create a synthetic private-data marker; install the recovery APK without uninstalling; launch it; verify both packages and the old marker; install a test higher version with the SAME new signing key and verify its data marker persists. No real employees, alarms or attendance records are used. Keep the resulting signature, manifest and device-test report with the release. Remove the one-time recovery-generation workflow after handoff so it cannot accidentally mint another key.
