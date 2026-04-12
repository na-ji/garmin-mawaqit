import Toybox.System;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Application.Properties;
import Toybox.Lang;

//
// MawaqitServiceDelegate: Lightweight background service for periodic prayer data refresh.
//
// Makes a SINGLE HTTP request to /prayer-times endpoint (well under 30-second timeout
// and 8KB Background.exit() data limit). Does NOT reuse MawaqitService which has a
// 6-step chain unsuitable for background execution.
//
// Annotated (:background) so this code loads in the background process context.
// Background and foreground do NOT share memory -- all data transfer goes through
// Background.exit() -> AppBase.onBackgroundData().
//
(:background)
class MawaqitServiceDelegate extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var slug = Properties.getValue("mosqueSetting") as String or Null;
        if (slug == null || slug.equals("")) {
            Background.exit(null);
            return;
        }

        var url = "https://mawaqit.naj.ovh/api/v1/" + slug + "/prayer-times";
        Communications.makeWebRequest(
            url,
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onReceive)
        );
    }

    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode == 200 && data != null) {
            Background.exit(data);
        } else {
            // Silent failure -- next scheduled run will retry.
            // Do not crash or throw; just exit with null.
            Background.exit(null);
        }
    }
}
