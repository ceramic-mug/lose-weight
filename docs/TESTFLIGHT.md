# Testing on your iPhone with TestFlight

The **TestFlight** workflow builds the app on a cloud Mac and uploads it to TestFlight. It also handles Apple setup:
- It registers the app ID (default `com.ceramicmug.loseweight`) and turns on HealthKit.
- It finds your Team ID.
- It signs the app.

## You need these GitHub secrets
Add them under **Settings › Secrets and variables › Actions** on the GitHub website.

| Secret | Where to get it |
|---|---|
| `ASC_KEY_ID` | App Store Connect › Users and Access › Integrations › Team Keys. Create the key with **Admin** access. |
| `ASC_ISSUER_ID` | Shown above that key list |
| `ASC_KEY_P8` | Full text of the downloaded `.p8` file, including the BEGIN/END lines |
| `BUNDLE_ID` *(optional)* | Overrides `com.ceramicmug.loseweight` |
| `APPLE_TEAM_ID` *(optional)* | Found automatically if you leave it out |

## Steps
1. In the GitHub app or on the website, go to **Actions › TestFlight › Run workflow**.
2. **First run only:** the run stops at **Apple setup** and asks you to create the app.
   1. In App Store Connect, go to **Apps › + › New App**.
   2. **Platform:** iOS. **Bundle ID:** the one the message names. **Name:** anything unique. **SKU:** anything.
   3. Run the workflow again.
3. When the run is green, open **TestFlight** in App Store Connect. The first time, add yourself to an **Internal Testing** group.
4. Install the **TestFlight** app on your iPhone and install Lose Weight from it. Later builds update automatically.

TestFlight builds store data on the phone only. iCloud sync between iPhone and Mac is off until an iCloud container is set up.

## If a step fails
- **Check secrets:** a secret is missing or misnamed.
- **Apple setup:** the message says what to fix. Usually it's the key's role (it must be Admin) or a missing app record.
- **Archive or Upload:** a signing or App Store Connect problem. Share the run link and Claude can read the log.
