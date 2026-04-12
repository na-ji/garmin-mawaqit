# Phase 4: Multi-Language Support - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 04-multi-language-support
**Areas discussed:** Prayer name handling, Countdown format, Widget localization strategy, Empty state wording

---

## Prayer Name Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Keep Arabic names (Recommended) | Fajr, Dhuhr, Asr, Maghrib, Isha in both languages. Universal across Muslim communities, avoids regional variant debates. | ✓ |
| Use French variants | Translate to French-community equivalents (Sobh, Dohr, Asr, Maghreb, Icha). | |
| Match Mawaqit API names | Use whatever names the Mawaqit API returns for the mosque. | |

**User's choice:** Keep Arabic names — PRAYER_LABELS unchanged.
**Notes:** No follow-up needed. Universal names are the clear choice.

---

## Countdown Format

| Option | Description | Selected |
|--------|-------------|----------|
| "dans" pattern (Recommended) | Direct French: "Asr dans 2h 15m", "Asr maintenant". | ✓ |
| Compact symbol pattern | Language-neutral symbols: "Asr > 2h 15m". | |
| Time-only pattern | Drop connector: "Asr 2h 15m". | |

**User's choice:** "dans" pattern — "in" → "dans", "now" → "maintenant". Time unit suffixes stay the same.
**Notes:** No follow-up needed.

---

## Widget Localization Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| loadResource() (Recommended) | Standard CIQ pattern with resources-fre/ folder. Auto language detect, easy to add languages. | ✓ |
| Hardcoded conditionals | Same as Glance pattern. Check systemLanguage and branch. Consistent but verbose. | |
| Shared helper module | (:glance) annotated Strings module used by both views. Single source of truth. | |

**User's choice:** loadResource() with standard CIQ resource folders.
**Notes:** User asked whether loadResource() could also work in Glances (it can — no API restriction). This led to a follow-up question about Glance strategy.

### Follow-up: Glance Localization Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Try loadResource() everywhere (Recommended) | Target unified approach. Researcher verifies memory impact. Fall back to hardcoded for Glance if needed. | ✓ |
| Play it safe — hardcoded for Glance | Stick with original roadmap decision. Two different patterns. | |

**User's choice:** Try loadResource() everywhere — researcher verifies. This overrides the original roadmap decision "NO loadResource() in Glance".
**Notes:** The original roadmap decision was a cautious assumption, not a tested limitation. User prefers a unified approach with empirical verification.

---

## Empty State Wording

### No Mosque Configured Message

| Option | Description | Selected |
|--------|-------------|----------|
| "Configurer dans l'app Connect" (Recommended) | Direct, natural French. | ✓ |
| "Ouvrir Garmin Connect" | Shorter, action-oriented. | |
| You decide | Let Claude pick during implementation. | |

**User's choice:** "Configurer dans l'app Connect" for Glance, "Configurer la mosquée" / "dans Garmin Connect" for Widget.
**Notes:** No follow-up needed.

### No-Data Placeholder

| Option | Description | Selected |
|--------|-------------|----------|
| Keep "-- in --" in both (Recommended) | Language-neutral symbolic placeholder. | |
| Localize to "-- dans --" | Consistent with countdown token localization. | ✓ |

**User's choice:** Localize the placeholder — "-- dans --" in French for consistency with countdown format.
**Notes:** User prioritized consistency over the "it's just a placeholder" argument.

---

## Claude's Discretion

- Settings label French translations (natural wording at Claude's discretion)
- Minor UI strings discovered during implementation

## Deferred Ideas

None — discussion stayed within phase scope.
