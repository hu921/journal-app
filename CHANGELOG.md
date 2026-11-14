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

## PR #5: Faster typing, logs, photo location, passcode and month scrubber (2026-11-14)

TestFlight: builds 3 to 16 (latest: build 16)

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
- Build number set to 16.

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
