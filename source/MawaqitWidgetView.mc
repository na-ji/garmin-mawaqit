import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Lang;

//
// MawaqitWidgetView: Full-screen 5-row prayer schedule for the widget view.
//
// Layout (top to bottom):
//   Header:  Countdown to next prayer (e.g., "Asr in 2h 15m")
//   Line:    Thin separator
//   Rows:    5 prayer rows (Fajr, Dhuhr, Asr, Maghrib, Isha)
//            Each row: prayer name (left), time (center), iqama offset (right)
//            Next prayer row highlighted with green accent background
//
// Empty states:
//   No mosque configured -> "Mawaqit" title + instructions
//   No data available -> prayer labels with "--:--" placeholders
//
// Timer: 1-second updates for live countdown (widget has 64-128KB budget).
// All direct Dc drawing, no XML layouts.
//
class MawaqitWidgetView extends WatchUi.View {

    var _timer as Timer.Timer or Null = null;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), 1000, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTimer() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        // --- Empty state: No mosque configured ---
        if (!PrayerDataStore.isMosqueConfigured()) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                w / 2, h / 3,
                Graphics.FONT_MEDIUM,
                "Mawaqit",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            var noMosqueLine1 = WatchUi.loadResource(Rez.Strings.WidgetNoMosqueLine1) as String;
            var noMosqueLine2 = WatchUi.loadResource(Rez.Strings.WidgetNoMosqueLine2) as String;
            dc.drawText(
                w / 2, h / 2,
                Graphics.FONT_SMALL,
                noMosqueLine1,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.drawText(
                w / 2, h / 2 + h / 8,
                Graphics.FONT_SMALL,
                noMosqueLine2,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            return;
        }

        // --- Get prayer data ---
        var todayTimes = PrayerDataStore.getTodayPrayerTimes();
        var tomorrowTimes = PrayerDataStore.getTomorrowPrayerTimes();

        // --- Empty state: No cached data ---
        if (!PrayerDataStore.hasCachedData() || todayTimes == null) {
            drawEmptyState(dc, w, h);
            return;
        }

        var result = PrayerLogic.getNextPrayerResult(todayTimes, tomorrowTimes);
        var iqama = PrayerDataStore.getTodayIqama();
        var state = result["state"] as String;

        if (state.equals("no_data")) {
            drawEmptyState(dc, w, h);
            return;
        }

        // --- Layout calculations (proportional to screen size) ---
        var headerY = h * 20 / 100;
        var sepY = h * 28 / 100;
        var leftMargin = w * 12 / 100;
        var rightMargin = w - leftMargin;
        var rowStartY = h * 34 / 100;
        var rowSpacing = (h * 50) / (100 * 5);

        // --- Draw countdown header ---
        var tokenIn = WatchUi.loadResource(Rez.Strings.CountdownIn) as String;
        var tokenNow = WatchUi.loadResource(Rez.Strings.CountdownNow) as String;

        var countdownText = "";
        if (state.equals("now")) {
            countdownText = PrayerLogic.formatCountdown(0, result["name"] as String, tokenIn, tokenNow);
        } else if (state.equals("normal")) {
            countdownText = PrayerLogic.formatCountdown(result["remaining"] as Number, result["name"] as String, tokenIn, tokenNow);
        } else if (state.equals("overnight")) {
            countdownText = PrayerLogic.formatCountdown(result["remaining"] as Number, result["name"] as String, tokenIn, tokenNow);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2, headerY,
            Graphics.FONT_SMALL,
            countdownText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // --- Draw separator line ---
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(leftMargin, sepY, w - 2 * leftMargin, 2);

        // --- Determine highlighted prayer index ---
        var highlightIndex = -1;
        if (state.equals("normal")) {
            highlightIndex = result["index"] as Number;
        } else if (state.equals("overnight")) {
            // Past all prayers, Fajr is next
            highlightIndex = 0;
        } else if (state.equals("now")) {
            highlightIndex = result["index"] as Number;
        }

        // --- Draw 5 prayer rows ---
        var times = todayTimes as Dictionary;
        for (var i = 0; i < 5; i++) {
            var key = PrayerLogic.PRAYER_KEYS[i] as String;
            var label = PrayerLogic.PRAYER_LABELS[i] as String;

            // Get prayer time string
            var timeStr = "--:--";
            if (times[key] != null) {
                timeStr = times[key] as String;
            }

            // Get iqama offset string
            var iqamaStr = null as String?;
            if (iqama != null) {
                var iqamaDict = iqama as Dictionary;
                if (iqamaDict[key] != null) {
                    iqamaStr = iqamaDict[key] as String;
                }
            }

            var rowY = rowStartY + (i * rowSpacing) + (rowSpacing / 2);

            if (i == highlightIndex) {
                // Highlighted row: green accent background
                dc.setColor(0x00AA44, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(
                    leftMargin - 4,
                    rowY - rowSpacing / 2 + 2,
                    w - 2 * leftMargin + 8,
                    rowSpacing - 4,
                    8
                );

                // Prayer label (white, same font as normal — green bg is the differentiator)
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    leftMargin, rowY,
                    Graphics.FONT_XTINY,
                    label,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
                );

                // Prayer time (white)
                dc.drawText(
                    w / 2, rowY,
                    Graphics.FONT_XTINY,
                    timeStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );

                // Iqama offset (lighter color for highlighted)
                if (iqamaStr != null && !iqamaStr.equals("")) {
                    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(
                        rightMargin, rowY,
                        Graphics.FONT_XTINY,
                        iqamaStr,
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
                    );
                }
            } else {
                // Normal row: light gray text
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    leftMargin, rowY,
                    Graphics.FONT_XTINY,
                    label,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
                );

                dc.drawText(
                    w / 2, rowY,
                    Graphics.FONT_XTINY,
                    timeStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );

                // Iqama offset (dimmer color for normal rows)
                if (iqamaStr != null && !iqamaStr.equals("")) {
                    dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(
                        rightMargin, rowY,
                        Graphics.FONT_XTINY,
                        iqamaStr,
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
                    );
                }
            }
        }
    }

    //
    // Draw empty state: prayer labels with "--:--" placeholders and no highlight.
    // Matches normal layout structure for visual consistency.
    //
    function drawEmptyState(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var headerY = h * 20 / 100;
        var sepY = h * 28 / 100;
        var leftMargin = w * 12 / 100;
        var rowStartY = h * 34 / 100;
        var rowSpacing = (h * 50) / (100 * 5);

        // Countdown placeholder
        var placeholderText = WatchUi.loadResource(Rez.Strings.NoDataPlaceholder) as String;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2, headerY,
            Graphics.FONT_SMALL,
            placeholderText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Separator line
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(leftMargin, sepY, w - 2 * leftMargin, 2);

        // 5 prayer rows with dashes
        for (var i = 0; i < 5; i++) {
            var label = PrayerLogic.PRAYER_LABELS[i] as String;
            var rowY = rowStartY + (i * rowSpacing) + (rowSpacing / 2);

            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                leftMargin, rowY,
                Graphics.FONT_XTINY,
                label,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.drawText(
                w / 2, rowY,
                Graphics.FONT_XTINY,
                "--:--",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }
}
