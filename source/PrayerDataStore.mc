import Toybox.Application.Storage;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Lang;

//
// PrayerDataStore: Read-side storage layer for cached prayer data.
// MawaqitService writes data to Storage; this module provides read accessors.
// Phase 2+ views use these functions to get prayer times for display.
//
(:glance)
module PrayerDataStore {

    //
    // Returns one month of calendar prayer times (Array of day objects, 0-indexed).
    // Each element is a Dictionary: { "fajr", "sunrise", "dohr", "asr", "maghreb", "icha" }
    //
    function getCalendarMonth(month as Number) as Array? {
        return Storage.getValue("cal_" + month) as Array?;
    }

    //
    // Returns one month of iqama offsets (Array of offset objects, 0-indexed).
    // Each element is a Dictionary: { "fajr", "dohr", "asr", "maghreb", "icha" } with offset strings like "+10"
    //
    function getIqamaMonth(month as Number) as Array? {
        return Storage.getValue("iqama_" + month) as Array?;
    }

    //
    // Returns today's prayer times from the /prayer-times endpoint cache.
    // Dictionary: { "fajr", "sunrise", "dohr", "asr", "maghreb", "icha" }
    //
    function getTodayTimes() as Dictionary? {
        return Storage.getValue("todayTimes") as Dictionary?;
    }

    //
    // Returns mosque metadata (D-01/D-08).
    // Dictionary: { "name", "timezone", "jumua", "jumua2", "shuruq", "hijriAdjustment" }
    //
    function getMosqueMeta() as Dictionary? {
        return Storage.getValue("mosqueMeta") as Dictionary?;
    }

    //
    // Returns the date string of the last successful fetch ("YYYY-MM-DD").
    //
    function getLastFetchDate() as String? {
        return Storage.getValue("lastFetchDate") as String?;
    }

    //
    // Returns the mosque slug used in the last successful fetch.
    //
    function getLastFetchSlug() as String? {
        return Storage.getValue("lastFetchSlug") as String?;
    }

    //
    // Primary accessor for today's prayer times from calendar data.
    // Tries the per-month calendar first (more accurate), falls back to /prayer-times cache.
    //
    function getTodayPrayerTimes() as Dictionary? {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var month = now.month as Number;
        var day = now.day as Number;

        // Try calendar data first
        var cal = getCalendarMonth(month);
        if (cal != null && cal.size() >= day) {
            return cal[day - 1] as Dictionary;
        }

        // Fall back to /prayer-times cache
        return getTodayTimes();
    }

    //
    // Returns tomorrow's prayer times from calendar data.
    // Needed for Isha-to-Fajr rollover (DATA-04).
    // Handles month boundary: last day of month rolls to day 1 of next month.
    //
    function getTomorrowPrayerTimes() as Dictionary? {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var month = now.month as Number;
        var day = now.day as Number;

        // Calculate days in current month
        var nextMonthNum = (month % 12) + 1;
        var nextYear = (month == 12) ? now.year + 1 : now.year;
        var firstOfNext = Gregorian.moment({
            :year => nextYear,
            :month => nextMonthNum,
            :day => 1,
            :hour => 0,
            :minute => 0,
            :second => 0
        });
        var lastOfCurrent = Gregorian.info(
            new Time.Moment(firstOfNext.value() - 86400),
            Time.FORMAT_SHORT
        );
        var daysInMonth = lastOfCurrent.day as Number;

        if (day < daysInMonth) {
            // Tomorrow is in the same month
            var cal = getCalendarMonth(month);
            if (cal != null && cal.size() > day) {
                return cal[day] as Dictionary; // day is 0-indexed for tomorrow (day-1+1)
            }
        } else {
            // Tomorrow is the first day of next month
            var cal = getCalendarMonth(nextMonthNum);
            if (cal != null && cal.size() > 0) {
                return cal[0] as Dictionary;
            }
        }

        return null;
    }

    //
    // Returns today's iqama offsets from the iqama calendar.
    // Dictionary: { "fajr", "dohr", "asr", "maghreb", "icha" } with offset strings
    //
    function getTodayIqama() as Dictionary? {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var month = now.month as Number;
        var day = now.day as Number;

        var iqama = getIqamaMonth(month);
        if (iqama != null && iqama.size() >= day) {
            return iqama[day - 1] as Dictionary;
        }

        return null;
    }

    //
    // Checks if we have valid cached data for today (D-07).
    // Returns false when calendar data has expired (no entry for current date),
    // which triggers the empty state.
    //
    function hasCachedData() as Boolean {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var month = now.month as Number;
        var day = now.day as Number;

        // Check calendar data for today
        var cal = getCalendarMonth(month);
        if (cal != null && cal.size() >= day) {
            return true;
        }

        // Fall back: check /prayer-times cache
        if (getTodayTimes() != null) {
            return true;
        }

        return false;
    }

    //
    // Convenience check: has a mosque ever been fetched successfully?
    //
    function isMosqueConfigured() as Boolean {
        return getLastFetchSlug() != null;
    }
}
