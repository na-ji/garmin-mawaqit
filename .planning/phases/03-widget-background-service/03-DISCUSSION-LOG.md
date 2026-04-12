# Phase 3: Widget & Background Service - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 03-widget-background-service
**Areas discussed:** Widget layout & content, Iqama display format, Progress indicator, Background refresh

---

## Widget Layout & Content

### Widget scope
| Option | Description | Selected |
|--------|-------------|----------|
| All 5 prayers (Recommended) | Widget shows all 5 prayers in a list with the next one highlighted | ✓ |
| Next prayer only | Widget shows only the next prayer, like the Glance but with more detail | |
| Next prayer + context | Next prayer prominent, previous/following shown smaller for context | |

**User's choice:** All 5 prayers
**Notes:** Supersedes PROJECT.md "out of scope" note. Glance covers "next prayer only", Widget provides full schedule.

### Highlighting style
| Option | Description | Selected |
|--------|-------------|----------|
| Bold + accent color (Recommended) | Next prayer row uses bold font and accent color, others white/gray | ✓ |
| Arrow/chevron marker | Small arrow indicator next to active prayer row | |
| Background highlight | Next prayer row gets colored background fill/stripe | |

**User's choice:** Bold + accent color
**Notes:** None

### Countdown display
| Option | Description | Selected |
|--------|-------------|----------|
| Countdown at top (Recommended) | Countdown prominently at top, 5-prayer list below | ✓ |
| Inline with highlighted row | Countdown appears on the highlighted row only | |
| No countdown | Times only, Glance handles countdown | |

**User's choice:** Countdown at top
**Notes:** None

### Empty states
| Option | Description | Selected |
|--------|-------------|----------|
| Match Glance patterns (Recommended) | Same D-09/D-10 logic, adapted for Widget screen | ✓ |
| Widget-specific design | Richer instructions using extra screen space | |
| You decide | Claude picks the approach | |

**User's choice:** Match Glance patterns
**Notes:** Consistent with Glance empty states.

---

## Iqama Display Format

### Iqama format
| Option | Description | Selected |
|--------|-------------|----------|
| Second column (Recommended) | Two columns: prayer time left, iqama time right, absolute times | |
| Offset notation | Raw offset after prayer time (e.g., "+10") | ✓ |
| Below prayer time | Iqama on second line below each prayer | |

**User's choice:** Offset notation
**Notes:** Compact, matches API data format, avoids mental math for absolute times but saves screen space.

### Sunrise inclusion
| Option | Description | Selected |
|--------|-------------|----------|
| Include Sunrise | Show between Fajr and Dhuhr, no iqama | |
| Exclude Sunrise (Recommended) | 5 prayers only, sunrise deferred to v2 (DISP-02) | ✓ |
| You decide | Claude decides based on screen space | |

**User's choice:** Exclude Sunrise
**Notes:** None

---

## Progress Indicator

### Progress style
| Option | Description | Selected |
|--------|-------------|----------|
| Reuse Glance bar (Recommended) | Same 5-segment colored bar between countdown and list | |
| Row highlight only | Highlighted next-prayer row IS the progress indicator | ✓ |
| Circular arc | Curved progress arc around round screen edge | |

**User's choice:** Row highlight only
**Notes:** Simpler, less visual clutter. The bold+accent row serves double duty.

---

## Background Refresh

### Refresh interval
| Option | Description | Selected |
|--------|-------------|----------|
| Every 6 hours (Recommended) | ~4x/day, minimal battery | |
| Every hour | ~24x/day, catches changes faster | |
| Once daily | 1x/day, negligible battery impact | ✓ |
| You decide | Claude picks based on constraints | |

**User's choice:** Once daily
**Notes:** Battery-first approach. 12-month cached calendar means freshness is rarely an issue.

### Setting change behavior
| Option | Description | Selected |
|--------|-------------|----------|
| Immediate fetch (Recommended) | Existing onSettingsChanged() handles it, background just uses current slug | ✓ |
| Force background refresh | Setting change triggers immediate background temporal event too | |

**User's choice:** Immediate fetch
**Notes:** Existing Phase 1 code already handles this. No extra background work needed.

---

## Claude's Discretion

- Accent color choice for highlighted row
- Font choices for Widget layout
- Vertical spacing/positioning on round screen
- Background service error handling/retry logic
- Widget timer strategy for countdown updates

## Deferred Ideas

- Sunrise/Shuruq display — tracked as DISP-02 in v2
- Circular arc progress indicator — interesting but complex
