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

//! Layout coordinates are in "design pixels" for a 454 px screen (from the
//! design mockup) and are scaled to the actual screen size.
class WatchFaceView extends WatchUi.WatchFace {

    private const DESIGN_SIZE = 454.0;

    // Row centers (design px)
    private const WEATHER_Y = 58;
    private const DATE_Y = 90;
    private const HOUR_Y = 161;
    private const MINUTE_Y = 274;
    private const ALT_Y = 356;
    private const SUN_Y = 389;

    // Gauges: centers (design px) in the order TL, TR, BL, BR; ring radius and stroke
    private const GAUGE_X = [98, 356, 98, 356];
    private const GAUGE_Y = [172, 172, 284, 284];
    private const GAUGE_RADIUS = 33;
    private const GAUGE_STROKE = 5;

    // Bezel (design px)
    private const TICK_OUTER = 220;
    private const MINUTE_TICK_INNER = 212;
    private const HOUR_TICK_INNER = 208;
    private const SECONDS_RADIUS = 224.5;
    private const SECONDS_STROKE = 4;

    // Font sizes (design px)
    private const TIME_SIZE = 122;
    private const SECONDS_SIZE = 28;
    private const DATE_SIZE = 22;
    private const WEATHER_SIZE = 24;
    private const ALT_SIZE = 30;
    private const LABEL_SIZE = 15;
    private const SUN_SIZE = 22;
    private const GAUGE_SIZE = 20;

    // Roboto Condensed digits are about 0.71 of the font size tall
    private const DIGIT_HEIGHT = 0.71;

    // Band height (px) for gradient text; smaller is smoother but slower to render
    private const GRADIENT_BAND = 2;

    // Colors
    private const PRIMARY = 0xECE9E2;
    private const SECONDARY = 0xC9CCD0;
    private const DATE_COLOR = 0xAEB3B8;
    private const DIM = 0x6B7177;
    private const AOD_TEXT = 0x9A9A9A;
    private const GAUGE_TRACK = 0x1F2327;
    private const TICK = 0x2A2E32;
    private const SECONDS_TRACK = 0x15171A;

    // Draws crosshair lines through the screen center to check alignment
    private const DEBUG_GUIDES = false;

    private var _w as Number = 0;
    private var _h as Number = 0;
    private var _cx as Number = 0;
    private var _cy as Number = 0;
    private var _s as Float = 1.0;

    private var _timeFont as FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var _secFont as FontType = Graphics.FONT_TINY;
    private var _dateFont as FontType = Graphics.FONT_SMALL;
    private var _weatherFont as FontType = Graphics.FONT_SMALL;
    private var _altFont as FontType = Graphics.FONT_SMALL;
    private var _labelFont as FontType = Graphics.FONT_XTINY;
    private var _sunFont as FontType = Graphics.FONT_SMALL;
    private var _gaugeFont as FontType = Graphics.FONT_TINY;

    private var _isAwake as Boolean = true;

    // Settings
    private var _hourColor as Number = Settings.GRADIENT_RED_ORANGE;
    private var _gaugeMetrics as Array<Number> = [1, 2, 3, 4];
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

    private var _background as BitmapResource?;
    private var _sunriseIcon as BitmapResource?;
    private var _sunsetIcon as BitmapResource?;
    private var _gaugeIcons as Array<BitmapResource?> = [null, null, null, null];

    // Hour digits rendered with their gradient; rebuilt when the text or color changes
    private var _hourBitmap as BufferedBitmap?;
    private var _hourBitmapKey as String = "";

    function initialize() {
        WatchFace.initialize();
        loadSettings();
    }

    function loadSettings() as Void {
        _hourColor = Settings.getNumber("HourColor");
        _gaugeMetrics = [
            Settings.getNumber("ArcTopLeft"),
            Settings.getNumber("ArcTopRight"),
            Settings.getNumber("ArcBottomLeft"),
            Settings.getNumber("ArcBottomRight")
        ];
        _altZone = Settings.getNumber("AltZone");
        for (var q = 0; q < 4; q++) {
            var id = Metrics.getIcon(_gaugeMetrics[q]);
            _gaugeIcons[q] = id != null ? WatchUi.loadResource(id) as BitmapResource : null;
        }
        _background = Settings.getBoolean("ShowBackground", true)
            ? WatchUi.loadResource(Rez.Drawables.TopoBg) as BitmapResource : null;
        _hourBitmapKey = "";
        _lastMinute = -1;
    }

