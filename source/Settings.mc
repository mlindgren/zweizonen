import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! User settings. Values live in Application.Properties, so they can be edited
//! from the phone (Connect IQ store installs) or from the on-watch menu.
module Settings {

    const KEYS = ["AltZone", "HourColor", "ArcTopLeft", "ArcTopRight", "ArcBottomLeft", "ArcBottomRight"];

    function title(key as String) as ResourceId {
        switch (key) {
            case "AltZone":        return Rez.Strings.AltZoneTitle;
            case "HourColor":      return Rez.Strings.HourColorTitle;
            case "ArcTopLeft":     return Rez.Strings.ArcTopLeftTitle;
            case "ArcTopRight":    return Rez.Strings.ArcTopRightTitle;
            case "ArcBottomLeft":  return Rez.Strings.ArcBottomLeftTitle;
        }
        return Rez.Strings.ArcBottomRightTitle;
    }

    function defaultValue(key as String) as Number {
        switch (key) {
            case "HourColor":      return 0xFFAA00;
            case "ArcTopLeft":     return Metrics.BODY_BATTERY;
            case "ArcTopRight":    return Metrics.WATCH_BATTERY;
            case "ArcBottomLeft":  return Metrics.STEPS;
            case "ArcBottomRight": return Metrics.RECOVERY;
        }
        return 0;
    }

    //! [label, value] pairs; must match the list entries in resources/settings/settings.xml
    function options(key as String) as Array<[ResourceId, Number]> {
        if (key.equals("AltZone")) {
            return [
            [Rez.Strings.City0, 0],
            [Rez.Strings.City1, 1],
            [Rez.Strings.City2, 2],
            [Rez.Strings.City3, 3],
            [Rez.Strings.City4, 4],
            [Rez.Strings.City5, 5],
            [Rez.Strings.City6, 6],
            [Rez.Strings.City7, 7],
            [Rez.Strings.City8, 8],
            [Rez.Strings.City9, 9],
            [Rez.Strings.City10, 10],
            [Rez.Strings.City11, 11],
            [Rez.Strings.City12, 12],
            [Rez.Strings.City13, 13],
            [Rez.Strings.City14, 14],
            [Rez.Strings.City15, 15],
            [Rez.Strings.City16, 16],
            [Rez.Strings.City17, 17],
            [Rez.Strings.City18, 18],
            [Rez.Strings.City19, 19],
            [Rez.Strings.City20, 20],
            [Rez.Strings.City21, 21],
            [Rez.Strings.City22, 22],
            [Rez.Strings.City23, 23],
            [Rez.Strings.City24, 24],
            [Rez.Strings.City25, 25],
            [Rez.Strings.City26, 26],
            [Rez.Strings.City27, 27],
            [Rez.Strings.City28, 28],
            [Rez.Strings.City29, 29],
            [Rez.Strings.City30, 30],
            [Rez.Strings.City31, 31],
            ];
        }
        if (key.equals("HourColor")) {
            return [
                [Rez.Strings.ColorAmber, 0xFFAA00],
                [Rez.Strings.ColorWhite, 0xFFFFFF],
                [Rez.Strings.ColorRed, 0xFF3030],
                [Rez.Strings.ColorOrange, 0xFF7700],
                [Rez.Strings.ColorYellow, 0xFFEE00],
                [Rez.Strings.ColorGreen, 0x33FF66],
                [Rez.Strings.ColorCyan, 0x00DDFF],
                [Rez.Strings.ColorBlue, 0x3388FF],
                [Rez.Strings.ColorPurple, 0xAA66FF],
                [Rez.Strings.ColorPink, 0xFF55AA]
            ];
        }
        return [
            [Rez.Strings.MetricNone, Metrics.NONE],
            [Rez.Strings.MetricBodyBattery, Metrics.BODY_BATTERY],
            [Rez.Strings.MetricWatchBattery, Metrics.WATCH_BATTERY],
            [Rez.Strings.MetricSteps, Metrics.STEPS],
            [Rez.Strings.MetricRecovery, Metrics.RECOVERY],
            [Rez.Strings.MetricIntensity, Metrics.INTENSITY],
            [Rez.Strings.MetricFloors, Metrics.FLOORS]
        ];
    }

    function getNumber(key as String) as Number {
        try {
            var value = Application.Properties.getValue(key);
            if (value instanceof Number) {
                return value;
            }
        } catch (e) {
        }
        return defaultValue(key);
    }

    function setNumber(key as String, value as Number) as Void {
        Application.Properties.setValue(key, value);
    }

    //! Label of the currently selected option, or null if the value isn't in the list.
    function currentLabel(key as String) as ResourceId? {
        var value = getNumber(key);
        var opts = options(key);
        for (var i = 0; i < opts.size(); i++) {
            if (opts[i][1] == value) {
                return opts[i][0];
            }
        }
        return null;
    }
}
