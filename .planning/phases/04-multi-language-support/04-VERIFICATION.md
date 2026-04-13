---
phase: 04-multi-language-support
verified: 2026-04-12T20:30:00Z
status: gaps_found
score: 3/7 must-haves verified
gaps:
  - truth: "French device sees Widget countdown header with 'dans' instead of 'in'"
    status: failed
    reason: "monkey.jungle has no fre.resourcePath entry — resources-fre/ is never compiled into the build. WatchUi.loadResource(Rez.Strings.CountdownIn) in MawaqitWidgetView.mc will always return 'in' (English default) regardless of device language."
    artifacts:
      - path: "monkey.jungle"
        issue: "Missing 'fre.resourcePath = resources-fre;resources-fre/strings' — French resource folder is silently ignored by build system"
      - path: "source/MawaqitWidgetView.mc"
        issue: "loadResource() calls are correct code but receive no French data because monkey.jungle never registers the French resource folder"
    missing:
      - "Add 'fre.resourcePath = resources-fre;resources-fre/strings' to monkey.jungle"

  - truth: "French device sees Widget empty state no-mosque message in French"
    status: failed
    reason: "Same root cause as above — WatchUi.loadResource(Rez.Strings.WidgetNoMosqueLine1) and WidgetNoMosqueLine2 always return English strings because resources-fre/ is excluded from build."
    artifacts:
      - path: "monkey.jungle"
        issue: "Missing fre.resourcePath entry"
    missing:
      - "Fix monkey.jungle (same fix as gap 1 — single root cause)"

  - truth: "French device sees Widget no-data placeholder in French"
    status: failed
    reason: "WatchUi.loadResource(Rez.Strings.NoDataPlaceholder) always returns '-- in --' (English) because resources-fre/ is excluded from build."
    artifacts:
      - path: "monkey.jungle"
        issue: "Missing fre.resourcePath entry"
    missing:
      - "Fix monkey.jungle (same root cause as gaps 1 and 2)"

  - truth: "French device sees phone app settings labels in French"
    status: failed
    reason: "Phone app settings labels (MosqueSettingTitle, MosqueSettingPrompt) are loaded from string resources via @Strings.xxx references in settings.xml. Since monkey.jungle has no fre.resourcePath, the French string overrides in resources-fre/strings/strings.xml are never compiled. French device will show 'Mosque ID' and English prompt instead of 'ID Mosquee'."
    artifacts:
      - path: "monkey.jungle"
        issue: "Missing fre.resourcePath entry means resources-fre/strings/strings.xml is excluded from all builds"
    missing:
      - "Fix monkey.jungle (same root cause — all 4 gaps share this single fix)"
human_verification:
  - test: "Build project after monkey.jungle fix, launch in simulator set to French language"
    expected: "Widget countdown shows 'Asr dans 2h 15m'; no-mosque state shows 'Configurer la mosquee' / 'dans Garmin Connect'; no-data placeholder shows '-- dans --'"
    why_human: "Cannot run Connect IQ simulator build from this verification context. Must verify loadResource() returns French strings after monkey.jungle fix."
  - test: "Check Garmin Connect phone app settings on French device after monkey.jungle fix"
    expected: "Settings title shows 'ID Mosquee', prompt shows French text"
    why_human: "Settings localization requires running app on device or simulator — cannot verify from file inspection."
  - test: "Launch Glance on French device and verify language fallback on getDeviceSettings() null"
    expected: "Glance displays French text normally; does not crash on initialization if getDeviceSettings() is briefly null"
    why_human: "The null-dereference risk on System.getDeviceSettings().systemLanguage (line 96 in MawaqitGlanceView.mc) cannot be reproduced from static analysis alone. Needs real device or simulator stress test."
---

# Phase 04: Multi-Language Support Verification Report

