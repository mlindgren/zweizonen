import Toybox.Activity;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

class WatchFaceView extends WatchUi.WatchFace {

    // Font sizes as a fraction of screen height
    private const TIME_SIZE = 0.40;
    private const ALT_SIZE = 0.17;
    private const SEC_SIZE = 0.095;
    private const TEXT_SIZE = 0.075;
    private const LABEL_SIZE = 0.048;

    // In the vector fonts used here, digits are about half the font height tall
    // and centered in the font box.
    private const DIGIT_HEIGHT = 0.5;
    // ...but sit slightly high in the box; shift down by this share of the font height
    private const DIGIT_DROP = 0.024;

    // Quadrant arcs: gap on either side of the 12/3/6/9 axes, in degrees
    private const ARC_GAP = 12;
    private const ARC_SPAN = 90 - 2 * ARC_GAP;
    private const ARC_TRACK_COLOR = 0x262626;

    // Draws crosshair lines through the screen center to check alignment
    private const DEBUG_GUIDES = false;

    private const DIM_COLOR = 0x9A9A9A;
    private const LABEL_COLOR = 0x8A8A8A;

    private var _w as Number = 0;
    private var _h as Number = 0;
    private var _cx as Number = 0;
    private var _cy as Number = 0;
    private var _arcRadius as Number = 0;
    private var _arcPen as Number = 0;

    // Vertical centers of each row, computed in onLayout
    private var _weatherY as Number = 0;
    private var _dateY as Number = 0;
    private var _altY as Number = 0;
    private var _sunY as Number = 0;

    private var _timeFont as FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var _secFont as FontType = Graphics.FONT_TINY;
    private var _altFont as FontType = Graphics.FONT_MEDIUM;
    private var _textFont as FontType = Graphics.FONT_SMALL;
    private var _labelFont as FontType = Graphics.FONT_XTINY;

    private var _isAwake as Boolean = true;

    // Settings
    private var _hourColor as Number = 0xFFAA00;
    private var _arcMetrics as Array<Number> = [1, 2, 3, 4];
    private var _altZone as Number = 0;

    // Values refreshed once per minute (or when the 12/24h setting changes)
    private var _lastMinute as Number = -1;
    private var _last24Hour as Boolean = false;
    private var _dateText as String = "";
    private var _tempText as String = "--°";
    private var _weatherIconId as ResourceId?;
    private var _weatherIcon as BitmapResource?;
    private var _sunText as String = "--:--";
    private var _sunIsSunset as Boolean = true;
    private var _altOffset as Number = 0;

    private var _sunriseIcon as BitmapResource?;
    private var _sunsetIcon as BitmapResource?;
    private var _arcIcons as Array<BitmapResource?> = [null, null, null, null];

    function initialize() {
        WatchFace.initialize();
        loadSettings();
    }

    function loadSettings() as Void {
        _hourColor = Settings.getNumber("HourColor");
        // Quadrant order used by drawArcs: TR, TL, BL, BR
        _arcMetrics = [
            Settings.getNumber("ArcTopRight"),
            Settings.getNumber("ArcTopLeft"),
            Settings.getNumber("ArcBottomLeft"),
            Settings.getNumber("ArcBottomRight")
        ];
        _altZone = Settings.getNumber("AltZone");
        for (var q = 0; q < 4; q++) {
            var id = Metrics.getIcon(_arcMetrics[q]);
            _arcIcons[q] = id != null ? WatchUi.loadResource(id) as BitmapResource : null;
        }
        _lastMinute = -1;
    }

    function onLayout(dc as Dc) as Void {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;
        _arcPen = (_w * 0.046).toNumber();
        _arcRadius = _cx - _arcPen / 2 - (_w * 0.01).toNumber();

        _timeFont = vectorFont(["BionicBold", "RobotoCondensedBold"], TIME_SIZE, Graphics.FONT_NUMBER_THAI_HOT);
        _secFont = vectorFont(["BionicBold", "RobotoCondensedBold"], SEC_SIZE, Graphics.FONT_TINY);
        _altFont = vectorFont(["BionicBold", "RobotoCondensedBold"], ALT_SIZE, Graphics.FONT_MEDIUM);
        _textFont = vectorFont(["RobotoCondensedBold"], TEXT_SIZE, Graphics.FONT_SMALL);
        _labelFont = vectorFont(["RobotoCondensedBold"], LABEL_SIZE, Graphics.FONT_XTINY);

        _sunriseIcon = WatchUi.loadResource(Rez.Drawables.WiSunrise) as BitmapResource;
        _sunsetIcon = WatchUi.loadResource(Rez.Drawables.WiSunset) as BitmapResource;

        // The main time is centered on the screen; other rows stack around it
        // using the visible digit/cap heights rather than the font boxes.
        var gap = (_h * 0.05).toNumber();
        var timeHalf = digitHalf(_timeFont);
        var textHalf = digitHalf(_textFont);
        var altHalf = digitHalf(_altFont);
        _dateY = _cy - timeHalf - gap - textHalf;
        _weatherY = _dateY - textHalf - gap - (_h * 0.035).toNumber();
        _altY = _cy + timeHalf + gap + altHalf;
        _sunY = _altY + altHalf + gap + (_h * 0.03).toNumber();
    }

