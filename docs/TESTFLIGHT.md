# Testing on your iPhone with TestFlight

You can do all of this from a phone browser. No Mac needed.

## One-time setup

### 1. Join the Apple Developer Program
At **developer.apple.com/programs**, enroll ($99/year). Approval can take up to 48 hours.

### 2. Register the app ID
On developer.apple.com, go to **Account › Certificates, IDs & Profiles › Identifiers › +**, then:
1. Choose **App IDs › App**.
2. **Bundle ID (explicit):** for example `com.yourname.loseweight`.
3. **Capabilities:** tick **HealthKit**, **iCloud** (choose *Include CloudKit support*) and **Push Notifications**.
4. Save. Then open **Identifiers**, switch the filter to **iCloud Containers**, tap **+** and create `iCloud.com.yourname.loseweight` (use your bundle ID after `iCloud.`).
5. Go back to your App ID and, under **iCloud › Edit**, select that container.

### 3. Create the app in App Store Connect
At **appstoreconnect.apple.com**, go to **Apps › + › New App**:
- **Platform:** iOS
- **Name:** anything unique, for example "Lose Weight – Yourname"
- **Bundle ID:** the one from step 2
- **SKU:** anything, for example `loseweight`

### 4. Create an API key
In App Store Connect, go to **Users and Access › Integrations › App Store Connect API › Team Keys › +**:
1. **Access:** Admin. Admin is needed so the build can create its own signing certificate.
2. Note the **Key ID** and the **Issuer ID** shown above the list.
3. **Download** the key. It's a `.p8` file and can only be downloaded once.

To copy the key's text on an iPhone:
1. In the Files app, rename `AuthKey_XXXX.p8` to `AuthKey_XXXX.txt`.
2. Open it, select all and copy.

You can delete the file afterwards.

### 5. Find your Team ID
On developer.apple.com, it's under **Account › Membership details**. It's 10 characters long.

### 6. Add secrets to GitHub
On github.com (in the browser, not the app), open the repo and go to **Settings › Secrets and variables › Actions › New repository secret**. Add:

| Name | Value |
|---|---|
| `BUNDLE_ID` | your bundle ID, for example `com.yourname.loseweight` |
| `APPLE_TEAM_ID` | your Team ID |
| `ASC_KEY_ID` | the Key ID |
| `ASC_ISSUER_ID` | the Issuer ID |
| `ASC_KEY_P8` | the full key text, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |

## Each time you want a new build

1. In the GitHub app or on the website, open the repo and go to **Actions › TestFlight › Run workflow**. It takes about 10–15 minutes.
2. In App Store Connect, open **TestFlight**. The build shows up after Apple finishes processing it, usually 5–30 minutes later.
3. The first time only:
   1. Create an **Internal Testing** group and add yourself.
   2. Answer the export-compliance question if it's asked. The app doesn't use encryption beyond what iOS provides.
4. Install the **TestFlight** app from the App Store, then install Lose Weight from it. New builds then arrive automatically.

The **Run workflow** button only appears once the workflow file is on the repo's default branch (`main`).

## If something fails

Open the failed run in **Actions** and look at the step that went red:
- **Check secrets:** one of the secrets above is missing.
- **Archive:** usually a signing problem. Check that the bundle ID, capabilities and iCloud container match step 2.
- **Upload to TestFlight:** the app record from step 3 doesn't exist, or the API key's role isn't Admin.
