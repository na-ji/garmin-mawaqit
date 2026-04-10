using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Application.Storage;
using Toybox.WatchUi;
using Toybox.System;
using Toybox.Graphics;

class GarminMawaqitApp extends Application.AppBase {

    var _currentSlug as String or Null = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        _currentSlug = getMosqueSlug();
        if (_currentSlug != null) {
            // TODO: Plan 02 will trigger fetchPrayerData(_currentSlug) here
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
    function getGlanceView() as [GlanceView] or Null {
        return [new $.MawaqitGlanceView()] as [GlanceView];
    }

    function onSettingsChanged() as Void {
        var newSlug = getMosqueSlug();
        if (newSlug != null && !newSlug.equals(_currentSlug)) {
            // Mosque slug changed to a new valid value
            _currentSlug = newSlug;
            clearCachedData();
            // TODO: Plan 02 will trigger fetchPrayerData(newSlug) here
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
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            Graphics.FONT_MEDIUM,
            "Mawaqit",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}

//
// Stub Glance View -- replaced in Phase 2
//
(:glance)
class MawaqitGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    (:glance)
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            0,
            dc.getHeight() / 2,
            Graphics.FONT_GLANCE,
            "Mawaqit",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
