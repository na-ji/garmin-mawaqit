using Toybox.Communications;
using Toybox.Application.Storage;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.System;
using Toybox.Lang;
using Toybox.WatchUi;

module MawaqitService {

    const API_BASE = "https://mawaqit.naj.ovh/api/v1/";

    var _fetchSlug as String or Null = null;
    var _fetchMonth as Number = 0;
    var _fetchNextMonth as Number = 0;
    var _isFetching as Boolean = false;
    var _fetchStep as Number = -1;

    //
    // Entry point: kicks off the sequential request chain.
    // Fetches: calendar (current month), calendar (next month),
    //          iqama (current month), iqama (next month),
    //          metadata, prayer-times
    //
    function fetchPrayerData(slug as String) as Void {
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
    // Stores the Array of day objects under "cal_{month}" key.
    //
    function onCalendarReceive(responseCode as Number, data) as Void {
        if (responseCode == 200 && data != null) {
            // Determine which month was fetched based on step
            var month = (_fetchStep == 0) ? _fetchMonth : _fetchNextMonth;
            Storage.setValue("cal_" + month, data);
            _processNextStep();
        } else {
            // Abort chain silently (D-06: leave cached data intact)
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
    // Stores the Array of iqama offset objects under "iqama_{month}" key.
    //
    function onIqamaReceive(responseCode as Number, data) as Void {
        if (responseCode == 200 && data != null) {
            // Determine which month was fetched based on step
            var month = (_fetchStep == 2) ? _fetchMonth : _fetchNextMonth;
            Storage.setValue("iqama_" + month, data);
            _processNextStep();
        } else {
            // Abort chain silently (D-06: leave cached data intact)
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
    // Stores the full Dictionary under "mosqueMeta" key (D-01/D-08).
    //
    function onMetadataReceive(responseCode as Number, data) as Void {
        if (responseCode == 200 && data != null) {
            Storage.setValue("mosqueMeta", data);
            _processNextStep();
        } else {
            // Abort chain silently (D-06: leave cached data intact)
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
    // Stores today's times and records fetch metadata, then refreshes UI.
    //
    function onPrayerTimesReceive(responseCode as Number, data) as Void {
        if (responseCode == 200 && data != null) {
            Storage.setValue("todayTimes", data);

            // Record fetch metadata
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var dateString = info.year + "-" + info.month + "-" + info.day;
            Storage.setValue("lastFetchDate", dateString);
            Storage.setValue("lastFetchSlug", _fetchSlug);

            _isFetching = false;

            // Refresh display with new data
            WatchUi.requestUpdate();
        } else {
            // Abort silently (D-06: leave cached data intact)
            _isFetching = false;
        }
    }
}
