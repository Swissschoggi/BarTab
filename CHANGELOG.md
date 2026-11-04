# Changelog

All notable changes to BarTab are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.1] - 2026-10-28

### Changed
- Made "For you" deals togglable instead of always visible
- Fixed badge wrapping in Discovery
- Show stale prices on the map
- Improved Bars tab search and parity with Drinks tab

## [1.1.0] - 2026-10-28

### Added
- Price alerts for saved bars
- Live location sharing with friends
- Groups, polls, and events
- "For you" feed of personalized drink deals
- Best-value sort in Discovery
- Price freshness decay (stale prices dimmed)
- Proximity check for bar check-ins

### Changed
- Waitlist signups now route through a same-origin Vercel function to avoid CORS

### Fixed
- Waitlist duplicate email submissions no longer return HTTP 500
- Screenshot references corrected to `.png`

## [1.0.0] - 2026-09-23

### Added
- Initial iOS app: bar discovery, drink prices, price submission
- Crowdsourced price verification
- User profiles, follows, and bar ratings
- Supabase backend with Row-Level Security
- Marketing website with waitlist signup
