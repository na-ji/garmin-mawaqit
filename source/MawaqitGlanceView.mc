import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Lang;

//
// MawaqitGlanceView: Sunrise-inspired 3-row Glance for prayer times.
//
// Layout:
//   Top line:    Next prayer name + countdown (e.g., "Asr in 2h 15m")
//   Middle:      5-segment colored progress bar with white current-time marker
//   Bottom line: Previous prayer time (left) and next prayer time (right)
//
// Empty states:
//   D-09: No mosque configured -> "Mawaqit" + "Set mosque in Connect app"
//   D-10: Data unavailable -> "-- in --" + empty bar + "--:--" placeholders
//
// Timer refreshes countdown: 30s normally, 1s when countdown < 60s.
// All direct Dc drawing, no XML layouts, no debug print calls.
//
(:glance)
class MawaqitGlanceView extends WatchUi.GlanceView {

    var _timer as Timer.Timer or Null = null;
    var _fastTimer as Boolean = false;

    function initialize() {
        GlanceView.initialize();
    }

    function onShow() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), 30000, true);
        _fastTimer = false;
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    //
    // Timer callback: request redraw and adjust interval based on countdown proximity.
    // When countdown < 60s, switch to 1s updates for seconds accuracy (D-05).
    // When back above 60s, revert to 30s updates.
    //
    (:glance)
    function onTimer() as Void {
        WatchUi.requestUpdate();

        // Check if we need to adjust timer interval
        var todayTimes = PrayerDataStore.getTodayPrayerTimes();
        var tomorrowTimes = PrayerDataStore.getTomorrowPrayerTimes();
        var result = PrayerLogic.getNextPrayerResult(todayTimes, tomorrowTimes);
        var state = result["state"] as String;

        var needFast = false;
        if (state.equals("normal") || state.equals("overnight")) {
            var remaining = result["remaining"] as Number;
            if (remaining < 60 && remaining > 0) {
                needFast = true;
            }
        }

        if (needFast && !_fastTimer) {
            if (_timer != null) {
                _timer.stop();
                _timer.start(method(:onTimer), 1000, true);
            }
            _fastTimer = true;
        } else if (!needFast && _fastTimer) {
            if (_timer != null) {
                _timer.stop();
                _timer.start(method(:onTimer), 30000, true);
            }
            _fastTimer = false;
        }
    }

    //
    // Core drawing: renders the 3-row Sunrise-inspired glance layout.
    // Handles empty states first, then draws top line, progress bar, bottom line.
    //
    (:glance)
    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        // --- Empty state: No mosque configured (D-09) ---
        if (!PrayerDataStore.isMosqueConfigured()) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                0, h / 3,
                Graphics.FONT_GLANCE,
                "Mawaqit",
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            var noMosqueText = WatchUi.loadResource(Rez.Strings.GlanceNoMosque) as String;
            dc.drawText(
                0, 2 * h / 3,
                Graphics.FONT_SYSTEM_XTINY,
                noMosqueText,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            return;
        }

        // --- Empty state: No cached data (D-10) ---
        if (!PrayerDataStore.hasCachedData()) {
            drawEmptyState(dc, w, h);
            return;
        }

        // --- Get prayer data ---
        var todayTimes = PrayerDataStore.getTodayPrayerTimes();
        var tomorrowTimes = PrayerDataStore.getTomorrowPrayerTimes();

        if (todayTimes == null) {
            drawEmptyState(dc, w, h);
            return;
        }

        var result = PrayerLogic.getNextPrayerResult(todayTimes, tomorrowTimes);
        var state = result["state"] as String;

        if (state.equals("no_data")) {
            drawEmptyState(dc, w, h);
            return;
        }

        // --- Layout constants ---
        var barHeight = 6;
        var barPadding = 5;
        var barX = barPadding;
        var barWidth = w - (barPadding * 2);

        // Vertical layout: divide into 3 rows
        // Top text centered in upper third
        var topY = h / 4;
        // Bar in the middle
        var barY = h / 2 - barHeight / 2;
        // Bottom text centered in lower third
        var bottomY = 3 * h / 4;

        // --- Draw top line (D-01, D-04, D-05, D-06, D-07) ---
        var tokenIn = WatchUi.loadResource(Rez.Strings.CountdownIn) as String;
        var tokenNow = WatchUi.loadResource(Rez.Strings.CountdownNow) as String;

        var topText = "";
        if (state.equals("now")) {
            topText = PrayerLogic.formatCountdown(0, result["name"] as String, tokenIn, tokenNow);
        } else if (state.equals("normal")) {
            topText = PrayerLogic.formatCountdown(result["remaining"] as Number, result["name"] as String, tokenIn, tokenNow);
        } else if (state.equals("overnight")) {
            topText = PrayerLogic.formatCountdown(result["remaining"] as Number, result["name"] as String, tokenIn, tokenNow);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            0, topY,
            Graphics.FONT_GLANCE,
            topText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // --- Draw progress bar (D-02) ---
        var segments = PrayerLogic.buildSegments(todayTimes);
        var currentSec = PrayerLogic.getCurrentSeconds();

        // Determine active segment index
        var activeIdx = -1;
        for (var i = 0; i < segments.size(); i++) {
            var seg = segments[i] as Dictionary;
            var segStart = seg["start"] as Number;
            var segEnd = seg["end"] as Number;
            if (currentSec >= segStart && currentSec < segEnd) {
                activeIdx = i;
                break;
            }
        }

        // Draw each segment
        for (var i = 0; i < segments.size(); i++) {
            var seg = segments[i] as Dictionary;
            var segStart = seg["start"] as Number;
            var segEnd = seg["end"] as Number;
            var segColor = seg["color"] as Number;

            var segX = barX + ((segStart.toFloat() / 86400.0) * barWidth).toNumber();
            var segW = (((segEnd - segStart).toFloat() / 86400.0) * barWidth).toNumber();

            // Ensure minimum 1px width for visibility
            if (segW < 1) {
                segW = 1;
            }

            var color;
            if (i == activeIdx) {
                color = segColor;
            } else {
                color = PrayerLogic.getDimColor(segColor);
            }

            dc.setColor(color, Graphics.COLOR_BLACK);
            dc.fillRectangle(segX, barY, segW, barHeight);
        }

        // Draw white current-time marker
        var markerX = barX + ((currentSec.toFloat() / 86400.0) * barWidth).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.fillRectangle(markerX - 1, barY - 2, 3, barHeight + 4);

        // --- Draw bottom line (D-03) ---
        var prevTime = "--:--";
        var nextTime = "--:--";

        if (state.equals("normal")) {
            if (result["prev"] != null) {
                prevTime = (result["prev"] as Dictionary)["time"] as String;
            }
            nextTime = result["time"] as String;
        } else if (state.equals("now")) {
            prevTime = result["time"] as String;
            if (result["nextPrayer"] != null) {
                nextTime = (result["nextPrayer"] as Dictionary)["time"] as String;
            }
        } else if (state.equals("overnight")) {
            if (result["prev"] != null) {
                prevTime = (result["prev"] as Dictionary)["time"] as String;
            }
            nextTime = result["time"] as String;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            barX, bottomY,
            Graphics.FONT_SYSTEM_XTINY,
            prevTime,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            barX + barWidth, bottomY,
            Graphics.FONT_SYSTEM_XTINY,
            nextTime,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    //
    // Draw the D-10 empty state: "-- in --" top, dim gray bar, "--:--" bottom.
    //
    (:glance)
    function drawEmptyState(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var barHeight = 6;
        var barPadding = 5;
        var barX = barPadding;
        var barWidth = w - (barPadding * 2);
        var topY = h / 4;
        var barY = h / 2 - barHeight / 2;
        var bottomY = 3 * h / 4;

        var placeholderText = WatchUi.loadResource(Rez.Strings.NoDataPlaceholder) as String;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            0, topY,
            Graphics.FONT_GLANCE,
            placeholderText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Single dim gray bar
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.fillRectangle(barX, barY, barWidth, barHeight);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            barX, bottomY,
            Graphics.FONT_SYSTEM_XTINY,
            "--:--",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            barX + barWidth, bottomY,
            Graphics.FONT_SYSTEM_XTINY,
            "--:--",
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