    function onLayout(dc as Dc) as Void {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;
        _s = _w / DESIGN_SIZE;

        _timeFont = font(TIME_SIZE, Graphics.FONT_NUMBER_THAI_HOT);
        _secFont = font(SECONDS_SIZE, Graphics.FONT_TINY);
        _dateFont = font(DATE_SIZE, Graphics.FONT_SMALL);
        _weatherFont = font(WEATHER_SIZE, Graphics.FONT_SMALL);
        _altFont = font(ALT_SIZE, Graphics.FONT_SMALL);
        _labelFont = font(LABEL_SIZE, Graphics.FONT_XTINY);
        _sunFont = font(SUN_SIZE, Graphics.FONT_SMALL);
        _gaugeFont = font(GAUGE_SIZE, Graphics.FONT_TINY);

        _sunriseIcon = WatchUi.loadResource(Rez.Drawables.WiSunrise) as BitmapResource;
        _sunsetIcon = WatchUi.loadResource(Rez.Drawables.WiSunset) as BitmapResource;
        _hourBitmapKey = "";
    }

    //! Roboto Condensed Bold at a design-pixel size, or the given built-in font
    //! on devices without scalable fonts.
    private function font(size as Number, fallback as FontType) as FontType {
        if (Graphics has :getVectorFont) {
            var f = Graphics.getVectorFont({:face => ["RobotoCondensedBold"], :size => px(size)});
            if (f != null) {
                return f;
            }
        }
        return fallback;
    }

    //! Design-pixel length to screen pixels
    private function px(v as Numeric) as Number {
        return (v * _s + 0.5).toNumber();
    }

    //! Design-pixel coordinates to screen coordinates
    private function sx(x as Numeric) as Number {
        return _cx + px(x - DESIGN_SIZE / 2);
    }

