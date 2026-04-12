import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Graphics;
import Toybox.Lang;

class GarminMawaqitApp extends Application.AppBase {

    var _currentSlug as String or Null = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        _currentSlug = getMosqueSlug();
        if (_currentSlug != null) {
            MawaqitService.fetchPrayerData(_currentSlug);
        }
    }

    function onStop(state as Dictionary?) as Void {
        // Cleanup if needed
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        // Stub widget view -- replaced in Phase 3
        return [new $.MawaqitWidgetView()] as [Views];
    }

    (:glance)
    function getGlanceView() {
        return [new $.MawaqitGlanceView()];
    }

    function onSettingsChanged() as Void {
        var newSlug = getMosqueSlug();
        if (newSlug != null && !newSlug.equals(_currentSlug)) {
            // Mosque slug changed to a new valid value
            _currentSlug = newSlug;
            clearCachedData();
            MawaqitService.fetchPrayerData(newSlug);
        } else if (newSlug == null && _currentSlug != null) {
            // User cleared the mosque slug
            _currentSlug = null;
            clearCachedData();
        }
        WatchUi.requestUpdate();
    }

    function getMosqueSlug() as String or Null {
        var slug = Properties.getValue("mosqueSetting") as String or Null;
        if (slug == null || slug.equals("")) {
            return null;
        }
        return slug;
    }

    function clearCachedData() as Void {
        Storage.deleteValue("mosqueMeta");
        for (var month = 1; month <= 12; month++) {
            Storage.deleteValue("cal_" + month);
            Storage.deleteValue("iqama_" + month);
        }
        Storage.deleteValue("todayTimes");
        Storage.deleteValue("lastFetchDate");
        Storage.deleteValue("lastFetchSlug");
    }
}

//
// Stub Widget View -- replaced in Phase 3
//
class MawaqitWidgetView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        // Show fetch status on screen for debugging
        var slug = Properties.getValue("mosqueSetting") as String or Null;
        var status = "No mosque";
        if (slug != null && !slug.equals("")) {
            status = slug;
            var times = Storage.getValue("todayTimes");
            if (times != null) {
                status = "OK: " + slug;
            } else {
                status = "Fetching: " + slug;
            }
        }

        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            Graphics.FONT_SMALL,
            status,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
