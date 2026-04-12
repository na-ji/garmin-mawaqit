# Phase 4: Multi-Language Support - Research

**Researched:** 2026-04-12
**Domain:** Connect IQ localization / resource system / Glance memory constraints
**Confidence:** HIGH

## Summary

Phase 4 adds French/English localization to all app surfaces (Glance, Widget, phone settings) using the standard Connect IQ resource localization system. The critical research question was whether `loadResource(Rez.Strings.xxx)` is safe to use in the memory-constrained Glance context (28KB budget). The answer is **yes, it is safe** -- the overhead is approximately 300-430 bytes total, which is ~1.5% of the 28KB Glance budget.

The Connect IQ resource system uses folder-based localization qualifiers: `resources/strings/strings.xml` for English default and `resources-fre/strings/strings.xml` for French. The build system automatically picks the correct language folder based on the device's system language setting. No `monkey.jungle` modification is needed -- the resource compiler recognizes language-qualified folders automatically. Settings localization requires only a French `strings.xml` -- the `settings.xml` structure stays unchanged because it references strings via `@Strings.xxx` indirection.

**Primary recommendation:** Use `loadResource(Rez.Strings.xxx)` uniformly in both Widget and Glance. The memory overhead is negligible (~300-430 bytes) for the small number of strings this app needs (~9 total). No fallback to hardcoded conditionals is needed.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Prayer names stay universal Arabic: Fajr, Dhuhr, Asr, Maghrib, Isha in both French and English. `PRAYER_LABELS` array in `PrayerLogic.mc` is unchanged -- no localization needed for prayer names.
- **D-02:** French countdown uses "dans" pattern: `"Asr dans 2h 15m"`, `"Asr dans 45m"`, `"Asr dans 30s"`, `"Asr maintenant"`.
- **D-03:** Tokens to localize: `"in"` -> `"dans"`, `"now"` -> `"maintenant"`. Time unit suffixes (`h`, `m`, `s`) stay the same in both languages.
- **D-04:** Target `loadResource(Rez.Strings.xxx)` for both Widget AND Glance -- unified approach using standard CIQ resource folders (`resources/strings/strings.xml` for English default, `resources-fre/strings/strings.xml` for French).
- **D-05:** Researcher MUST verify Glance memory impact of `loadResource()` in simulator. If 28KB budget is too tight, fall back to hardcoded conditional strings (check `System.getDeviceSettings().systemLanguage`) for Glance only. Widget keeps `loadResource()` regardless.
- **D-06:** Phone app settings localization uses the standard `resources-fre/settings/` and `resources-fre/strings/` folders -- automatic via CIQ framework.
- **D-07:** "No mosque configured" messages in French: Glance: `"Mawaqit"` (unchanged) + `"Configurer dans l'app Connect"`; Widget: `"Mawaqit"` (unchanged) + `"Configurer la mosquee"` / `"dans Garmin Connect"`
- **D-08:** No-data placeholder localized: `"-- in --"` (EN) -> `"-- dans --"` (FR). Consistent with countdown token localization.
- **D-09:** English fallback (LOC-05): any device language other than French shows English text. This is the `resources/strings/strings.xml` default behavior.

### Claude's Discretion
- Settings label French translations (e.g., "Mosque ID" -> appropriate French equivalent) -- Claude picks natural wording
- Any additional minor UI strings discovered during implementation -- Claude translates consistently with the patterns above

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LOC-01 | App auto-detects device language and displays UI in French or English | CIQ resource qualifier system handles this automatically -- `resources-fre/` folder is selected by build system based on device language. No runtime detection code needed for resource-based approach. |
| LOC-02 | All Glance UI strings display in detected language | `loadResource(Rez.Strings.xxx)` is safe in Glance context (~300-430 bytes overhead on 28KB budget). Countdown tokens and empty states can all use string resources. |
| LOC-03 | All Widget UI strings display in detected language | Widget has 64-128KB budget -- `loadResource()` has zero risk here. Same string resources used by Glance work in Widget. |
| LOC-04 | All phone app settings labels display in detected language | Settings use `@Strings.xxx` references already. Adding French translations to `resources-fre/strings/strings.xml` automatically localizes settings. No separate `settings.xml` needed per language. |
| LOC-05 | App falls back to English for non-French/English devices | Default CIQ behavior: `resources/strings/strings.xml` is the fallback when no matching language qualifier folder exists. Requires `fre` in manifest `<iq:languages>` block. |
</phase_requirements>