    private function sy(y as Numeric) as Number {
        return _cy + px(y - DESIGN_SIZE / 2);
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
            if (_background != null) {
                dc.drawBitmap(_cx - _background.getWidth() / 2, _cy - _background.getHeight() / 2, _background);
            }
            drawBezel(dc, clock.sec);
            for (var q = 0; q < 4; q++) {
                drawGauge(dc, q);
            }
            drawWeather(dc);
            drawSun(dc);
            drawTexts(dc, clock, 0, 0);
        } else {
            // Always-on: date and both times only, shifted a few pixels each
            // minute to limit AMOLED burn-in.
            var step = px(4);
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

    //! Half the visible digit (or cap) height of a font
    private function digitHalf(font as FontType) as Number {
        return (fontSize(font) * DIGIT_HEIGHT / 2).toNumber();
    }

    //! Nominal pixel size of a font (ascent + descent)
    private function fontSize(font as FontType) as Number {
        return Graphics.getFontAscent(font) + Graphics.getFontDescent(font);
    }

    //! Date, stacked main time and second time; shared by the normal and always-on views.
    private function drawTexts(dc as Dc, clock as System.ClockTime, dx as Number, dy as Number) as Void {
        var flags = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        drawSpaced(dc, _dateText, _dateFont, _isAwake ? DATE_COLOR : AOD_TEXT, _cx + dx, sy(DATE_Y) + dy, px(3), false);

        // Hour line, with AM/PM at the top right of the digits in 12-hour mode
        var hourY = sy(HOUR_Y) + dy;
        var hourRight = drawHour(dc, hourText(clock.hour), _cx + dx, hourY);
        var suffix = amPm(clock.hour);
        if (suffix != null) {
            dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(hourRight + px(6), hourY - digitHalf(_timeFont) + digitHalf(_secFont), _secFont, suffix, flags);
        }

        // Minute line, with seconds at the bottom right while awake
        var minuteY = sy(MINUTE_Y) + dy;
        var minutes = clock.min.format("%02d");
        dc.setColor(_isAwake ? PRIMARY : AOD_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + dx, minuteY, _timeFont, minutes, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (_isAwake) {
            var minuteRight = _cx + dx + dc.getTextWidthInPixels(minutes, _timeFont) / 2;
            dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(minuteRight + px(6), minuteY + digitHalf(_timeFont) - digitHalf(_secFont), _secFont,
                clock.sec.format("%02d"), flags);
        }

        // Second time zone: digits centered, zone label (and AM/PM) to the right on the same baseline
        var alt = Gregorian.utcInfo(Time.now().add(new Time.Duration(_altOffset)), Time.FORMAT_SHORT);
        var altHour = alt.hour as Number;
        var altText = formatClock(altHour, alt.min as Number, false);
        var label = AltTime.label(_altZone);
        var altSuffix = amPm(altHour);
        if (altSuffix != null) {
            label = altSuffix + " " + label;
        }
        var altY = sy(ALT_Y) + dy;
        var altRight = _cx + dx + dc.getTextWidthInPixels(altText, _altFont) / 2;
        dc.setColor(_isAwake ? SECONDARY : AOD_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + dx, altY, _altFont, altText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        drawSpaced(dc, label, _labelFont, DIM, altRight + px(5), altY + digitHalf(_altFont) - digitHalf(_labelFont),
            px(2), true);
    }

    //! Draws the hour digits centered at (x, y) in the configured color or
    //! gradient. Returns the right edge of the digits.
    private function drawHour(dc as Dc, text as String, x as Number, y as Number) as Number {
        var key = text + "/" + _hourColor;
        if (!key.equals(_hourBitmapKey)) {
            _hourBitmap = renderGradientText(dc, text, _timeFont, Settings.hourColors(_hourColor));
            _hourBitmapKey = key;
        }
        var bmp = _hourBitmap;
        if (bmp == null) {
            return x;
        }
        dc.drawBitmap(x - bmp.getWidth() / 2, y - bmp.getHeight() / 2, bmp);
        return x + bmp.getWidth() / 2;
    }

    //! Connect IQ can't fill text with a gradient, so the text is drawn once per
    //! thin horizontal band, each clipped to its band and in its own color. This
    //! goes into an offscreen bitmap that is reused until the text changes.
    //! The bitmap is exactly as wide as the text and centered on it vertically.
    private function renderGradientText(dc as Dc, text as String, font as FontType, colors as [Number, Number]) as BufferedBitmap {
        var w = dc.getTextWidthInPixels(text, font);
        var h = fontSize(font);
        var bmp = Graphics.createBufferedBitmap({:width => w, :height => h}).get() as BufferedBitmap;
        var bdc = bmp.getDc();
        if (bdc has :setAntiAlias) {
            bdc.setAntiAlias(true);
        }
        var flags = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        if (colors[0] == colors[1]) {
            bdc.setColor(colors[0], Graphics.COLOR_TRANSPARENT);
            bdc.drawText(w / 2, h / 2, font, text, flags);
            return bmp;
        }
        // The gradient spans the visible digits, not the whole font box
        var half = digitHalf(font);
        var top = h / 2 - half;
        for (var y = 0; y < h; y += GRADIENT_BAND) {
            var t = (y + GRADIENT_BAND / 2.0 - top) / (2.0 * half);
            bdc.setClip(0, y, w, GRADIENT_BAND);
            bdc.setColor(lerpColor(colors[0], colors[1], t), Graphics.COLOR_TRANSPARENT);
            bdc.drawText(w / 2, h / 2, font, text, flags);
        }
        bdc.clearClip();
        return bmp;
    }

    private function lerpColor(a as Number, b as Number, t as Float) as Number {
        t = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);
        var r = ((a >> 16) & 0xFF) + ((((b >> 16) & 0xFF) - ((a >> 16) & 0xFF)) * t).toNumber();
        var g = ((a >> 8) & 0xFF) + ((((b >> 8) & 0xFF) - ((a >> 8) & 0xFF)) * t).toNumber();
        var bl = (a & 0xFF) + (((b & 0xFF) - (a & 0xFF)) * t).toNumber();
        return (r << 16) | (g << 8) | bl;
    }

    //! Draws text with extra spacing between letters, vertically centered on y.
    //! The text is centered on x, or starts at x when leftAligned is set.
    private function drawSpaced(dc as Dc, text as String, font as FontType, color as Number, x as Number, y as Number,
                                spacing as Number, leftAligned as Boolean) as Void {
        var chars = text.toCharArray();
        if (!leftAligned) {
            var total = spacing * (chars.size() - 1);
            for (var i = 0; i < chars.size(); i++) {
                total += dc.getTextWidthInPixels(chars[i].toString(), font);
            }
            x -= total / 2;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i].toString();
            dc.drawText(x, y, font, c, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            x += dc.getTextWidthInPixels(c, font) + spacing;
        }
    }

    //! Draws an icon followed by text, the pair centered on x and vertically on y.
    private function drawIconText(dc as Dc, icon as BitmapResource?, tint as Number?, text as String,
                                  font as FontType, color as Number, x as Number, y as Number) as Void {
        var gap = px(4);
        var iconW = icon != null ? icon.getWidth() + gap : 0;
        var left = x - (iconW + dc.getTextWidthInPixels(text, font)) / 2;
        if (icon != null) {
            var iy = y - icon.getHeight() / 2;
            if (tint != null && dc has :drawBitmap2) {
                dc.drawBitmap2(left, iy, icon, {:tintColor => tint});
            } else {
                dc.drawBitmap(left, iy, icon);
            }
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + iconW, y, font, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawWeather(dc as Dc) as Void {
        drawIconText(dc, _weatherIcon, null, _tempText, _weatherFont, PRIMARY, _cx, sy(WEATHER_Y));
    }

    private function drawSun(dc as Dc) as Void {
        drawIconText(dc, _sunIsSunset ? _sunsetIcon : _sunriseIcon, Settings.accentColor(_hourColor),
            _sunText, _sunFont, SECONDARY, _cx, sy(SUN_Y));
    }

    //! Minute and hour ticks, the 12 o'clock accent marker, and the seconds ring.
    private function drawBezel(dc as Dc, sec as Number) as Void {
        for (var i = 0; i < 60; i++) {
            if (i == 0) {
                continue;
            }
            var isHour = i % 5 == 0;
            dc.setPenWidth(isHour ? px(3) : px(2));
            dc.setColor(isHour ? DIM : TICK, Graphics.COLOR_TRANSPARENT);
            radialLine(dc, i * 6, isHour ? HOUR_TICK_INNER : MINUTE_TICK_INNER, TICK_OUTER);
        }
        dc.setPenWidth(px(4));
        dc.setColor(Settings.accentColor(_hourColor), Graphics.COLOR_TRANSPARENT);
        radialLine(dc, 0, HOUR_TICK_INNER - 2, TICK_OUTER + 2);

        // Seconds ring: faint track, fill growing clockwise from 12 o'clock
        var r = SECONDS_RADIUS * _s;
        dc.setPenWidth(px(SECONDS_STROKE));
        dc.setColor(SECONDS_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r);
        if (sec > 0) {
            dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(_cx, _cy, r, Graphics.ARC_CLOCKWISE, 90, 90 - sec * 6);
        }
        dc.setPenWidth(1);
    }

    //! Line along a radius; angle in degrees clockwise from 12 o'clock, radii in design px.
    private function radialLine(dc as Dc, angle as Number, inner as Numeric, outer as Numeric) as Void {
        var a = Math.toRadians(angle);
        var sin = Math.sin(a);
        var cos = Math.cos(a);
        dc.drawLine(_cx + inner * _s * sin, _cy - inner * _s * cos, _cx + outer * _s * sin, _cy - outer * _s * cos);
    }

    //! Ring gauge with a solid black center, filling clockwise from 12 o'clock,
    //! with the metric icon above its value.
    private function drawGauge(dc as Dc, q as Number) as Void {
        var metric = _gaugeMetrics[q];
        if (metric == Metrics.NONE) {
            return;
        }
        var x = sx(GAUGE_X[q]);
        var y = sy(GAUGE_Y[q]);
        var r = GAUGE_RADIUS * _s;
        var stroke = px(GAUGE_STROKE);
        var reading = Metrics.getReading(metric);
        var fraction = reading[0];

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r + stroke / 2.0);
        dc.setPenWidth(stroke);
        dc.setColor(GAUGE_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, r);
        if (fraction != null && fraction > 0.0) {
            dc.setColor(Metrics.getColor(metric, fraction), Graphics.COLOR_TRANSPARENT);
            if (fraction >= 1.0) {
                dc.drawCircle(x, y, r);
            } else {
                dc.drawArc(x, y, r, Graphics.ARC_CLOCKWISE, 90, 90 - (360 * fraction).toNumber());
            }
        }
        dc.setPenWidth(1);

        var icon = _gaugeIcons[q];
        if (icon != null) {
            dc.drawBitmap(x - icon.getWidth() / 2, y - px(11) - icon.getHeight() / 2, icon);
        }
        dc.setColor(PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + px(9), _gaugeFont, reading[1], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
