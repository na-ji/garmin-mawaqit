import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Graphics;
import Toybox.Lang;

(:glance)
class GarminMawaqitApp extends Application.AppBase {

    var _currentSlug as String or Null = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        _currentSlug = getMosqueSlug();
        // Do NOT call MawaqitService here — onStart() runs in glance context
        // where MawaqitService is not available. Fetch is triggered in
        // getInitialView() (widget mode only).
    }

    function onStop(state as Dictionary?) as Void {
        // Cleanup if needed
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        // Trigger data fetch when entering widget mode (not glance mode)
        if (_currentSlug != null) {
            MawaqitService.fetchPrayerData(_currentSlug);
        }
        return [new $.MawaqitWidgetView()] as [Views];
    }

    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new $.MawaqitGlanceView()] as [WatchUi.GlanceView];
    }

    function onSettingsChanged() as Void {
        var newSlug = getMosqueSlug();
        if (newSlug != null && !newSlug.equals(_currentSlug)) {
            _currentSlug = newSlug;
            clearCachedData();
            MawaqitService.fetchPrayerData(newSlug);
        } else if (newSlug == null && _currentSlug != null) {
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