**Phase Goal:** Users see all app text in their device language (French or English) without any manual configuration
**Verified:** 2026-04-12T20:30:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | French device sees Glance countdown with 'dans' instead of 'in' | VERIFIED | MawaqitGlanceView.mc lines 158-163: hardcoded conditional sets tokenIn="dans" when lang == System.LANGUAGE_FRE; passes to formatCountdown() |
| 2 | French device sees Glance empty state in French | VERIFIED | MawaqitGlanceView.mc lines 107-110: hardcoded conditional sets noMosqueText to French string; drawEmptyState() similarly conditioned (lines 278-280) |
| 3 | French device sees phone app settings labels in French | FAILED | resources-fre/strings/strings.xml contains correct translations but monkey.jungle has no fre.resourcePath — file is never compiled into any build |
| 4 | Non-French, non-English device sees all text in English (fallback) | PARTIAL | Glance: works via hardcoded conditionals (defaults to English when lang != LANGUAGE_FRE). Widget: "works" only because loadResource always returns English (monkey.jungle bug makes French unreachable for all devices) |
| 5 | Prayer names remain Fajr, Dhuhr, Asr, Maghrib, Isha in all languages | VERIFIED | PrayerLogic.mc line 22: PRAYER_LABELS = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"] — unchanged, not in any resource file |
| 6 | French device sees Widget countdown header with 'dans' instead of 'in' | FAILED | WatchUi.loadResource(Rez.Strings.CountdownIn) is correctly called at MawaqitWidgetView.mc line 108, but returns English "in" because monkey.jungle excludes resources-fre/ from build |
| 7 | French device sees Widget empty state and no-data placeholder in French | FAILED | loadResource(Rez.Strings.WidgetNoMosqueLine1/Line2/NoDataPlaceholder) correctly called but return English because monkey.jungle excludes French resources |

**Score:** 3/7 truths verified (4 failed, including 1 partial counted as partial)

### Root Cause

All Widget and Settings localization failures share a single root cause: **`monkey.jungle` is missing the `fre.resourcePath` declaration**. The current file:

```
project.manifest = manifest.xml
base.sourcePath = source
base.resourcePath = resources;resources/drawables;resources/settings;resources/strings
```

The `resources-fre/` directory exists and is correctly structured at `resources-fre/strings/strings.xml`, but the Connect IQ build system only discovers language-specific resource folders when they are explicitly declared in `monkey.jungle`. Without `fre.resourcePath = resources-fre;resources-fre/strings`, the French resources are silently excluded from every build target. This was identified as Critical finding CR-01 in the Phase 04 Code Review (04-REVIEW.md).

The fix is a single line addition to monkey.jungle.

### Glance vs Widget Asymmetry

The Glance surface works correctly in French because it uses the D-05 fallback pattern (hardcoded language conditionals via `System.getDeviceSettings().systemLanguage`), which the human checkpoint triggered after `loadResource()` caused an IQ! crash exceeding the 28KB memory budget. This approach does not depend on the resource system and therefore is unaffected by the monkey.jungle bug.

