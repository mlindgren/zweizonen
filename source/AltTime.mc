import Toybox.Lang;
import Toybox.Position;
import Toybox.Time;
import Toybox.Time.Gregorian;

//! Alternate time zone. Cities are resolved through Gregorian.localMoment so
//! the device's time zone database applies DST rules.
module AltTime {

    //! [label, latitude, longitude]. Index matches the AltZone setting value in
    //! resources/settings/settings.xml; index 0 is UTC.
    const CITIES = [
        ["UTC", 0.0, 0.0],
        ["LON", 51.5074, -0.1278],
        ["PAR", 48.8566, 2.3522],
        ["BER", 52.5200, 13.4050],
        ["ATH", 37.9838, 23.7275],
        ["CAI", 30.0444, 31.2357],
        ["JNB", -26.2041, 28.0473],
        ["NBO", -1.2921, 36.8219],
        ["IST", 41.0082, 28.9784],
        ["MOW", 55.7558, 37.6173],
        ["DXB", 25.2048, 55.2708],
        ["DEL", 28.6139, 77.2090],
        ["BKK", 13.7563, 100.5018],
        ["SIN", 1.3521, 103.8198],
        ["HKG", 22.3193, 114.1694],
        ["SHA", 31.2304, 121.4737],
        ["SEL", 37.5665, 126.9780],
        ["TYO", 35.6762, 139.6503],
        ["SYD", -33.8688, 151.2093],
        ["AKL", -36.8485, 174.7633],
        ["HNL", 21.3069, -157.8583],
        ["ANC", 61.2181, -149.9003],
        ["LAX", 34.0522, -118.2437],
        ["SEA", 47.6062, -122.3321],
        ["PHX", 33.4484, -112.0740],
        ["DEN", 39.7392, -104.9903],
        ["MEX", 19.4326, -99.1332],
        ["CHI", 41.8781, -87.6298],
        ["NYC", 40.7128, -74.0060],
        ["TOR", 43.6532, -79.3832],
        ["SAO", -23.5505, -46.6333],
        ["BUE", -34.6037, -58.3816],
    ] as Array<[String, Float, Float]>;

    function label(index as Number) as String {
        return CITIES[clamp(index)][0];
    }

    //! Offset from UTC in seconds, including DST, for the city at index.
    function offsetSeconds(index as Number, now as Time.Moment) as Number {
        index = clamp(index);
        if (index == 0) {
            return 0;
        }
        var city = CITIES[index];
        var location = new Position.Location({
            :latitude => city[1],
            :longitude => city[2],
            :format => :degrees
        });
        var local = Gregorian.localMoment(location, now);
        return local != null ? local.getOffset() : 0;
    }

    function clamp(index as Number) as Number {
        return (index < 0 || index >= CITIES.size()) ? 0 : index;
    }
}