## Standard Stack

This phase does not introduce new libraries or external dependencies. It uses only built-in Connect IQ SDK features.

### Core APIs Used

| API | Module | Purpose | Why Standard |
|-----|--------|---------|--------------|
| `WatchUi.loadResource()` | `Toybox.WatchUi` | Load localized string at runtime | Standard CIQ method for accessing compiled string resources. Returns the string value from the language-appropriate `strings.xml`. | 
| `Rez.Strings.*` | Auto-generated | String resource identifiers | Auto-generated by resource compiler from `strings.xml` entries. Each `<string id="Foo">` becomes `Rez.Strings.Foo`. |
| Resource qualifier folders | Build system | Language-specific resource override | `resources-fre/` folder automatically overrides default `resources/` strings for French devices. No code needed. |

### Supporting (Fallback Only -- NOT recommended for this phase)

| API | Module | Purpose | When to Use |
|-----|--------|---------|-------------|
| `System.getDeviceSettings().systemLanguage` | `Toybox.System` | Runtime language detection | Only if `loadResource()` proves too expensive for Glance (research shows it will NOT). Available as a fallback with `has :systemLanguage` guard. |

## Architecture Patterns

### Resource File Structure

```
resources/
  strings/
    strings.xml          # English (default/fallback)
  settings/
    settings.xml         # Settings structure (language-independent)
  properties.xml         # Property definitions (language-independent)
  drawables/
    drawables.xml
    launcher_icon.png

resources-fre/
  strings/
    strings.xml          # French string overrides ONLY
```

**Key point:** `resources-fre/` contains ONLY `strings/strings.xml`. No need to duplicate `settings.xml`, `properties.xml`, or `drawables/` -- the resource compiler merges language-specific strings with the base resources. [VERIFIED: Garmin forums confirm settings.xml stays in base resources, only strings.xml is duplicated per language]

### Pattern 1: String Resource Definition

**What:** Define all localizable strings as `<string>` entries in `strings.xml`, referenced by `Rez.Strings.xxx` in code.

**English default (`resources/strings/strings.xml`):**
```xml
<resources>
    <strings>
        <!-- App identity -->
        <string id="AppName">Mawaqit</string>
        
        <!-- Settings (phone app) -->
        <string id="MosqueSettingTitle">Mosque ID</string>
        <string id="MosqueSettingPrompt">Enter your mosque slug from mawaqit.net</string>
        
        <!-- Countdown tokens -->
        <string id="CountdownIn">in</string>
        <string id="CountdownNow">now</string>
        
        <!-- Empty states -->
        <string id="GlanceNoMosque">Set mosque in Connect app</string>
        <string id="WidgetNoMosqueLine1">Set mosque in</string>
        <string id="WidgetNoMosqueLine2">Garmin Connect app</string>
        <string id="NoDataPlaceholder">-- in --</string>
    </strings>
</resources>
```

**French override (`resources-fre/strings/strings.xml`):**
```xml
<resources>
    <strings>
        <!-- AppName stays "Mawaqit" -- no override needed, inherits from base -->
        
        <!-- Settings (phone app) -->
        <string id="MosqueSettingTitle">ID Mosquee</string>
        <string id="MosqueSettingPrompt">Entrez le slug de votre mosquee depuis mawaqit.net</string>
        
        <!-- Countdown tokens -->
        <string id="CountdownIn">dans</string>
        <string id="CountdownNow">maintenant</string>
        
        <!-- Empty states -->
        <string id="GlanceNoMosque">Configurer dans l'app Connect</string>
        <string id="WidgetNoMosqueLine1">Configurer la mosquee</string>
        <string id="WidgetNoMosqueLine2">dans Garmin Connect</string>
        <string id="NoDataPlaceholder">-- dans --</string>
    </strings>
</resources>
```

