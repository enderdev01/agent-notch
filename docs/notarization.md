# Signing and notarizing Agent Notch

A notarized DMG opens without the Gatekeeper warning: drag to Applications, open, done. This is the one-time setup;
after it, every release is `scripts/release.sh` with two environment variables.

You need a paid [Apple Developer Program](https://developer.apple.com/programs/enroll/) membership. Only the **Account Holder**
can create *Developer ID* certificates ([Apple's help page](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)).
An *Apple Development* certificate (the kind Xcode creates for free) cannot be used for distribution.

## 1. Create the Developer ID Application certificate

Pick one way.

**In Xcode:** Settings → Accounts → select your team → *Manage Certificates…* → **+** → *Developer ID Application*.

**On the website:**

1. Open a Certificate Signing Request: Keychain Access → Certificate Assistant → *Request a Certificate From a Certificate Authority…*,
   enter your email, choose *Saved to disk*.
2. developer.apple.com → Account → Certificates, Identifiers & Profiles → Certificates → **+** → under *Software* choose
   *Developer ID* → *Developer ID Application*, upload the `.certSigningRequest`, download the `.cer`.
3. Double-click the `.cer` to install it in your login keychain.

Check it is installed:

```sh
security find-identity -v -p codesigning | grep "Developer ID Application"
```

You should see a line like `"Developer ID Application: Your Name (ABCDE12345)"`. The text in quotes is your `DEVELOPER_ID`; the code in
parentheses is your **Team ID** (also under Membership details in your developer account).

Back up the certificate with its private key (Keychain Access → right-click → *Export…* → `.p12`, with a password) and keep it
somewhere safe. Without the private key you cannot sign updates from another Mac.

## 2. Create an app-specific password

Notarization authenticates with your Apple ID plus an app-specific password (not your Apple ID password):
Apple Account → Sign-In and Security → *App-Specific Passwords* → generate one named `agent-notch-notary`. Copy it once;
Apple does not show it again. (An App Store Connect API key also works; see `xcrun notarytool store-credentials --help`.)

## 3. Store the notarytool profile (once)

```sh
xcrun notarytool store-credentials agent-notch --apple-id you@example.com --team-id ABCDE12345
```

Leave `--password` out: the tool asks for it with a hidden prompt, so it never lands in your shell history. It validates the
credentials with Apple before saving them in the keychain. Check later with:

```sh
xcrun notarytool history --keychain-profile agent-notch
```

## 4. Release

```sh
DEVELOPER_ID="Developer ID Application: Your Name (ABCDE12345)" \
NOTARY_PROFILE=agent-notch \
scripts/release.sh
```

Before building, the script checks that the identity is a *Developer ID Application* one and that the profile works, so a typo fails
in seconds, not after a notarization round trip. Then it signs with the hardened runtime and a secure timestamp, builds the DMG,
signs it, submits it to Apple (`notarytool submit --wait`, usually a few minutes), staples the ticket and validates it.

## 5. Check the result

```sh
xcrun stapler validate build/AgentNotch-<version>.dmg
spctl --assess --type open --context context:primary-signature -v build/AgentNotch-<version>.dmg   # should say: accepted, source=Notarized Developer ID
```

The real test is another Mac (or another user account): download the DMG from GitHub, drag the app to Applications and open it.
There should be no "cannot verify" dialog, and the README's "Open Anyway" step disappears. When that works, delete that step from
the README files and the release notes.

## If something fails

- **Rejected or Invalid:** read Apple's log: `xcrun notarytool log <submission-id> --keychain-profile agent-notch`
  (the id is printed by `notarytool submit`). Typical causes: a binary without the hardened runtime or secure timestamp, or signed with the wrong identity.
- **`errSecInternalComponent` while signing:** the keychain is locked or the private key is missing; unlock it or re-import the `.p12`.
- **`hdiutil verify` fails with "Resource temporarily unavailable":** `hdiutil info`, eject our DMG, run the verify again.
