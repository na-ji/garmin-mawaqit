# Phase 2: Prayer Logic & Glance - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 02-prayer-logic-glance
**Areas discussed:** Glance layout, Countdown format, Prayer transition, Glance empty states

---

## Glance Layout

### Information Hierarchy
User provided a reference screenshot of Garmin's built-in Sunrise glance before the question was presented. The user described their vision directly:

- Top line: "Asr in XXXX" (prayer name + countdown)
- Middle: Progress bar showing the day with multiple segments and a progression marker
- Bottom: Exact time of next prayer

This established the Sunrise glance as the design model for Mawaqit.

### Bar Segments

| Option | Description | Selected |
|--------|-------------|----------|
| 5 prayer segments, colored | Each prayer period gets a distinct color. Active segment highlighted. | ✓ |
| 5 segments, uniform color | All segments same color with gaps. Active segment brighter. | |
| You decide | Claude picks based on Garmin constraints and 28KB budget. | |

**User's choice:** 5 prayer segments, colored
**Notes:** None

### Bottom Times

| Option | Description | Selected |
|--------|-------------|----------|
| Current + next prayer time | Left: just-passed prayer time. Right: next prayer time. Shows the window. | ✓ |
| Next prayer time only | Single time on the left or centered. | |
| Fajr + Isha (day boundaries) | First and last prayer of the day, like sunrise/sunset. | |

**User's choice:** Current + next prayer time
**Notes:** User selected the preview showing "12:30  14:30" flanking the progress bar.

---

## Countdown Format

### Threshold Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Switch to minutes-only (Recommended) | Under 1h: "45m". Under 1m: "<1m". | ✓ (partially) |
| Always Xh Ym | Consistent format even under 1 hour. | |
| You decide | Claude picks best threshold. | |

**User's choice:** Switch to minutes-only
**Notes:** Combined with seconds decision below — under 1 minute shows seconds, not "<1m".

### Seconds Display

| Option | Description | Selected |
|--------|-------------|----------|
| Hours and minutes only (Recommended) | "2h 15m" — matches Sunrise glance. | |
| Add seconds under 1 minute | Normal: "2h 15m". Under 1 min: "45s". | ✓ |
| Always show seconds | "2h 15m 30s" — precise but busy. | |

**User's choice:** Add seconds under 1 minute
**Notes:** Final format: >1h = "Xh Ym", <1h = "Ym", <1m = "Xs"

---

## Prayer Transition

### At Prayer Time

| Option | Description | Selected |
|--------|-------------|----------|
| Immediate flip (Recommended) | Switch to next prayer as soon as time passes. | |
| "Now" window for 15 min | Show "Asr now" for 15 minutes. | |
| "Now" window for 5 min | Show "Asr now" for 5 minutes. | ✓ |

**User's choice:** "Now" window for 5 min
**Notes:** Brief acknowledgment, then forward-looking.

### Overnight (Isha to Fajr)

| Option | Description | Selected |
|--------|-------------|----------|
| Same format, no distinction | "Fajr in 8h 30m" — identical to any other countdown. | ✓ |
| You decide | Claude picks based on progress bar wrapping. | |

**User's choice:** Same format, no distinction
**Notes:** Progress bar naturally communicates the overnight position.

### "Now" Window Display

| Option | Description | Selected |
|--------|-------------|----------|
| Show current prayer + next prayer | Bottom shows "now" prayer time and next prayer time. | |
| You decide | Claude handles the "now" state display. | ✓ |

**User's choice:** You decide
**Notes:** Claude has discretion on how bottom times and progress bar behave during the 5-min "now" window.

---

## Glance Empty States

### No Mosque Configured

| Option | Description | Selected |
|--------|-------------|----------|
| Short message (Recommended) | "Mawaqit" + "Set mosque in Connect app" | ✓ |
| App name + icon only | Just "Mawaqit" with no instructions. | |
| You decide | Claude picks. | |

**User's choice:** Short message
**Notes:** None

### Data Expired/Unavailable

| Option | Description | Selected |
|--------|-------------|----------|
| Show dashes as placeholders (Recommended) | "-- in --" with empty bar and "--:--" times. | ✓ |
| Brief error message | "Mawaqit — No data" breaking visual pattern. | |
| You decide | Claude picks. | |

**User's choice:** Show dashes as placeholders
**Notes:** Maintains the visual structure even without data.

---

## Claude's Discretion

- "Now" window display behavior (bottom times and progress bar during 5-min window)
- Color palette for the 5 prayer-period segments
- Font choices within Garmin's available FONT_* options
- Timer/redraw strategy for countdown updates

## Deferred Ideas

None — discussion stayed within phase scope.