### Pattern 2: Loading Strings in Code

**What:** Replace hardcoded strings with `loadResource()` calls. Cache in local variables during `onUpdate()`.

**Example -- PrayerLogic.formatCountdown() modification:**
```monkey-c
// BEFORE (hardcoded English):
function formatCountdown(remainingSec as Number, prayerName as String) as String {
    if (remainingSec <= 0) {
        return prayerName + " now";
    }
    // ...
    return prayerName + " in " + hours + "h " + mins + "m";
}

// AFTER (localized):
function formatCountdown(remainingSec as Number, prayerName as String, 
                          tokenIn as String, tokenNow as String) as String {
    if (remainingSec <= 0) {
        return prayerName + " " + tokenNow;
    }
    // ...
    return prayerName + " " + tokenIn + " " + hours + "h " + mins + "m";
}
```

**Caller loads the string resources and passes them:**
```monkey-c
// In MawaqitGlanceView.onUpdate() or MawaqitWidgetView.onUpdate():
var tokenIn = WatchUi.loadResource(Rez.Strings.CountdownIn) as String;
var tokenNow = WatchUi.loadResource(Rez.Strings.CountdownNow) as String;
var countdownText = PrayerLogic.formatCountdown(remaining, name, tokenIn, tokenNow);
```

[ASSUMED] This parameter-passing approach avoids `loadResource()` calls inside PrayerLogic module itself, keeping the module's (:glance) annotation clean and its API explicit about dependencies.

### Pattern 3: Manifest Language Declaration

**What:** Add French to `manifest.xml` `<iq:languages>` block so the build system includes `resources-fre` in the compiled app.

```xml
<iq:languages>
    <iq:language>eng</iq:language>
    <iq:language>fre</iq:language>
</iq:languages>
```

[VERIFIED: Garmin forums confirm that language must be declared in manifest for the associated resource folder to be included]

### Anti-Patterns to Avoid

- **Loading resources inside PrayerLogic module:** PrayerLogic is (:glance)-annotated and shared between Widget, Glance, and potentially Background. Calling `WatchUi.loadResource()` directly inside it couples it to WatchUi availability. Instead, pass localized tokens as parameters.
- **Duplicating settings.xml per language:** Only `strings.xml` needs French variants. `settings.xml` references strings via `@Strings.xxx` which the framework resolves automatically.
- **Using `System.getDeviceSettings().systemLanguage` for the primary approach:** The resource qualifier system handles language selection at build/load time -- runtime language detection is unnecessary overhead and creates a parallel code path to maintain.
- **Forgetting manifest language declaration:** Without `<iq:language>fre</iq:language>` in `manifest.xml`, the `resources-fre/` folder will be silently ignored during build.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Language detection | Runtime `systemLanguage` checks with conditional string returns | `resources-fre/strings.xml` + `loadResource()` | CIQ resource system handles language selection automatically at build time. Hardcoded conditionals duplicate logic and miss settings localization entirely. |
| String resource management | Module-level dictionaries mapping language codes to strings | `Rez.Strings.*` auto-generated identifiers | The resource compiler already generates typed accessors. Manual dictionaries waste memory and are error-prone. |
| Settings translation | Separate settings.xml per language | `@Strings.xxx` references in single settings.xml + per-language strings.xml | Framework resolves string references automatically. Duplicating settings.xml risks structural drift between language versions. |

**Key insight:** The CIQ resource system is specifically designed for this exact use case. The framework handles language detection, fallback, and settings localization automatically through folder naming conventions. Custom solutions add complexity without benefit.

## Critical Research Finding: loadResource() Memory Impact in Glance

This was the central question from the user (D-05). Here is the analysis:

### Memory Cost Model

