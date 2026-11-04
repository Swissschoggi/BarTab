# BarTab Versioning Guide

## Overview

BarTab ships three independent artifacts:

| Artifact | Where version lives | Format |
|---|---|---|
| iOS app | `CFBundleShortVersionString` + `CFBundleVersion` in Xcode / Info.plist | `MAJOR.MINOR.PATCH` + integer build |
| Website | `?v=` cache-bust on assets + footer/meta (manual) | `YYYY.MM.DD` or app version |
| Supabase backend | Edge function version (auto) + migration list | Function version integer |

Keep them in sync on every release, but they do not have to move together.

## iOS app versioning

### Marketing version (`CFBundleShortVersionString`)
User-facing version shown in the App Store and in the app.

- Format: `MAJOR.MINOR.PATCH`
- Bump **MAJOR** for breaking changes / major redesigns.
- Bump **MINOR** for new features (new screens, new capabilities).
- Bump **PATCH** for bug fixes and small polish.

Examples: `1.0.0` (launch), `1.1.0` (added price alerts), `1.1.1` (fixed map crash).

### Build number (`CFBundleVersion`)
Internal integer used by App Store Connect to distinguish uploads. **Must increase on every upload**, even for the same marketing version.

- Always use a monotonically increasing integer: `1, 2, 3, …`
- Never reuse a build number that has already been uploaded.
- Recommended scheme: `YYYYMMDDNN` (e.g. `2026102801`) keeps them sortable and unique.

### Xcode steps
1. Select the app target → **General** tab.
2. Set **Version** = `CFBundleShortVersionString` (e.g. `1.2.0`).
3. Set **Build** = `CFBundleVersion` (e.g. `2026102801`).
4. For every new upload, increment **Build** only; bump **Version** when the marketing version changes.

### TestFlight / App Store
- Each uploaded build must have a higher `CFBundleVersion` than the last.
- You can have multiple builds of the same `CFBundleShortVersionString` (e.g. `1.2.0` build 5, 6, 7) during testing.
- Only the final build for a version is submitted for review.

## Website versioning

- Bump the `?v=` query string on `style.css` (and other cached assets) whenever CSS changes, e.g. `style.css?v=3`.
- Update the footer copyright year and any “last updated” dates on legal pages when content changes.
- Keep the website version roughly aligned with the app marketing version for messaging consistency.

## Backend (Supabase) versioning

- **Database migrations**: each migration file is named with a timestamp prefix (`20261028120000_description.sql`). Never edit an applied migration; add a new one.
- **Edge functions**: each deploy creates a new version number automatically. Note the version in the changelog when behavior changes.
- **RLS / policies**: treat policy changes like migrations — additive, never destructive without a backup.

## Changelog

Maintain `CHANGELOG.md` at the repo root using the [Keep a Changelog](https://keepachangelog.com) format:

- Group changes under `Added`, `Changed`, `Fixed`, `Removed`, `Security`.
- Add an `Unreleased` section at the top for work in progress.
- When releasing, rename `Unreleased` to the version number + date.

Example entry:

```markdown
## [1.2.0] - 2026-11-15

### Added
- Price alerts for saved bars
- Live location sharing with friends

### Fixed
- Waitlist duplicate email submissions no longer return 500
```

## Release checklist

1. Bump app marketing version / build number in Xcode.
2. Run the full test suite (unit + UI) on a clean build.
3. Test on a physical device (location, push, auth flows).
4. Update `CHANGELOG.md`: move `Unreleased` → version + date.
5. Deploy backend migrations and edge functions; verify in production.
6. Deploy website (Vercel); verify waitlist end-to-end.
7. Upload build to App Store Connect; submit for review.
8. Tag the git commit: `git tag v1.2.0 && git push --tags`.
9. Update footer/legal “last updated” dates if needed.

## Git tags

Use annotated tags matching the marketing version:

```bash
git tag -a v1.2.0 -m "BarTab 1.2.0"
git push origin v1.2.0
```