    private function digitHalf(font as FontType) as Number {
        return (dcFontHeight(font) * DIGIT_HEIGHT / 2).toNumber();
    }

    private function digitDrop(font as FontType) as Number {
        return (dcFontHeight(font) * DIGIT_DROP).toNumber();
    }

    private function dcFontHeight(font as FontType) as Number {
        return Graphics.getFontAscent(font) + Graphics.getFontDescent(font);
    }

    //! Returns a scalable system font sized as a fraction of screen height,
    //! or the given built-in font on devices without vector font support.
    private function vectorFont(faces as Array<String>, heightFraction as Float, fallback as FontType) as FontType {
        if (Graphics has :getVectorFont) {
            var font = Graphics.getVectorFont({:face => faces, :size => (_h * heightFraction).toNumber()});
            if (font != null) {
                return font;
            }
        }
        return fallback;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        var clock = System.getClockTime();
        var is24Hour = System.getDeviceSettings().is24Hour;
        if (clock.min != _lastMinute || is24Hour != _last24Hour) {
            refreshMinuteData();
            _lastMinute = clock.min;
            _last24Hour = is24Hour;
        }

        if (_isAwake) {
            drawArcs(dc);
            drawWeather(dc);
            drawSun(dc);
            drawTexts(dc, clock, 0, 0);
        } else {
            // Always-on: same text layout, no arcs/fields/seconds, shifted a
            // few pixels each minute to limit AMOLED burn-in.
            var step = (_w * 0.01).toNumber();
            drawTexts(dc, clock, ((clock.min % 3) - 1) * step, (((clock.min / 3) % 3) - 1) * step);
        }

        if (DEBUG_GUIDES) {
            dc.setPenWidth(1);
            dc.setColor(0xFF00FF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(0, _cy, _w, _cy);
            dc.drawLine(_cx, 0, _cx, _h);
        }
    }

    function onEnterSleep() as Void {
        _isAwake = false;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _isAwake = true;
        WatchUi.requestUpdate();
    }

    // ---- Data -------------------------------------------------------------

    private function refreshMinuteData() as Void {
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_MEDIUM);
        _dateText = (info.day_of_week as String).toUpper() + " " + info.day + " " + (info.month as String).toUpper();

        _altOffset = AltTime.offsetSeconds(_altZone, now);

        var iconId = Rez.Drawables.WiNa;
        _tempText = "--°";
        _sunText = "--:--";

        var conditions = Weather.getCurrentConditions();
        var isNight = false;
        var location = findLocation(conditions);
        if (location != null) {
            // Show whichever sun event comes next: sunset by day, sunrise by night.
            // Yesterday..tomorrow are checked because which day the API picks
            // depends on the date boundary, not on the sun.
            var next = null as Time.Moment?;
            for (var d = -1; d <= 1; d++) {
                var day = now.add(new Time.Duration(d * Gregorian.SECONDS_PER_DAY));
                var events = [Weather.getSunrise(location, day), Weather.getSunset(location, day)];
                for (var i = 0; i < 2; i++) {
                    var event = events[i];
                    if (event != null && event.greaterThan(now) && (next == null || event.lessThan(next))) {
                        next = event;
                        _sunIsSunset = (i == 1);
                    }
                }
            }
            if (next != null) {
                var sunInfo = Gregorian.info(next, Time.FORMAT_SHORT);
                _sunText = formatClock(sunInfo.hour as Number, sunInfo.min as Number, true);
                isNight = !_sunIsSunset;
            }
        }

        if (conditions != null) {
            var temp = conditions.temperature;
            if (temp != null) {
                if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
                    temp = temp * 9.0 / 5.0 + 32;
                }
                _tempText = temp.toFloat().format("%.0f") + "°";
            }
            iconId = WeatherIcons.resourceFor(conditions.condition, isNight);
        }

