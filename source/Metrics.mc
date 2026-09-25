import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;

//! Gauge metrics. Each metric yields a fill fraction (0..1), a short value
//! label, a color and an icon.
module Metrics {

    // Values match the gauge metric lists in resources/settings/settings.xml
    enum Metric {
        NONE = 0,
        BODY_BATTERY = 1,
        WATCH_BATTERY = 2,
        STEPS = 3,
        RECOVERY = 4,
        INTENSITY = 5,
        FLOORS = 6
    }

    const RECOVERY_MAX_MINUTES = 96 * 60;
    const NO_VALUE = "--";

    function getColor(metric as Number, fraction as Float?) as Number {
        switch (metric) {
            case BODY_BATTERY:  return 0x45A8F5;
            case WATCH_BATTERY: return (fraction != null && fraction < 0.2) ? 0xF0483A : 0x62D26F;
            case STEPS:         return 0xF5C542;
            case RECOVERY:      return 0xA77BF3;
            case INTENSITY:     return 0xE8618C;
            case FLOORS:        return 0x4FD1C5;
        }
        return 0xECE9E2;
    }

    function getIcon(metric as Number) as ResourceId? {
        switch (metric) {
            case BODY_BATTERY:  return Rez.Drawables.GaugeBodyBattery;
            case WATCH_BATTERY: return Rez.Drawables.GaugeWatchBattery;
            case STEPS:         return Rez.Drawables.GaugeSteps;
            case RECOVERY:      return Rez.Drawables.GaugeRecovery;
            case INTENSITY:     return Rez.Drawables.GaugeIntensity;
            case FLOORS:        return Rez.Drawables.GaugeFloors;
        }
        return null;
    }

    //! [fill fraction or null if unavailable, value label]
    function getReading(metric as Number) as [Float?, String] {
        switch (metric) {
            case BODY_BATTERY:  return bodyBattery();
            case WATCH_BATTERY: return watchBattery();
            case STEPS:         return steps();
            case RECOVERY:      return recovery();
            case INTENSITY:     return intensity();
            case FLOORS:        return floors();
        }
        return [null, ""];
    }

    function ratio(value as Numeric?, goal as Numeric?) as Float? {
        if (value == null || goal == null || goal <= 0) {
            return null;
        }
        var f = value.toFloat() / goal.toFloat();
        return f > 1.0 ? 1.0 : (f < 0.0 ? 0.0 : f);
    }

    function complicationValue(id as Complications.Id) as Numeric? {
        try {
            var value = Complications.getComplication(id).value;
            if (value instanceof Number || value instanceof Float) {
                return value;
            }
        } catch (e) {
        }
        return null;
    }

    //! "850", "4.6k", "12k"
    function compact(value as Number) as String {
        if (value < 1000) {
            return value.toString();
        }
        if (value < 10000) {
            return (value / 1000.0).format("%.1f") + "k";
        }
        return (value / 1000).toString() + "k";
    }

    function bodyBattery() as [Float?, String] {
        var value = complicationValue(new Complications.Id(Complications.COMPLICATION_TYPE_BODY_BATTERY));
        if (value == null) {
            var sample = SensorHistory.getBodyBatteryHistory({:period => 1}).next();
            if (sample != null) {
                value = sample.data;
            }
        }
        return [ratio(value, 100), value != null ? value.toNumber().toString() : NO_VALUE];
    }

    function watchBattery() as [Float?, String] {
        var battery = System.getSystemStats().battery;
        return [battery / 100.0, battery.toNumber().toString() + "%"];
    }

    function steps() as [Float?, String] {
        var info = ActivityMonitor.getInfo();
        var steps = info.steps;
        return [ratio(steps, info.stepGoal), steps != null ? compact(steps) : NO_VALUE];
    }

    //! Recovery time counts down, so the gauge shows time remaining out of 96 h.
    function recovery() as [Float?, String] {
        var minutes = complicationValue(new Complications.Id(Complications.COMPLICATION_TYPE_RECOVERY_TIME));
        if (minutes == null) {
            return [null, NO_VALUE];
        }
        var m = minutes.toNumber();
        var text = m < 60 ? m.toString() + "m" : ((m + 59) / 60).toString() + "h";
        return [ratio(m, RECOVERY_MAX_MINUTES), text];
    }

    function intensity() as [Float?, String] {
        var info = ActivityMonitor.getInfo();
        var week = info.activeMinutesWeek;
        var total = week != null ? week.total : null;
        return [ratio(total, info.activeMinutesWeekGoal), total != null ? total.toString() : NO_VALUE];
    }

    function floors() as [Float?, String] {
        var info = ActivityMonitor.getInfo();
        var floors = info.floorsClimbed;
        return [ratio(floors, info.floorsClimbedGoal), floors != null ? floors.toString() : NO_VALUE];
    }
}
