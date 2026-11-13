# Daily Log: Journal

A simple iOS journal app. SwiftUI + SwiftData, synced with iCloud (CloudKit).

## Features
- Many entries per day, each with title, text, date-time and optional location.
- Up to 5 photos and 2 videos per entry.
- List grouped by month, newest first, with day column and thumbnail.
- Search, swipe to delete.
- iCloud sync across your devices.

Requires iOS 17 (iPhone 13 and newer). Xcode 16 or later.

## First-time setup in Xcode
1. Open `DailyJournal.xcodeproj`.
2. Select the **DailyJournal** target > **Signing & Capabilities**.
3. Pick your **Team**.
4. Change **Bundle Identifier** from `com.sarahu.dailyjournal` to your own, e.g. `com.yourname.dailyjournal`.
5. Under **iCloud**, make sure **CloudKit** is checked and the container `iCloud.<your bundle id>` is ticked. Press **+** to create it if missing.
6. Make sure **Background Modes > Remote notifications** and **Push Notifications** are present.
7. Run on your iPhone. Sign in to iCloud on the device.

## Notes
- iCloud sync only works on a real device or a simulator signed in to iCloud.
- Before an App Store release, deploy the CloudKit schema to Production in the CloudKit Console.
- Photos are resized to 2048px to save iCloud space. Videos are stored as picked.