The Widget surface uses `loadResource()` (correct approach for its 64-128KB budget), which depends on the resource system — and therefore is broken by the monkey.jungle bug.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `resources/strings/strings.xml` | English default strings (9 entries) | VERIFIED | All 9 string IDs present: AppName, MosqueSettingTitle, MosqueSettingPrompt, CountdownIn, CountdownNow, GlanceNoMosque, WidgetNoMosqueLine1, WidgetNoMosqueLine2, NoDataPlaceholder |
| `resources-fre/strings/strings.xml` | French overrides (8 entries, no AppName) | VERIFIED | All 8 French overrides present and correct. AppName correctly omitted. |
| `manifest.xml` | Declares fre language | VERIFIED | `<iq:language>fre</iq:language>` present at line 16 |
| `monkey.jungle` | Registers French resource path | FAILED — MISSING | Only has `base.resourcePath`; `fre.resourcePath` declaration absent. French resources are never compiled. |
| `source/PrayerLogic.mc` | formatCountdown accepts tokenIn/tokenNow | VERIFIED | Function signature at line 275: `function formatCountdown(remainingSec as Number, prayerName as String, tokenIn as String, tokenNow as String) as String` |
| `source/MawaqitGlanceView.mc` | Glance displays French via language conditionals | VERIFIED | Uses System.getDeviceSettings().systemLanguage + System.LANGUAGE_FRE for all localizable strings (D-05 fallback, confirmed by human checkpoint) |
| `source/MawaqitWidgetView.mc` | Widget uses loadResource for all display strings | VERIFIED (code) / BROKEN (runtime) | Code correctly calls loadResource for 5 string IDs; broken at runtime because monkey.jungle excludes French resources |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| MawaqitWidgetView.mc | resources/strings/strings.xml | WatchUi.loadResource(Rez.Strings.*) | PARTIAL | Code link exists; runtime link broken — loadResource returns English regardless of device language due to monkey.jungle missing fre.resourcePath |
| MawaqitGlanceView.mc | Language detection | System.getDeviceSettings().systemLanguage | WIRED | Reads systemLanguage and conditionally sets French strings (D-05 fallback pattern) |
| MawaqitWidgetView.mc | PrayerLogic.mc | formatCountdown(remaining, name, tokenIn, tokenNow) | WIRED | All 3 calls pass 4 arguments (lines 113, 115, 117) |
| MawaqitGlanceView.mc | PrayerLogic.mc | formatCountdown(remaining, name, tokenIn, tokenNow) | WIRED | All 3 calls pass 4 arguments (lines 167, 169, 171) |
| manifest.xml | resources-fre/ | iq:language fre declaration | WIRED | `<iq:language>fre</iq:language>` present |
| monkey.jungle | resources-fre/ | fre.resourcePath entry | NOT_WIRED | Missing — this is the critical gap |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| MawaqitWidgetView.mc | tokenIn, tokenNow | WatchUi.loadResource(Rez.Strings.CountdownIn/CountdownNow) | NO — always returns English "in"/"now" | HOLLOW — French resource never compiled |
| MawaqitWidgetView.mc | noMosqueLine1, noMosqueLine2 | WatchUi.loadResource(Rez.Strings.WidgetNoMosqueLine1/Line2) | NO — always English | HOLLOW — same root cause |
| MawaqitWidgetView.mc | placeholderText | WatchUi.loadResource(Rez.Strings.NoDataPlaceholder) | NO — always English | HOLLOW — same root cause |
| MawaqitGlanceView.mc | tokenIn, tokenNow | Hardcoded conditional on System.LANGUAGE_FRE | YES — correct French tokens on French device | FLOWING |
| MawaqitGlanceView.mc | noMosqueText | Hardcoded conditional on System.LANGUAGE_FRE | YES — correct French string on French device | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED — Connect IQ Garmin simulator required to run the app; cannot test loadResource() behavior without building and running on device/simulator.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| LOC-01 | 04-01 | App auto-detects device language and displays UI in French or English | PARTIALLY SATISFIED | Glance: satisfied via hardcoded systemLanguage check. Widget: language detection via loadResource is present in code but silently broken (monkey.jungle). REQUIREMENTS.md marks this complete (checked), but it is not fully functional. |
| LOC-02 | 04-01 | All Glance UI strings display in the detected language | SATISFIED | Glance uses D-05 fallback with hardcoded conditionals — verified working by human checkpoint in Plan 02 |
| LOC-03 | 04-02 | All Widget UI strings display in the detected language | NOT SATISFIED | loadResource() calls are present but return English always due to monkey.jungle missing fre.resourcePath. REQUIREMENTS.md marks this "Pending" — consistent with this finding. |
| LOC-04 | 04-01 | All phone app settings labels display in the detected language | NOT SATISFIED | French string overrides for MosqueSettingTitle/MosqueSettingPrompt are in resources-fre/ but never compiled due to monkey.jungle gap |
| LOC-05 | 04-01 | App falls back to English for non-French/English devices | SATISFIED for Glance; VACUOUSLY TRUE for Widget | Glance: hardcoded conditionals default to English for non-French. Widget: "falls back" to English only because French never works at all |