        if (iconId != _weatherIconId) {
            _weatherIconId = iconId;
            _weatherIcon = WatchUi.loadResource(iconId) as BitmapResource;
        }
    }

    //! Location for sunrise/sunset, from the first source that has a valid fix:
    //! weather observation location, last known position, activity GPS, and
    //! finally the last location we saw (kept in storage).
    private function findLocation(conditions as Weather.CurrentConditions?) as Position.Location? {
        var sources = [
            conditions != null ? conditions.observationLocationPosition : null,
            Position.getInfo().position,
            Activity.getActivityInfo().currentLocation
        ];
        for (var i = 0; i < sources.size(); i++) {
            var degrees = validDegrees(sources[i]);
            if (degrees != null) {
                Application.Storage.setValue("lastLocation", degrees);
                return sources[i];
            }
        }
        var saved = Application.Storage.getValue("lastLocation");
        if (saved instanceof Array && saved.size() == 2) {
            return new Position.Location({:latitude => saved[0], :longitude => saved[1], :format => :degrees});
        }
        return null;
    }

    //! [lat, lon] in degrees, or null for a missing or placeholder position
    //! (Garmin reports "no fix" as 180,180; 0,0 is also treated as no fix).
    private function validDegrees(location as Position.Location?) as [Double, Double]? {
        if (location == null) {
            return null;
        }
        var d = location.toDegrees();
        var lat = d[0].toDouble();
        var lon = d[1].toDouble();
        if (lat.abs() > 90 || lon.abs() > 180 || (lat == 0.0d && lon == 0.0d)) {
            return null;
        }
        return [lat, lon];
    }

    private function hourText(hour as Number) as String {
        if (System.getDeviceSettings().is24Hour) {
            return hour.format("%02d");
        }
        hour = hour % 12;
        return (hour == 0 ? 12 : hour).toString();
    }

    //! "HH:MM", with a trailing "a"/"p" in 12-hour mode when withSuffix is set.
    private function formatClock(hour as Number, min as Number, withSuffix as Boolean) as String {
        var text = hourText(hour) + ":" + min.format("%02d");
        if (withSuffix && !System.getDeviceSettings().is24Hour) {
            text += hour < 12 ? "a" : "p";
        }
        return text;
    }

    private function amPm(hour as Number) as String? {
        if (System.getDeviceSettings().is24Hour) {
            return null;
        }
        return hour < 12 ? "AM" : "PM";
    }

    // ---- Drawing ----------------------------------------------------------

    //! Date, main time and alternate time; shared by the normal and always-on views.
    private function drawTexts(dc as Dc, clock as System.ClockTime, dx as Number, dy as Number) as Void {
        var textColor = _isAwake ? Graphics.COLOR_WHITE : DIM_COLOR;
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + dx, _dateY + dy, _textFont, _dateText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawTime(dc, clock, textColor, dx, dy);

        var alt = Gregorian.utcInfo(Time.now().add(new Time.Duration(_altOffset)), Time.FORMAT_SHORT);
        var altHour = alt.hour as Number;
        var altText = formatClock(altHour, alt.min as Number, false);
        var altSuffix = amPm(altHour);
        var zone = AltTime.label(_altZone);
        var width = dc.getTextWidthInPixels(altText, _altFont);
        // Center the digits alone; the AM/PM and zone tags hang off to the right
        var x = _cx + dx - width / 2;
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        var altY = _altY + dy + digitDrop(_altFont);
        dc.drawText(x, altY, _altFont, altText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        drawSideTags(dc, x + width, altY, _altFont, altSuffix, zone, _labelFont);
    }

    private function drawTime(dc as Dc, clock as System.ClockTime, minuteColor as Number, dx as Number, dy as Number) as Void {
        var hours = hourText(clock.hour);
        var minutes = clock.min.format("%02d");
        var colon = ":";
        var wh = dc.getTextWidthInPixels(hours, _timeFont);
        var wc = dc.getTextWidthInPixels(colon, _timeFont);
        var wm = dc.getTextWidthInPixels(minutes, _timeFont);
        var suffix = amPm(clock.hour);
        var seconds = _isAwake ? clock.sec.format("%02d") : null;

        // Center HH:MM together with the AM/PM + seconds column so wide times
        // like 23:59 stay clear of the arcs.
        var x = _cx + dx - (wh + wc + wm + sideWidth(dc, suffix, seconds, _secFont)) / 2;
        var y = _cy + dy + digitDrop(_timeFont);

        var flags = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(_hourColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, _timeFont, hours, flags);
        dc.setColor(minuteColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + wh, y, _timeFont, colon, flags);
        dc.drawText(x + wh + wc, y, _timeFont, minutes, flags);

        drawSideTags(dc, x + wh + wc + wm, y, _timeFont, suffix, seconds, _secFont);
    }

    //! Width taken by drawSideTags, including the gap before it.
    private function sideWidth(dc as Dc, top as String?, bottom as String?, bottomFont as FontType) as Number {
        var wt = top != null ? dc.getTextWidthInPixels(top, _labelFont) : 0;
        var wb = bottom != null ? dc.getTextWidthInPixels(bottom, bottomFont) : 0;
        if (wt == 0 && wb == 0) {
            return 0;
        }
        return (_w * 0.012).toNumber() + (wt > wb ? wt : wb);
    }

    //! Small tags to the right of large digits: one aligned to the top of the
    //! digits (AM/PM) and one to their bottom (seconds or zone label).
    private function drawSideTags(dc as Dc, x as Number, y as Number, font as FontType,
                                  top as String?, bottom as String?, bottomFont as FontType) as Void {
        var flags = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var half = digitHalf(font);
        x += (_w * 0.012).toNumber();
        dc.setColor(_isAwake ? LABEL_COLOR : DIM_COLOR, Graphics.COLOR_TRANSPARENT);
        if (top != null) {
            dc.drawText(x, y - half + digitHalf(_labelFont), _labelFont, top, flags);
        }
        if (bottom != null) {
            dc.drawText(x, y + half - digitHalf(bottomFont), bottomFont, bottom, flags);
        }
    }

    private function drawWeather(dc as Dc) as Void {
        var icon = _weatherIcon;
        var width = iconWidth(icon) + dc.getTextWidthInPixels(_tempText, _textFont);
        drawIconText(dc, icon, _tempText, _cx - width / 2, _weatherY);
    }

    private function drawSun(dc as Dc) as Void {
        var icon = _sunIsSunset ? _sunsetIcon : _sunriseIcon;
        var width = iconWidth(icon) + dc.getTextWidthInPixels(_sunText, _textFont);
        drawIconText(dc, icon, _sunText, _cx - width / 2, _sunY);
    }

    private function iconWidth(icon as BitmapResource?) as Number {
        return icon != null ? icon.getWidth() : 0;
    }

    //! Draws an icon followed by text, vertically centered on y. Returns the right edge.
    private function drawIconText(dc as Dc, icon as BitmapResource?, text as String, x as Number, y as Number) as Number {
        if (icon != null) {
            dc.drawBitmap(x, y - icon.getHeight() / 2, icon);
            x += icon.getWidth();
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, _textFont, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        return x + dc.getTextWidthInPixels(text, _textFont);
    }

    //! Quadrants in order TR, TL, BL, BR. Each fills from its horizontal
    //! (3 or 9 o'clock) end toward 12 or 6 o'clock.
    private function drawArcs(dc as Dc) as Void {
        for (var q = 0; q < 4; q++) {
            // Start angle at the horizontal end, and the direction of fill
            var start = (q == 0) ? ARC_GAP : (q == 1) ? 180 - ARC_GAP : (q == 2) ? 180 + ARC_GAP : 360 - ARC_GAP;
            var dir = (q % 2 == 0) ? 1 : -1;

            drawArcSegment(dc, start, start + dir * ARC_SPAN, ARC_TRACK_COLOR);

            var metric = _arcMetrics[q];
            var fraction = Metrics.getFraction(metric);
            if (fraction != null && fraction > 0.0) {
                var end = start + dir * (ARC_SPAN * fraction).toNumber();
                drawArcSegment(dc, start, end, Metrics.getColor(metric, fraction));
            }

            // Metric icon just inside the middle of the arc
            var icon = _arcIcons[q];
            if (icon != null) {
                var a = Math.toRadians(start + dir * ARC_SPAN / 2);
                var r = _arcRadius - _arcPen / 2 - _w * 0.015 - icon.getWidth() / 2;
                dc.drawBitmap(_cx + r * Math.cos(a) - icon.getWidth() / 2,
                              _cy - r * Math.sin(a) - icon.getHeight() / 2, icon);
            }
        }

    }

    //! Draws an arc band with flat ends as a filled polygon. Angles in degrees,
    //! counter-clockwise from 3 o'clock.
    private function drawArcSegment(dc as Dc, from as Number, to as Number, color as Number) as Void {
        if (from == to) {
            return;
        }
        var inner = _arcRadius - _arcPen / 2.0;
        var outer = _arcRadius + _arcPen / 2.0;
        // Up to 22 steps per side keeps the polygon under the 64-point limit
        var steps = ((to - from).abs() / 3) + 1;
        var outerPts = [] as Array<[Numeric, Numeric]>;
        var innerPts = [] as Array<[Numeric, Numeric]>;
        for (var i = 0; i <= steps; i++) {
            var a = Math.toRadians(from + (to - from) * i.toFloat() / steps);
            var c = Math.cos(a);
            var s = Math.sin(a);
            outerPts.add([_cx + outer * c, _cy - outer * s]);
            innerPts.add([_cx + inner * c, _cy - inner * s]);
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(outerPts.addAll(innerPts.reverse()));
    }
}