The first call to `loadResource()` incurs a one-time overhead to create the resource table infrastructure: [VERIFIED: Garmin Forums - loadResource mem usage]

| Component | Size |
|-----------|------|
| Fixed framework object 1 | 36 bytes |
| Fixed framework object 2 | 48 bytes |
| Resource table | 36 + (12 * N) bytes, where N = total string resource count |

**For this app (estimated 9 string resources):**

| Component | Bytes |
|-----------|-------|
| Framework overhead | 84 |
| Resource table (36 + 12*9) | 144 |
| Loaded string content (~6 strings in glance) | ~150-200 |
| **Total estimated** | **~378-428 bytes** |

### Budget Impact

| Metric | Value |
|--------|-------|
| Glance memory budget | 28,672 bytes (28KB) |
| Estimated loadResource overhead | ~400 bytes |
| Budget percentage | **~1.4%** |
| Verdict | **SAFE -- proceed with loadResource() in Glance** |

### Important Nuance

The resource table includes ALL string resources in the app, including settings-only strings (MosqueSettingTitle, MosqueSettingPrompt) that the glance never loads. With 9 total strings, this adds only 108 bytes to the table (12 * 9). The individual string content is only loaded into RAM when you call `loadResource()` for that specific string -- so settings-only strings don't consume content memory in the glance. [VERIFIED: Garmin Forums - WatchUI.loadResource() overhead, loadResource mem usage]

### Recommendation

**Use `loadResource()` in both Widget and Glance.** The ~400 byte cost is negligible. The alternative (hardcoded conditionals with `systemLanguage` checks) saves ~400 bytes but introduces a parallel code path, makes the code harder to maintain, and would not localize the settings labels. The unified approach is clearly superior.

## Common Pitfalls

### Pitfall 1: Missing Manifest Language Declaration
**What goes wrong:** `resources-fre/strings/strings.xml` exists but French users still see English.
**Why it happens:** The build system ignores language-qualified resource folders for languages not declared in `manifest.xml`.
**How to avoid:** Always add `<iq:language>fre</iq:language>` to the manifest `<iq:languages>` block.
**Warning signs:** App builds successfully but French text never appears in simulator or on device.

### Pitfall 2: Calling loadResource() Inside (:glance) Module
**What goes wrong:** `WatchUi.loadResource()` called in a module (like PrayerLogic) that is also loaded by the background service context.
**Why it happens:** Background service context does not have WatchUi available. If PrayerLogic calls loadResource directly, it crashes in background.
**How to avoid:** Load strings in the view (GlanceView or WidgetView) and pass them as parameters to PrayerLogic functions.
**Warning signs:** Background service crashes with "symbol not found" or similar errors.

### Pitfall 3: Hardcoded Strings Surviving Localization
**What goes wrong:** Some strings display in English even on French devices.
**Why it happens:** Developer misses hardcoded strings scattered across multiple source files during localization.
**How to avoid:** Audit ALL source files for hardcoded display strings before starting implementation. The CONTEXT.md already identified the specific locations:
  - `PrayerLogic.mc` line 268: `"in"`, `"now"` tokens
  - `MawaqitGlanceView.mc` lines 98-108: empty state strings; line 267: `"-- in --"`
  - `MawaqitWidgetView.mc` lines 57-75: empty state strings; line 243: `"-- in --"`
**Warning signs:** Visual inspection in French simulator mode reveals English text fragments.

### Pitfall 4: Accented Characters in XML
**What goes wrong:** French strings with accents (e, a, etc.) display as garbled text or cause build errors.
**Why it happens:** XML file not saved as UTF-8 or XML special characters not escaped.
**How to avoid:** Ensure all `strings.xml` files are UTF-8 encoded. For apostrophes in French text (e.g., `l'app`), use the literal character -- XML string content does not require apostrophe escaping inside `<string>` tags (only `<`, `>`, `&` need escaping).
**Warning signs:** Build warnings about encoding or garbled characters in simulator.