**Note on REQUIREMENTS.md discrepancy:** LOC-01 and LOC-04 are marked `[x]` (complete) in REQUIREMENTS.md but are not fully satisfied in the codebase due to the monkey.jungle gap. LOC-03 is correctly marked `[ ]` (pending). The traceability table shows LOC-03 "Pending" — accurate. LOC-01 and LOC-04 should be reverted to pending.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| monkey.jungle | N/A — missing line | Missing `fre.resourcePath` declaration | Blocker | All Widget and Settings French localization is dead code — resources-fre/ is never compiled into any build target |
| source/MawaqitGlanceView.mc | 96 | `System.getDeviceSettings().systemLanguage` without null guard | Warning | getDeviceSettings() can return null in glance context; accessing .systemLanguage on null causes an uncatchable VM fault (per project memory: "try/catch can't catch VM faults"). Defaults to English if guarded. |
| source/MawaqitGlanceView.mc | 50, 87, 268 | Redundant `(:glance)` annotations on methods inside a `(:glance)` class | Info | Class-level annotation covers all methods; redundant per-method annotations are noise |
| resources-fre/strings/strings.xml | 4, 5, 15 | Unaccented "mosquee" instead of "mosquée" | Info | Grammatically incorrect French; acceptable for v1.1 but should be fixed before release |

### Human Verification Required

#### 1. Widget French Text After monkey.jungle Fix

**Test:** Add `fre.resourcePath = resources-fre;resources-fre/strings` to monkey.jungle, rebuild, launch in Connect IQ simulator with device language set to French
**Expected:** Widget countdown header shows "Asr dans 2h 15m" (French "dans"); no-mosque state shows "Configurer la mosquee" / "dans Garmin Connect"; no-data placeholder shows "-- dans --"
**Why human:** Cannot invoke Connect IQ build + simulator from static verification. The fix is straightforward but the outcome requires runtime confirmation.

#### 2. Settings Labels in French

**Test:** After monkey.jungle fix and rebuild, open Garmin Connect app settings for the widget on a French-language device or simulator
**Expected:** Setting title shows "ID Mosquee", prompt shows "Entrez le slug de votre mosquee depuis mawaqit.net"
**Why human:** Settings localization requires running the connected app flow — not inspectable from source code alone.

#### 3. Glance Null Safety on getDeviceSettings()

**Test:** Launch Glance view on a device that has just rebooted or is in a low-memory state; observe for crashes
**Expected:** Glance renders correctly (falls back to English) without crashing when getDeviceSettings() returns null
**Why human:** VM faults in Glance context cannot be caught in code or verified statically. Requires device testing with `settings = System.getDeviceSettings(); lang = (settings != null) ? settings.systemLanguage : System.LANGUAGE_ENG` fix applied.

### Gaps Summary

Four truths failed from a single root cause: `monkey.jungle` is missing the `fre.resourcePath` declaration. The entire Widget and Settings French localization is silently non-functional because the Connect IQ build system never sees `resources-fre/strings/strings.xml`.

The Glance surface works correctly in French via the D-05 fallback (hardcoded language conditionals), which was implemented after `loadResource()` crashed the 28KB glance budget during human verification. This path does not go through the resource system and is therefore unaffected.

The single fix required is adding one line to monkey.jungle:
```
fre.resourcePath = resources-fre;resources-fre/strings
```

All 4 failed truths (Widget countdown French, Widget empty states French, Widget no-data placeholder French, Settings labels French) will be resolved by this single change. After applying the fix, human verification is needed to confirm the Widget and Settings surfaces display French text correctly in the simulator.

A secondary issue (null-dereference risk on getDeviceSettings() in GlanceView) should also be fixed for robustness, though it does not affect functional French display under normal conditions.

---

_Verified: 2026-04-12T20:30:00Z_
_Verifier: Claude (gsd-verifier)_
