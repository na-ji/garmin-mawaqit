import Toybox.Communications;
import Toybox.Application.Storage;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.System;
import Toybox.Lang;
import Toybox.WatchUi;

//
// MawaqitService: HTTP service that fetches prayer data and mosque metadata
// through sequential API calls. Uses a class (not module) because
// method(:callback) requires an object context for makeWebRequest callbacks.
//
class MawaqitService {

    static const API_BASE = "https://mawaqit.naj.ovh/api/v1/";

    // Singleton instance
    private static var _instance as MawaqitService or Null = null;

    var _fetchSlug as String or Null = null;
    var _fetchMonth as Number = 0;
    var _fetchNextMonth as Number = 0;
    var _isFetching as Boolean = false;
    var _fetchStep as Number = -1;

    function initialize() {
    }

    //
    // Returns (and lazily creates) the singleton instance.
    //
    static function getInstance() as MawaqitService {
        if (_instance == null) {
            _instance = new MawaqitService();
        }
        return _instance;
    }

    //
    // Static entry point: kicks off the sequential request chain.
    // Callers use MawaqitService.fetchPrayerData(slug).
    //
    static function fetchPrayerData(slug as String) as Void {
        getInstance()._startFetch(slug);
    }

    //
    // Instance method that actually starts the fetch chain.
    //
    function _startFetch(slug as String) as Void {
        if (_isFetching) {
            return;
        }
        _isFetching = true;
        _fetchSlug = slug;

        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        _fetchMonth = info.month as Number;
        _fetchNextMonth = (_fetchMonth % 12) + 1;

        _fetchStep = -1;
        _processNextStep();
    }

    //
    // Advances through the fetch chain step by step.
    //
    function _processNextStep() as Void {
        _fetchStep++;
        switch (_fetchStep) {
            case 0:
                _fetchCalendar(_fetchMonth);
                break;
            case 1:
                _fetchCalendar(_fetchNextMonth);
                break;
            case 2:
                _fetchIqama(_fetchMonth);
                break;
            case 3:
                _fetchIqama(_fetchNextMonth);
                break;
            case 4:
                _fetchMetadata();
                break;
            case 5:
                _fetchPrayerTimes();
                break;
            default:
                // Fetch chain complete
                _isFetching = false;
                break;
        }
    }

    //
    // Fetches one month of calendar prayer times.
    //
    function _fetchCalendar(month as Number) as Void {
        var url = API_BASE + _fetchSlug + "/calendar/" + month;
        Communications.makeWebRequest(
            url,
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onCalendarReceive)
        );
    }

    //
    // Callback for calendar endpoint responses.
    // Converts each day's dictionary to an array before storing to eliminate
    // repeated key strings. Array order: [fajr, sunrise, dohr, asr, maghreb, icha]
    //
    function onCalendarReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode == 200 && data != null) {
            var month = (_fetchStep == 0) ? _fetchMonth : _fetchNextMonth;
            var arr = data as Array;
            var compact = new [arr.size()];
            for (var i = 0; i < arr.size(); i++) {
                var day = arr[i] as Dictionary;
                compact[i] = [day["fajr"], day["sunrise"], day["dohr"], day["asr"], day["maghreb"], day["icha"]];
            }
            Storage.setValue("cal_" + month, compact);
            _processNextStep();
        } else {
            _isFetching = false;
        }
    }

    //
    // Fetches one month of iqama offsets.
    //
    function _fetchIqama(month as Number) as Void {
        var url = API_BASE + _fetchSlug + "/calendar-iqama/" + month;
        Communications.makeWebRequest(
            url,
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onIqamaReceive)
        );
    }

    //
    // Callback for iqama endpoint responses.
    // Converts each day's dictionary to an array before storing.
    // Array order: [fajr, dohr, asr, maghreb, icha]
    //
    function onIqamaReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode == 200 && data != null) {
            var month = (_fetchStep == 2) ? _fetchMonth : _fetchNextMonth;
            var arr = data as Array;
            var compact = new [arr.size()];
            for (var i = 0; i < arr.size(); i++) {
                var day = arr[i] as Dictionary;
                compact[i] = [day["fajr"], day["dohr"], day["asr"], day["maghreb"], day["icha"]];
            }
            Storage.setValue("iqama_" + month, compact);
            _processNextStep();
        } else {
            _isFetching = false;
        }
    }

    //
    // Fetches mosque metadata (D-08): name, timezone, jumua, jumua2, shuruq, hijriAdjustment.
    //
    function _fetchMetadata() as Void {
        var url = API_BASE + _fetchSlug + "/metadata";
        Communications.makeWebRequest(
            url,
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onMetadataReceive)
        );
    }

    //
    // Callback for metadata endpoint response.
    //
    function onMetadataReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode == 200 && data != null) {
            Storage.setValue("mosqueMeta", data);
            _processNextStep();
        } else {
            _isFetching = false;
        }
    }

    //
    // Fetches today's prayer times from the /prayer-times endpoint.
    //
    function _fetchPrayerTimes() as Void {
        var url = API_BASE + _fetchSlug + "/prayer-times";
        Communications.makeWebRequest(
            url,
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onPrayerTimesReceive)
        );
    }

    //
    // Callback for prayer-times endpoint response.
    //
    function onPrayerTimesReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode == 200 && data != null) {
            var d = data as Dictionary;
            var compact = [d["fajr"], d["sunrise"], d["dohr"], d["asr"], d["maghreb"], d["icha"]];
            Storage.setValue("todayTimes", compact);

            // Record fetch metadata
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var dateString = info.year + "-" + info.month + "-" + info.day;
            Storage.setValue("lastFetchDate", dateString);
            Storage.setValue("lastFetchSlug", _fetchSlug);

            _isFetching = false;

            // Refresh display with new data
            WatchUi.requestUpdate();
        } else {
            _isFetching = false;
        }
    }
}