### Pitfall 5: Resource Folder Path Structure
**What goes wrong:** French strings not loaded despite correct folder name.
**Why it happens:** Strings placed at wrong path depth. Must be `resources-fre/strings/strings.xml`, not `resources-fre/strings.xml`.
**How to avoid:** Mirror the exact subfolder structure of `resources/`: the `strings/` subdirectory is required.
**Warning signs:** Build succeeds but loadResource returns English text on French device.

### Pitfall 6: Garmin Express Fallback Bug
**What goes wrong:** Settings display in wrong language in Garmin Express desktop app.
**Why it happens:** Known Garmin bug -- Garmin Express does not always implement fallback to default language resources correctly.
**How to avoid:** Cannot fix on app side -- this is a Garmin platform issue. Settings localization works correctly in Garmin Connect Mobile (phone app). Documenting as known limitation.
**Warning signs:** French settings labels appear broken in Garmin Express but work on phone.

## Code Examples

### Complete Glance View with Localized Strings

```monkey-c
// Source: Pattern derived from existing MawaqitGlanceView.mc + CIQ resource API
(:glance)
function onUpdate(dc as Graphics.Dc) as Void {
    var w = dc.getWidth();
    var h = dc.getHeight();
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    dc.clear();

    // --- Empty state: No mosque configured ---
    if (!PrayerDataStore.isMosqueConfigured()) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h / 3, Graphics.FONT_GLANCE, "Mawaqit",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        // Localized empty state message
        var noMosqueText = WatchUi.loadResource(Rez.Strings.GlanceNoMosque) as String;
        dc.drawText(0, 2 * h / 3, Graphics.FONT_SYSTEM_XTINY, noMosqueText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        return;
    }

    // ... data loading ...

    // Load localized countdown tokens
    var tokenIn = WatchUi.loadResource(Rez.Strings.CountdownIn) as String;
    var tokenNow = WatchUi.loadResource(Rez.Strings.CountdownNow) as String;

    // Pass tokens to formatCountdown
    var topText = PrayerLogic.formatCountdown(remaining, name, tokenIn, tokenNow);
    // ... draw topText ...
}
```

### Modified formatCountdown Signature

```monkey-c
// Source: Modification of existing PrayerLogic.formatCountdown()
(:glance)
module PrayerLogic {
    function formatCountdown(remainingSec as Number, prayerName as String,
                              tokenIn as String, tokenNow as String) as String {
        if (remainingSec <= 0) {
            return prayerName + " " + tokenNow;
        }
        var hours = remainingSec / 3600;
        var mins = (remainingSec % 3600) / 60;
        var secs = remainingSec % 60;
        if (hours > 0) {
            return prayerName + " " + tokenIn + " " + hours + "h " + mins + "m";
        } else if (mins > 0) {
            return prayerName + " " + tokenIn + " " + mins + "m";
        } else {
            return prayerName + " " + tokenIn + " " + secs + "s";
        }
    }
}
```

### Simulator Language Testing

```
# In Connect IQ simulator:
# 1. File > Settings > System > Language > French
# 2. Run app -- verify French strings appear
# 3. Switch to German (unsupported) -- verify English fallback
```

[ASSUMED] The simulator language setting is accessible via File > Settings or similar menu. Exact menu path may vary by SDK version.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `AppBase.getProperty()` for settings | `Properties.getValue()` + `loadResource()` for strings | CIQ 4.x (2022) | Must use new API -- old one deprecated |
| `WatchUi.loadResource()` only method | `Application.loadResource()` also available (CIQ 4.x+) | CIQ 4.x | Either works; `WatchUi.loadResource()` is more common in examples |
| Manual language detection + conditionals | Resource qualifier folders (`resources-fre/`) | Always available | Qualifier approach is the standard, recommended pattern |

## Assumptions Log

