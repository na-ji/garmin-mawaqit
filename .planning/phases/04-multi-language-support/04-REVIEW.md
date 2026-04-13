---
phase: 04-multi-language-support
reviewed: 2026-04-12T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - manifest.xml
  - resources-fre/strings/strings.xml
  - resources/strings/strings.xml
  - source/MawaqitGlanceView.mc
  - source/MawaqitWidgetView.mc
  - source/PrayerLogic.mc
findings:
  critical: 1
  warning: 2
  info: 3
  total: 6
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-04-12T00:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

This phase added French/English localization to the Garmin Mawaqit widget. The design correctly splits strategy by memory context: `loadResource()` in the full widget view (64-128KB budget) and hardcoded language conditionals in the glance view (28KB budget). The string IDs are consistent across both resource files and their usage in source code.

One critical issue was found: the French resource directory `resources-fre/` is never registered in `monkey.jungle`, meaning the Connect IQ build system will never include French strings in any build — the entire localization is silently non-functional.

Two warnings cover a potential crash when `getDeviceSettings()` returns null in the glance context, and a null data inconsistency in the overnight `prev` dictionary. Three informational items cover missing `AppName` in the French override (intentional but undocumented), redundant `:glance` annotations, and missing accents in French strings.

---

## Critical Issues

### CR-01: French resource directory not registered in monkey.jungle — localization is dead code

**File:** `monkey.jungle:3`
**Issue:** The Connect IQ build system discovers language-specific resources only when they are declared in `monkey.jungle` with a language-prefix variable (e.g., `fre.resourcePath`). The current file only declares `base.resourcePath`, which points at `resources/`. The `resources-fre/` directory is never referenced and is therefore never compiled into any build. All devices — including French-language ones — will fall back to English strings. The glance-view hardcoded conditionals (`System.LANGUAGE_FRE`) will show French text correctly only because they are hardcoded in source, but all `loadResource()` calls in `MawaqitWidgetView` will return English strings regardless of the device language setting.

**Fix:**
```
# monkey.jungle — add French resource path alongside base
project.manifest = manifest.xml
base.sourcePath = source
base.resourcePath = resources;resources/drawables;resources/settings;resources/strings
fre.resourcePath = resources-fre;resources-fre/strings
```
The `fre.` prefix corresponds to the ISO 639-2 code declared in `manifest.xml` (`<iq:language>fre</iq:language>`). When the device language is French, the SDK merges `resources-fre/` over `resources/`, so only the overridden string IDs need to be present in the French file (which is already the case).

---

## Warnings

### WR-01: Null-dereference crash risk on getDeviceSettings() in glance context

**File:** `source/MawaqitGlanceView.mc:95`
**Issue:** `System.getDeviceSettings().systemLanguage` dereferences the return value of `getDeviceSettings()` without a null check. Per the Connect IQ documentation and project memory (CIQ glance context gotchas), the glance runs in a constrained VM context where `getDeviceSettings()` can return null under certain device states (e.g., during initialization or low-memory conditions). In Monkey C, accessing a property on null throws a VM fault that `try/catch` cannot catch. This would crash the glance view silently on affected devices.

**Fix:**
```javascript
// Replace line 95-96:
var settings = System.getDeviceSettings();
var lang = (settings != null) ? settings.systemLanguage : System.LANGUAGE_ENG;
```
This guards the null case and defaults to English, which is the correct fallback behavior — all hardcoded default strings in the file are already English.

---

### WR-02: Overnight result dictionary includes null "seconds" when Isha time is malformed

**File:** `source/PrayerLogic.mc:248-254`
**Issue:** In `getNextPrayerResult()`, the overnight code path parses `ishaSec` at line 222 and guards access behind `if (ishaSec != null)` at line 223. However, when `ishaSec` is null (malformed "icha" value in the data store), execution falls through to the return statement at line 243-254, which unconditionally includes `"seconds" => ishaSec` in the `"prev"` sub-dictionary. This means callers receive a `"prev"` dictionary with a null `"seconds"` field. While current callers in `MawaqitGlanceView` and `MawaqitWidgetView` only read `["time"]` from `prev` (not `["seconds"]`), this creates a fragile data contract: future code accessing `(result["prev"] as Dictionary)["seconds"] as Number` would crash at runtime rather than fail gracefully.

**Fix:**
```javascript
// Replace lines 249-253 in the overnight return:
"prev" => {
    "name" => "Isha",
    "time" => (ishaSec != null) ? times["icha"] : "--:--",
    "seconds" => (ishaSec != null) ? ishaSec : 0
}
```
Alternatively, mirror the fajrSec null-guard pattern used earlier in the same function: return `{ "state" => "no_data" }` when `ishaSec` is null, since we cannot compute a meaningful overnight display without Isha's time.

---

## Info

### IN-01: AppName missing from French resource file — intent should be documented

**File:** `resources-fre/strings/strings.xml`
**Issue:** The English base file (`resources/strings/strings.xml`) declares `AppName = "Mawaqit"`, but the French override file does not include it. This is correct behavior — "Mawaqit" is a proper noun and should not be translated — but the omission is silent. A comment would prevent a future contributor from adding a translation by mistake, or from wondering whether it was accidentally forgotten.

**Fix:**
```xml
<!-- AppName intentionally omitted: "Mawaqit" is a proper noun, same in all languages -->
```
Add this comment at the top of `resources-fre/strings/strings.xml`.

---

### IN-02: Redundant (:glance) annotation on individual methods inside a (:glance) class

**File:** `source/MawaqitGlanceView.mc:50, 87, 268`
**Issue:** The class declaration at line 22 is annotated `(:glance)`, which causes the entire class (all methods) to be compiled into the glance memory context. The additional per-method `(:glance)` annotations at lines 50, 87, and 268 (`onTimer`, `onUpdate`, `drawEmptyState`) are redundant. Per the Garmin Connect IQ annotation documentation, a class-level annotation covers all members. The redundant annotations add visual noise without effect.

**Fix:** Remove the `(:glance)` annotation from lines 50, 87, and 268. Keep only the class-level annotation at line 22.

---

### IN-03: Missing accents in French strings

**File:** `resources-fre/strings/strings.xml:4, 5, 15`
**Issue:** Three French strings use unaccented "mosquee" instead of "mosquée":
- Line 4: `"ID Mosquee"` should be `"ID Mosquée"`
- Line 5: `"Entrez le slug de votre mosquee depuis mawaqit.net"` should be `"mosquée"`
- Line 15: `"Configurer la mosquee"` should be `"Configurer la mosquée"`

These strings are shown in the Garmin Connect phone app settings UI (not on-device), where UTF-8 accented characters render correctly. The missing accents are grammatically incorrect French.

**Fix:**
```xml
<string id="MosqueSettingTitle">ID Mosquée</string>
<string id="MosqueSettingPrompt">Entrez le slug de votre mosquée depuis mawaqit.net</string>
<string id="WidgetNoMosqueLine1">Configurer la mosquée</string>
```

---

_Reviewed: 2026-04-12T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
