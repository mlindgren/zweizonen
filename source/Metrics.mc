import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;

//! Arc metrics. Each metric yields a fill fraction (0..1) and a color.
module Metrics {

    // Values match the ArcMetric list in resources/settings/settings.xml
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

    function getColor(metric as Number, fraction as Float?) as Number {
        switch (metric) {
            case BODY_BATTERY:  return 0x00AAFF;
            case WATCH_BATTERY: return (fraction != null && fraction < 0.2) ? 0xFF3030 : 0x00FF55;
            case STEPS:         return 0xFF8800;
            case RECOVERY:      return 0xAA55FF;
            case INTENSITY:     return 0xFFCC00;
            case FLOORS:        return 0x00DDDD;
        }
        return 0xFFFFFF;
    }

    function getIcon(metric as Number) as ResourceId? {
        switch (metric) {
            case BODY_BATTERY:  return Rez.Drawables.ArcBodyBattery;
            case WATCH_BATTERY: return Rez.Drawables.ArcWatchBattery;
            case STEPS:         return Rez.Drawables.ArcSteps;
            case RECOVERY:      return Rez.Drawables.ArcRecovery;
            case INTENSITY:     return Rez.Drawables.ArcIntensity;
            case FLOORS:        return Rez.Drawables.ArcFloors;
        }
        return null;
    }

    //! Returns the fill fraction for the metric, or null if the data is unavailable.
    function getFraction(metric as Number) as Float? {
        switch (metric) {
            case BODY_BATTERY:  return bodyBattery();
            case WATCH_BATTERY: return System.getSystemStats().battery / 100.0;
            case STEPS:         return steps();
            case RECOVERY:      return recovery();
            case INTENSITY:     return intensity();
            case FLOORS:        return floors();
        }
        return null;
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

    function bodyBattery() as Float? {
        var value = complicationValue(new Complications.Id(Complications.COMPLICATION_TYPE_BODY_BATTERY));
        if (value == null) {
            var sample = SensorHistory.getBodyBatteryHistory({:period => 1}).next();
            if (sample != null) {
                value = sample.data;
            }
        }
        return ratio(value, 100);
    }

    function steps() as Float? {
        var info = ActivityMonitor.getInfo();
        return ratio(info.steps, info.stepGoal);
    }

    //! Recovery time counts down, so the arc shows time remaining out of 96 h.
    function recovery() as Float? {
        return ratio(complicationValue(new Complications.Id(Complications.COMPLICATION_TYPE_RECOVERY_TIME)), RECOVERY_MAX_MINUTES);
    }

    function intensity() as Float? {
        var info = ActivityMonitor.getInfo();
        var week = info.activeMinutesWeek;
        return ratio(week != null ? week.total : null, info.activeMinutesWeekGoal);
    }

    function floors() as Float? {
        var info = ActivityMonitor.getInfo();
        return ratio(info.floorsClimbed, info.floorsClimbedGoal);
    }
}