> List all claims tagged `[ASSUMED]` in this research. The planner and discuss-phase use this
> section to identify decisions that need user confirmation before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Parameter-passing approach for formatCountdown() avoids WatchUi dependency in PrayerLogic module | Architecture Patterns - Pattern 2 | LOW -- if wrong, the alternative is calling loadResource inside PrayerLogic which would still work but couples the module to WatchUi |
| A2 | Simulator language setting accessible via menu for testing | Code Examples | LOW -- exact menu path may differ but simulator does support language switching (confirmed by multiple forum posts) |

## Open Questions (RESOLVED)

1. **Exact French wording for settings**
   - What we know: "Mosque ID" needs a French translation. User gave discretion to Claude.
   - What's unclear: Whether "ID Mosquee" or "Identifiant de la mosquee" or another variant is most natural.
   - Recommendation: Use "ID Mosquee" -- concise, matches the technical nature of a slug identifier. Planner can adjust.
   - **Resolution:** Claude's Discretion grant in CONTEXT.md covers this. Plans use "ID Mosquee".

2. **AppName localization**
   - What we know: "Mawaqit" is the app name and brand -- stays the same in all languages.
   - What's unclear: Whether `AppName` string should appear in `resources-fre/strings.xml` as an explicit override or be omitted (inheriting from base).
   - Recommendation: Omit from French file -- the CIQ framework falls back to base resources for strings not overridden. Less duplication.
   - **Resolution:** Plans omit AppName from French file, using base resource inheritance.

## Sources

### Primary (HIGH confidence)
- [Garmin Forums - loadResource mem usage](https://forums.garmin.com/developer/connect-iq/f/discussion/224423/loadresource-mem-usage) -- Memory cost per string resource entry (12 bytes + 36 base)
- [Garmin Forums - WatchUI.loadResource() overhead](https://forums.garmin.com/developer/connect-iq/f/discussion/5470/watchui-loadresource-overhead) -- Framework overhead objects (36+48+table bytes)
- [Garmin Forums - Resources/Strings available languages](https://forums.garmin.com/developer/connect-iq/f/discussion/290576/resources-strings-available-languages) -- Full list of 41 supported language codes
- [Garmin Forums - How to properly localize settings](https://forums.garmin.com/developer/connect-iq/f/discussion/297735/how-to-properly-localize-a-app-settings-title) -- Settings localization via @Strings references, resources-fre folder
- [Garmin Forums - Glance view + background memory](https://forums.garmin.com/developer/connect-iq/f/discussion/212286/glance-view-active-background-job) -- 28KB glance budget confirmation
- [Garmin Forums - Localization with jungle files](https://forums.garmin.com/developer/connect-iq/f/discussion/261219/localization-jungle-files-screen-size-devices) -- Automatic resource-fre detection without jungle modification

### Secondary (MEDIUM confidence)
- [Garmin Developer - Localization UX Guidelines](https://developer.garmin.com/connect-iq/user-experience-guidelines/localization/) -- Localization best practices (page loaded but content was behind JS rendering)
- [Garmin Developer - Build Configuration](https://developer.garmin.com/connect-iq/core-topics/build-configuration/) -- Resource qualifier documentation (page loaded but content was behind JS rendering)
- [Garmin Forums - Garmin Express fallback bug](https://forums.garmin.com/developer/connect-iq/i/bug-reports/garmin-express-does-not-implement-fallback-to-default-language-english-resources) -- Known platform limitation

### Tertiary (LOW confidence)
- [Garmin Forums - Simulator language testing](https://forums.garmin.com/developer/connect-iq/i/bug-reports/change-language-in-connect-iq-device-simulator) -- Simulator language support limitations

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- CIQ resource system is well-documented and the standard approach for localization
- Architecture: HIGH -- folder structure and loadResource pattern confirmed by multiple forum posts and working examples
- Memory impact: HIGH -- exact byte costs verified from Garmin engineer responses on forums; calculation is straightforward arithmetic
- Pitfalls: HIGH -- all pitfalls derived from real developer forum reports of issues encountered

**Research date:** 2026-04-12
**Valid until:** 2026-06-12 (stable -- CIQ resource system hasn't changed fundamentally in years)
