# Turning on iCloud sync (one time)

iPhone and Mac sync through iCloud. Before that can work, iCloud needs the app's database layout (the "schema"). TestFlight builds can't create it, so a special **Sync setup** Mac app, built in the cloud, does it once. No Xcode needed.

## 1. Find your Mac's ID
On the Mac, go to  › **About This Mac** › **More Info…** › **System Report…** (or hold ⌥ Option and click  › **System Information**). Under **Hardware**, copy **Provisioning UDID**.

## 2. Build the helper
In the GitHub app or on github.com, go to **Actions › Sync setup (Mac) › Run workflow** and paste the Provisioning UDID. It takes about 10 minutes. (You can also send the ID to Claude to run it.)

## 3. Run it on the Mac
1. Open the finished run on github.com from the Mac, and download **Sensible-SyncSetup** under *Artifacts*. Unzip it.
2. Open **LoseWeight.app**. macOS will block it the first time because it isn't from the App Store. Go to **System Settings › Privacy & Security**, click **Open Anyway**, and confirm.
3. Make sure the Mac is signed in to iCloud. The app uploads a few sample records, removes them, and says **Done**.

## 4. Deploy the layout
Click **Open CloudKit Console** (or go to icloud.developer.apple.com). Choose **CloudKit Database**, select the container `iCloud.com.ceramicmug.loseweight`, click **Deploy Schema Changes**, and confirm with **Deploy**.

## 5. Check
Open Sensible from TestFlight on the iPhone and the Mac. Within a minute or two, **Settings › Your data › Sync** should read "iCloud · just now", and entries logged on one device should show up on the other.

You can delete the helper app afterwards. If the data model gains new fields later, repeat steps 2–4.
