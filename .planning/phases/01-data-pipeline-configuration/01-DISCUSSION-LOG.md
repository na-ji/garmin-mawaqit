# Phase 1: Data Pipeline & Configuration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-10
**Phase:** 01-data-pipeline-configuration
**Areas discussed:** API response & data model, First-launch experience, Stale data policy

---

## API Response & Data Model

| Option | Description | Selected |
|--------|-------------|----------|
| Prayer times only | Store just the 5 prayer times + iqama times + date. Minimal footprint. | |
| Times + mosque name | Also store mosque name for potential Widget header display. | |
| Full metadata | Store everything the API returns — future-proofs but heavier. | |

**User's choice:** Full metadata (with clarification — see follow-up)
**Notes:** User specified "Store all the prayer times: the one for current day + the full calendar."

---

| Option | Description | Selected |
|--------|-------------|----------|
| Store full calendar | Keep whatever the API returns (month/year). More offline resilience. | :heavy_check_mark: |
| Store a rolling week | Trim to ~7 days. Good buffer without heavy storage. | |
| Store two days only | Minimum for Isha-to-Fajr rollover. Lightest storage. | |

**User's choice:** Store full calendar
**Notes:** "It's less than 36kb, so it's worth keeping."

---

| Option | Description | Selected |
|--------|-------------|----------|
| Prayer-relevant fields | calendar, iqamaCalendar, times, shuruq, jumua, name, timezone, hijriAdjustment. Skip images/announcements/facilities. | :heavy_check_mark: |
| Entire rawdata blob | Store everything the API returns including images, URLs, facility flags. | |

**User's choice:** Prayer-relevant fields
**Notes:** Refined from initial "full metadata" — full calendar yes, but only prayer-relevant fields, not announcements/images/facility data.

---

## First-Launch Experience

| Option | Description | Selected |
|--------|-------------|----------|
| Default mosque pre-filled | Ship with a default slug. App works out of the box. | |
| "Configure mosque" message | Show a setup prompt. No data until configured. | |
| Empty state with instructions | Normal layout with placeholder dashes and brief instruction. | :heavy_check_mark: |

**User's choice:** Empty state with instructions
**Notes:** Show the normal layout structure with dashes and a brief message to configure via Garmin Connect.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Empty by default | No pre-filled slug. User must enter their own. | :heavy_check_mark: |
| Example slug pre-filled | Pre-fill with tawba-bussy-saint-georges as starting point. | |

**User's choice:** Empty by default
**Notes:** Avoids confusion about whose mosque data they're seeing.

---

## Stale Data Policy

| Option | Description | Selected |
|--------|-------------|----------|
| Always show cached, no warning | Display cached data without staleness indicator. Simplest UX. | :heavy_check_mark: |
| Show cached with age indicator | Subtle "Last updated X days ago" indicator. | |
| Show cached, warn after threshold | Normal display but warn after configurable period (e.g., 30 days). | |

**User's choice:** Always show cached, no warning
**Notes:** With full 12-month calendar, times are accurate for months. No need to worry the user.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Show last known times | Keep showing most recent day's times from cache. Slightly off seasonally but useful. | |
| Show empty state | Switch to no-data empty state when calendar fully expires. | :heavy_check_mark: |

**User's choice:** Show empty state
**Notes:** When cached calendar has no entry for current date and no future data, show empty state rather than extrapolating.

---

## Claude's Discretion

- Error communication strategy (bad slug, API down, no BLE) — level of detail shown to user
- Storage key structure in Application.Storage
- HTTP request configuration (headers, timeouts, retries)

## Deferred Ideas

None — discussion stayed within phase scope.
