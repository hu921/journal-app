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
