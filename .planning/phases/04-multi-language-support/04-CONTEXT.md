# Phase 4: Multi-Language Support - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Users see all app text in their device language (French or English) without any manual configuration. This phase localizes the Glance, Widget, and phone app settings surfaces. No new features — purely translating and wiring up the existing UI strings.

</domain>

<decisions>
## Implementation Decisions

### Prayer Names
- **D-01:** Prayer names stay universal Arabic: Fajr, Dhuhr, Asr, Maghrib, Isha in both French and English. `PRAYER_LABELS` array in `PrayerLogic.mc` is unchanged — no localization needed for prayer names.

### Countdown Format
- **D-02:** French countdown uses "dans" pattern: `"Asr dans 2h 15m"`, `"Asr dans 45m"`, `"Asr dans 30s"`, `"Asr maintenant"`.
- **D-03:** Tokens to localize: `"in"` → `"dans"`, `"now"` → `"maintenant"`. Time unit suffixes (`h`, `m`, `s`) stay the same in both languages.

### Localization Strategy
- **D-04:** Target `loadResource(Rez.Strings.xxx)` for both Widget AND Glance — unified approach using standard CIQ resource folders (`resources/strings/strings.xml` for English default, `resources-fre/strings/strings.xml` for French).
- **D-05:** Researcher MUST verify Glance memory impact of `loadResource()` in simulator. If 28KB budget is too tight, fall back to hardcoded conditional strings (check `System.getDeviceSettings().systemLanguage`) for Glance only. Widget keeps `loadResource()` regardless.
- **D-06:** Phone app settings localization uses the standard `resources-fre/settings/` and `resources-fre/strings/` folders — automatic via CIQ framework.

### Empty State Wording
- **D-07:** "No mosque configured" messages in French:
  - Glance: `"Mawaqit"` (unchanged) + `"Configurer dans l'app Connect"`
  - Widget: `"Mawaqit"` (unchanged) + `"Configurer la mosquée"` / `"dans Garmin Connect"`
- **D-08:** No-data placeholder localized: `"-- in --"` (EN) → `"-- dans --"` (FR). Consistent with countdown token localization.
- **D-09:** English fallback (LOC-05): any device language other than French shows English text. This is the `resources/strings/strings.xml` default behavior.

### Claude's Discretion
- Settings label French translations (e.g., "Mosque ID" → appropriate French equivalent) — Claude picks natural wording
- Any additional minor UI strings discovered during implementation — Claude translates consistently with the patterns above

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Connect IQ Localization
- [Connect IQ Core Topics - Properties and App Settings](https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/) — How settings.xml and strings.xml localization works
- [Monkey C Annotations](https://developer.garmin.com/connect-iq/monkey-c/annotations/) — (:glance) annotation rules for code availability

### Existing Source (strings to localize)
- `source/PrayerLogic.mc` — `formatCountdown()` at line 268: hardcoded "in", "now", "h", "m", "s" tokens
- `source/MawaqitGlanceView.mc` — Lines 98-108: "Mawaqit", "Set mosque in Connect app"; Lines 267-269: "-- in --"
- `source/MawaqitWidgetView.mc` — Lines 57-75: "Mawaqit", "Set mosque in", "Garmin Connect app"; Lines 243-248: "-- in --"
- `resources/strings/strings.xml` — Current English strings: AppName, MosqueSettingTitle, MosqueSettingPrompt

### Requirements
- `.planning/REQUIREMENTS.md` — LOC-01 through LOC-05 define acceptance criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PrayerLogic.mc` module pattern — (:glance) annotated, contains `formatCountdown()` that needs localization tokens
- `resources/strings/strings.xml` — existing string resource infrastructure, just needs expansion
- `resources/settings/settings.xml` — references string resources, French equivalents auto-loaded from `resources-fre/`

### Established Patterns
- Module pattern (not classes) for (:glance) code — `PrayerLogic` is a module, any string helper should follow same pattern
- Direct `Dc` drawing in views — no XML layouts, strings passed directly to `dc.drawText()`
- `System.getDeviceSettings().systemLanguage` available for runtime language detection if needed as fallback

### Integration Points
- `PrayerLogic.formatCountdown()` — countdown tokens injected here (either via loadResource or conditional)
- `MawaqitGlanceView.onUpdate()` — empty state strings drawn here
- `MawaqitWidgetView.onUpdate()` — empty state strings drawn here
- `resources-fre/` folder — new, needs to be created with French string resources

</code_context>

<specifics>
## Specific Ideas

- French countdown: "Asr dans 2h 15m" (not "Asr en 2h 15m" — "dans" is the natural preposition for time-until)
- "maintenant" for "now" (not "en cours" or other alternatives)
- Empty state instruction: "Configurer dans l'app Connect" (action-oriented, fits Glance width)
- Widget empty state split across two lines: "Configurer la mosquée" / "dans Garmin Connect"

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-multi-language-support*
*Context gathered: 2026-04-12*
