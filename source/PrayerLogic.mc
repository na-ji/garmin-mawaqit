import Toybox.System;
import Toybox.Lang;

//
// PrayerLogic: Computational core for prayer time display.
// Converts raw "HH:MM" prayer time strings from PrayerDataStore into
// display-ready data: next prayer identification, countdown calculation,
// overnight rollover, formatted countdown strings, and progress bar segments.
//
// All functions use seconds-since-midnight integer arithmetic to avoid
// the Gregorian.moment() UTC/local timezone pitfall. No Time module imports.
// No debug print calls (memory risk in 28KB glance budget).
//
// Annotated (:glance) for memory-safe use from the GlanceView context.
//
(:glance)
module PrayerLogic {

    // Prayer order for iteration (excluding sunrise -- not a prayer)
    // Keys match PrayerDataStore dictionary keys
    const PRAYER_KEYS = ["fajr", "dohr", "asr", "maghreb", "icha"];
    const PRAYER_LABELS = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];

    // Duration of the "now" indicator window in seconds (D-07: 5 minutes)
    const NOW_WINDOW = 300;

    // Seconds in a full day
    const DAY_SECONDS = 86400;

    // Segment colors for the 5 prayer periods (D-02)
    // Optimized for AMOLED visibility and distinctiveness at glance size
    const SEGMENT_COLORS = [
        0x3366CC,  // Fajr-to-Dhuhr: Deep Blue
        0xFFAA00,  // Dhuhr-to-Asr: Amber/Gold
        0xFF6633,  // Asr-to-Maghrib: Orange
        0xCC3333,  // Maghrib-to-Isha: Deep Red/Crimson
        0x6633CC   // Isha-to-Fajr: Dark Purple
    ];

    //
    // Parse an "HH:MM" time string to seconds since midnight.
    // Returns null for malformed input (null, too short, missing colon, non-numeric).
    //
    // Examples:
    //   parseTimeToSeconds("13:30") => 48600
    //   parseTimeToSeconds("00:00") => 0
    //   parseTimeToSeconds("23:59") => 86340
    //   parseTimeToSeconds(null)    => null
    //   parseTimeToSeconds("bad")   => null
    //   parseTimeToSeconds("1:30")  => null (too short)
    //
    function parseTimeToSeconds(timeStr) as Number? {
        // Validate input: must be non-null string with at least 4 characters ("H:MM")
        if (timeStr == null) {
            return null;
        }
        if (!(timeStr instanceof String)) {
            return null;
        }
        var str = timeStr as String;
        if (str.length() < 4) {
            return null;
        }

        // Find colon separator
        var colonPos = str.find(":");
        if (colonPos == null) {
            return null;
        }

        // Extract and parse hour and minute components
        var hour = str.substring(0, colonPos).toNumber();
        var min = str.substring(colonPos + 1, str.length()).toNumber();

        // Validate parsed numbers
        if (hour == null || min == null) {
            return null;
        }

        return hour * 3600 + min * 60;
    }

    //
    // Get the current local time as seconds since midnight.
    // Uses System.getClockTime() which returns local time directly,
    // avoiding the Gregorian.moment() UTC timezone pitfall.
    //
    // Returns: Number between 0 and 86399
    //
    function getCurrentSeconds() as Number {
        var clock = System.getClockTime();
        return clock.hour * 3600 + clock.min * 60 + clock.sec;
    }

    //
    // Find the next upcoming prayer from a times dictionary.
    // Iterates prayers in order: Fajr, Dhuhr, Asr, Maghrib, Isha.
    // Returns the first prayer whose time is strictly after currentSec.
    //
    // Returns: Dictionary with "name", "key", "time", "seconds", "index"
    //          or null if all prayers have passed (triggers overnight rollover)
    //
    function getNextPrayer(times as Dictionary, currentSec as Number) as Dictionary? {
        for (var i = 0; i < PRAYER_KEYS.size(); i++) {
            var prayerSec = parseTimeToSeconds(times[PRAYER_KEYS[i]]);
            if (prayerSec == null) {
                // Skip prayers with malformed time data
                continue;
            }
            if (prayerSec > currentSec) {
                return {
                    "name" => PRAYER_LABELS[i],
                    "key" => PRAYER_KEYS[i],
                    "time" => times[PRAYER_KEYS[i]],
                    "seconds" => prayerSec,
                    "index" => i
                };
            }
        }
        // All prayers have passed today
        return null;
    }

    //
    // Find the most recent past prayer from a times dictionary.
    // Iterates prayers in reverse order to find the last one at or before currentSec.
    //
    // Returns: Dictionary with "name", "key", "time", "seconds", "index"
    //          or null if before Fajr (no prayer has occurred yet today)
    //
    function getPreviousPrayer(times as Dictionary, currentSec as Number) as Dictionary? {
        for (var i = PRAYER_KEYS.size() - 1; i >= 0; i--) {
            var prayerSec = parseTimeToSeconds(times[PRAYER_KEYS[i]]);
            if (prayerSec == null) {
                continue;
            }
            if (prayerSec <= currentSec) {
                return {
                    "name" => PRAYER_LABELS[i],
                    "key" => PRAYER_KEYS[i],
                    "time" => times[PRAYER_KEYS[i]],
                    "seconds" => prayerSec,
                    "index" => i
                };
            }
        }
        // Before Fajr -- no prayer has occurred yet today
        return null;
    }

    //
    // Full state machine for next prayer identification.
    // Handles 4 states:
    //   "no_data"   - No prayer times available
    //   "now"       - A prayer just occurred (within 5-minute window, D-07)
    //   "normal"    - Normal countdown to next prayer
    //   "overnight" - Past Isha, counting down to tomorrow's Fajr (D-08)
    //
    // Parameters:
    //   todayTimes    - Today's prayer dictionary from PrayerDataStore, or null
    //   tomorrowTimes - Tomorrow's prayer dictionary, or null (falls back to today's Fajr)
    //
    // Returns: Dictionary with "state" key and state-specific data
    //
    function getNextPrayerResult(todayTimes, tomorrowTimes) as Dictionary {
        var currentSec = getCurrentSeconds();

        // No data available
        if (todayTimes == null) {
            return { "state" => "no_data" };
        }

        var times = todayTimes as Dictionary;
        var next = getNextPrayer(times, currentSec);
        var prev = getPreviousPrayer(times, currentSec);

        // "Now" window check (D-07): if a prayer just occurred within 5 minutes
        if (prev != null) {
            var prevSeconds = prev["seconds"] as Number;
            var elapsed = currentSec - prevSeconds;
            if (elapsed >= 0 && elapsed < NOW_WINDOW) {
                return {
                    "state" => "now",
                    "name" => prev["name"] as String,
                    "time" => prev["time"] as String,
                    "prevSeconds" => prevSeconds,
                    "index" => prev["index"] as Number,
                    "nextPrayer" => next
                };
            }
        }

        // Normal next prayer countdown
        if (next != null) {
            var nextSeconds = next["seconds"] as Number;
            var remaining = nextSeconds - currentSec;
            return {
                "state" => "normal",
                "name" => next["name"] as String,
                "time" => next["time"] as String,
                "remaining" => remaining,
                "seconds" => nextSeconds,
                "index" => next["index"] as Number,
                "prev" => prev
            };
        }

        // Overnight rollover (D-08): past all prayers including Isha
        // Use tomorrow's times if available, else fall back to today's Fajr as estimate
        var fajrTimes = tomorrowTimes;
        if (fajrTimes == null) {
            fajrTimes = times;
        }
        var fajrDict = fajrTimes as Dictionary;
        var fajrSec = parseTimeToSeconds(fajrDict["fajr"]);

        if (fajrSec == null) {
            return { "state" => "no_data" };
        }

        // Check Isha "now" window before committing to overnight state
        var ishaSec = parseTimeToSeconds(times["icha"]);
        if (ishaSec != null) {
            var ishaElapsed = currentSec - ishaSec;
            if (ishaElapsed >= 0 && ishaElapsed < NOW_WINDOW) {
                return {
                    "state" => "now",
                    "name" => "Isha",
                    "time" => times["icha"] as String,
                    "prevSeconds" => ishaSec,
                    "index" => 4,
                    "nextPrayer" => {
                        "name" => "Fajr",
                        "time" => fajrDict["fajr"],
                        "seconds" => fajrSec
                    }
                };
            }
        }

        // Overnight countdown: seconds remaining today + seconds into tomorrow until Fajr
        var remaining = (DAY_SECONDS - currentSec) + fajrSec;
        return {
            "state" => "overnight",
            "name" => "Fajr",
            "time" => fajrDict["fajr"] as String,
            "remaining" => remaining,
            "seconds" => fajrSec,
            "prev" => {
                "name" => "Isha",
                "time" => times["icha"],
                "seconds" => ishaSec
            }
        };
    }

    //
    // Format a countdown duration into a human-readable, localized string.
    // Follows the Sunrise glance convention (D-04, D-05, D-06, D-07):
    //
    //   remainingSec <= 0:  "Asr now"/"Asr maintenant"  (D-07: now indicator)
    //   hours > 0:         "Asr in 2h 5m"/"Asr dans 2h 5m"  (D-04: hours+minutes)
    //   mins > 0:          "Asr in 45m"/"Asr dans 45m"   (D-05: minutes only)
    //   secs only:         "Asr in 45s"/"Asr dans 45s"   (D-05: seconds only)
    //
    // No seconds displayed above 1 minute (D-06).
    // Time unit suffixes (h, m, s) stay the same in all languages (D-03).
    //
    // Parameters:
    //   remainingSec - seconds until next prayer (0 or negative = "now")
    //   prayerName   - display name (e.g., "Fajr", "Asr")
    //   tokenIn      - localized "in"/"dans" token from loadResource()
    //   tokenNow     - localized "now"/"maintenant" token from loadResource()
    //
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

    //
    // Build 6 color-coded progress bar segments representing prayer periods (D-02).
    //
    // Segments:
    //   0: Midnight-to-Fajr (Dark Purple 0x6633CC) — overnight wrap continuation
    //   1: Fajr-to-Dhuhr    (Deep Blue 0x3366CC)
    //   2: Dhuhr-to-Asr     (Amber/Gold 0xFFAA00)
    //   3: Asr-to-Maghrib   (Orange 0xFF6633)
    //   4: Maghrib-to-Isha  (Deep Red/Crimson 0xCC3333)
    //   5: Isha-to-Midnight (Dark Purple 0x6633CC)
    //
    // Each segment is a Dictionary: {"start" => seconds, "end" => seconds, "color" => colorInt}
    //
    // The overnight Isha-to-Fajr period is split into two segments (0 and 5)
    // so the progress bar has full coverage from 0 to 86400.
    //
    // If any parse returns null, uses reasonable defaults to avoid crash.
    //
    function buildSegments(times as Dictionary) as Array {
        var fajrSec = parseTimeToSeconds(times["fajr"]);
        var dohrSec = parseTimeToSeconds(times["dohr"]);
        var asrSec = parseTimeToSeconds(times["asr"]);
        var maghrebSec = parseTimeToSeconds(times["maghreb"]);
        var ichaSec = parseTimeToSeconds(times["icha"]);

        // Apply safe defaults for any null values
        if (fajrSec == null) { fajrSec = 0; }
        if (dohrSec == null) { dohrSec = 43200; }     // noon fallback
        if (asrSec == null) { asrSec = 54000; }        // 15:00 fallback
        if (maghrebSec == null) { maghrebSec = 64800; } // 18:00 fallback
        if (ichaSec == null) { ichaSec = 72000; }       // 20:00 fallback

        return [
            { "start" => 0, "end" => fajrSec, "color" => SEGMENT_COLORS[4] },
            { "start" => fajrSec, "end" => dohrSec, "color" => SEGMENT_COLORS[0] },
            { "start" => dohrSec, "end" => asrSec, "color" => SEGMENT_COLORS[1] },
            { "start" => asrSec, "end" => maghrebSec, "color" => SEGMENT_COLORS[2] },
            { "start" => maghrebSec, "end" => ichaSec, "color" => SEGMENT_COLORS[3] },
            { "start" => ichaSec, "end" => DAY_SECONDS, "color" => SEGMENT_COLORS[4] }
        ];
    }

    //
    // Dim a color to approximately 40% brightness.
    // Used for inactive segments in the progress bar.
    //
    // Extracts R, G, B components, scales each to 40%, and reassembles.
    // Integer arithmetic only (no floating point).
    //
    function getDimColor(color as Number) as Number {
        var r = (color >> 16) & 0xFF;
        var g = (color >> 8) & 0xFF;
        var b = color & 0xFF;

        // Scale to 40%: multiply by 4, divide by 10
        r = (r * 4) / 10;
        g = (g * 4) / 10;
        b = (b * 4) / 10;

        return (r << 16) | (g << 8) | b;
    }
}
