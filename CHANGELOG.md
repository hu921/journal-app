# Changelog

All changes to Daily Log: Journal, grouped by pull request, newest first.

Every new PR adds its own entry at the top of this file.

<!--
Template for a new entry:

## PR #N: Title (YYYY-MM-DD)

TestFlight: build N

- Change one
- Change two
-->

## PR #8: Add Google Drive backup and restore (2026-11-14)

TestFlight: builds 22 to 26 (latest: build 26)

- New Settings > Backup screen. iCloud sync stays always on.
- Turn on Google Drive backup; it asks you to sign in to Google.
- Backs up automatically when you add entries and leave the app, or tap Back Up Now. Keeps the last 5 backups in a "Daily Log Backups" folder.
- Restore from a Drive backup. Entries you already have are skipped.
- Needs a Google client ID in the build (see google-drive-setup.md).
- Logs list is more compact: date, title and photo only (no time or place line).
- Google Drive switch explains when sign-in isn't set up yet, instead of doing nothing.
- Lower memory use: thumbnails decode at small size, the cache is capped at 40 MB and cleared in the background.
- Logs record tab switches with memory use.
- Backup: iCloud Sync is a switch (on by default; turning off applies after reopening). Google Drive shows "Signed in as" your email.
- Settings shows "Sync: On" (opens the Sync page) and "Last Sync" with the date and time of the latest iCloud sync or Google Drive backup.
- Build number set to 26.

## PR #7: Add About Me page (2026-11-14)

TestFlight: builds 19 to 21 (latest: build 21)

- Profile is now About Me, like the first page of a paper diary. Only filled-in items show.
- Photo, nickname, birthday with zodiac sign, optional gender.
- Favorites: food, color, song, movie, book, place, season.
- Three words that describe me.
- Right now: mood, what I'm into, this year's goals. Save them to a time capsule; a reminder shows after a year.
- Favorite quote and a signature drawn with your finger.
- New iCloud fields: deploy the CloudKit schema before TestFlight.
- Coming back to the app after a minute or more opens Logs at the top. An entry being written stays open.
- About shows the app version and a Contact row (email to be added).
- Build number set to 21.

## PR #5: Faster typing, logs, photo location, passcode and month scrubber (2026-11-14)

TestFlight: builds 3 to 18 (latest: build 18)

- Typing and scrolling are faster with a large journal (editor saves on Done, thumbnails cached, Map and Stats load only when opened).
- Fixed the new entry editor closing and reopening while typing.
- In-app logs with crash capture. Settings > About > Share Logs.
- Adding photos asks "Use photo's date, time and location?". No automatic current location.
- Pick a location by search or "Use Current Location". Date, time and location can always be changed.
- List screen titled "Daily Log".
- Original wording and stats layout.
- Passcode lock (4 digits) with Face ID. Locks when you leave the app. Forgot passcode uses the iPhone passcode.
- Calendar opens at the current month, with a Today button.
- Month scrubber on Calendar and List: drag the handle on the right edge to jump between months, with year marks.
- Lock cover no longer shows after a screenshot or when Control Center opens.
- Map opens at your current location, with a button to return to it. Falls back to showing all entries if location is off.
- Face ID now starts as soon as you return to the app, instead of failing in the background. Failed checks are logged.
- Tabs renamed: List is now Logs, Calendar is now Days.
- New app icon: a white page with an orange ribbon on a warm gradient.
- Profile: gender and birthday are one-line rows. Tap to change. Gender options: Female, Male, Non-binary, Prefer not to say.
- Build number set to 18.

## PR #2: Add Import / Export (2026-11-13)

TestFlight: build 2

- Import a Day One JSON `.zip` in the background with a progress bar.
- Import keeps up to 5 photos and 2 videos per entry and skips entries already imported.
- Export all entries or a date range as JSON (`.zip`), plain text (`.zip`), CSV, or PDF.
- Share an export or save it to Files.
- Added ZIPFoundation through Swift Package Manager.
- Build number set to 2.

## PR #1: Add calendar, map, stats, profile and settings (2026-11-13)

TestFlight: build 1

- Calendar tab shows a photo or dot on days with entries. Tap a day to see or add entries.
- Map tab pins entries that have a location.
- Stats tab shows streak, entries, days, media and on this day.
- Profile page (first name, last name, gender, birthday), synced with iCloud.
- Profile icon on each tab opens Settings.
- Settings: Profile, Appearance, Import/Export placeholder, About.
- Appearance: theme (system, light, dark), font (System, Roboto, Helvetica Neue, Lato, Open Sans), font size, auto title from first line, photos in calendar.
- Bundled Roboto, Lato and Open Sans fonts with their SIL Open Font License files.
- Bundle ID `com.sarahu.dailyjournal` and matching iCloud container.
- Development team set for signing.
- App icon and encryption export flag for TestFlight.
- App renamed to "Daily Log: Journal".

## Initial commit (2026-11-13)

Not uploaded to TestFlight.

- SwiftUI app with SwiftData and iCloud sync.
- Entries list grouped by month, newest first.
- Multiple entries per day, each with up to 5 photos and 2 videos.
- Optional location on each entry.
