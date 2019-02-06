using Toybox.Time.Gregorian;
using Toybox.System;
using Toybox.UserProfile;
using Toybox.ActivityMonitor;
using Toybox.SensorHistory;

/**
State computes differences to be drawn on watch face and current values.
 */
class State {

    var mSecondPos = 0, mMinutePos = 0, mHourPos = 0, mUTCPos = 0;
    var mDay = 0, mWeekDay = 0, mMonth = 0;

    var mHeartRatePos = null, mHeartRateValue = null;

    var mStepsFraction = 0, mActivityFraction = 0, mMovementFraction = 0;
    var mBatteryPos = 0, mBatteryValue = 0;

    var mIsBackgroundMode = false;

    enum {
        // icons states
        SLEEP = 1,
        ALARM = 2,
        PHONE = 4,
        DND = 8,
        NOTIFICATIONS = 16
    }

    var mIcons;

    enum {
        // invalidation flags
        SECOND = 1,
        MINUTE = 2,
        HOUR = 4,
        DAY_OF_WEEK = 8,
        DAY_OF_MONTH = 16,
        MONTH = 32,
        BATTERY = 64,
        ICONS = 128,
        HEARTBEAT = 256,
        STEPS = 512,
        ACTIVITY = 1024,
        MOVEMENT = 2048,

        // flag unions
        TIME = 454, // BATTERY | ICONS | HEARTBEAT | HOUR | MINUTE - draw hour and minute hands or not
        ALL = 4095 // sum of all flags - background invalidated
    }

    var mFlags = 0;

    function initialize() {
        update();
    }

    /**
    Callback for start of View.update call
    */
    function onUpdateStart() {
        // System.println(["onUpdateStart", mFlags.format("%x")]);
        update();
        return mFlags;
    }

    /**
    Callback for end of View.update call
    */
    function onUpdateFinished() {
        // System.println(["onUpdateFinished", mFlags.format("%x")]);
        mFlags = 0;
    }

    /**
    Updates values for all watch elements
    */
    function update() {
        var settings = System.getDeviceSettings();
        var profile = UserProfile.getProfile();
        var activityInfo = ActivityMonitor.getInfo();
        var stats = System.getSystemStats();

        var time = updateDateTime();
        updateIconStatus(time, settings, profile);
        updateHeartRate(profile);
        updateActivity(activityInfo);
        updateBattery(stats);
    }

    /**
    Invalidates backgrounds depending on hour and minute hands positions

    :param h: hour hand previous position, [0-59]
    :param m: minute hand previous position, [0-59]
     */
    function updateBackgrounds(h, m) {
        // System.println(["updateBackgrounds", mFlags.format("%x"), h, m]);
        if (6 <= m && m <= 15 || 6 <= h && h <= 15) {
            // month shaded by hour and minute hands and backgrounds
            // activity scale shaded by backgrounds
            mFlags |= MONTH | ACTIVITY;
        }
        if (48 <= m && m <= 53 || 48 <= h && h <= 53 ) {
            // day of week shaded by hour and minute hands and backgrounds
            mFlags |= DAY_OF_WEEK;
        }
        if (21 <= m && m <= 29) {
            // day of month invalidated by minute hand and backgrounds
            mFlags |= DAY_OF_MONTH;
        }
        if (39 <= m && m <= 53) {
            // steps scale shaded by backgrounds
            mFlags |= STEPS;
        }
        if (15 <= m && m <= 23) {
            // movement scale shaded by backgrounds
            mFlags |= MOVEMENT;
        }
    }

    /**
    Invalidates gauges backgrouns depending on hand position

    pos - hand position, [0-59]
     */
    function updateGaugeBackgrounds(pos) {
        if (pos >= 10 && pos <= 22) {
            // battery gauge shaded by hour or minute hand
            mFlags |= BATTERY;
        }
        if (pos >= 25 && pos <= 40) {
            // utc/icons gauge shaded by hour or minute hand
            mFlags |= ICONS;
        }
        if (pos >= 40 && pos <= 53) {
            // heartbeat gauge shaded by hour or minute hand
            mFlags |= HEARTBEAT;
        }
    }

    /**
    Handles current datetime changes.

    :returns Time.Gregorian.Info: time info
     */
    function updateDateTime() {
        var now = Time.now();
        var time = Gregorian.info(now, Time.FORMAT_SHORT);
        var pos;

        pos = time.sec;
        if (mSecondPos != pos) {
            mFlags |= SECOND;
            mSecondPos = pos;
        }
        pos = time.min;
        if (mMinutePos != pos) {
            mFlags |= MINUTE;
            updateBackgrounds(mHourPos, mMinutePos);
            updateGaugeBackgrounds(mMinutePos);
            mMinutePos = pos;
        }
        pos =  (time.hour % 12) * 5 + time.min / 12;
        if (mHourPos != pos) {
            // hour position change invalidates hour hand and utc gauge
            mFlags |= HOUR | ICONS;
            updateGaugeBackgrounds(mHourPos);
            var utc = Gregorian.utcInfo(now, Time.FORMAT_SHORT);
            mUTCPos = (utc.hour % 12) * 5 + utc.min / 12;
            mHourPos = pos;
        }

        pos = time.day;
        if (mDay != pos) {
            // day changed - redraw everything
            mFlags = ALL;
            mDay = pos;
            mWeekDay = time.day_of_week;
            mMonth = time.month;
        }
        return time;
    }

    /**
    Handles icons status changes.

    :param time Info: unpacked date time info
    :param settings DeviceSetting: device settings
    :param profile Profile: user profile
     */
    function updateIconStatus(time, settings, profile) {
        var value = time.hour * 3600 + time.min * 60 + time.sec;
        var alreadySleeping = value > profile.sleepTime.value();
        var stillSleeping = value < profile.wakeTime.value();
        value = 0;
        value += (alreadySleeping || stillSleeping)? SLEEP: 0;
        value += (settings.alarmCount > 0)? ALARM: 0;
        value += (settings.phoneConnected)? PHONE: 0;
        value += (settings.doNotDisturb)? DND: 0;
        value += (settings.notificationCount > 0)? NOTIFICATIONS: 0;
        if (mIcons != value) {
            // icons state invalidated
            mFlags |= ICONS;
            mIcons = value;
        }
    }

    function getHeartRateFromHistory() {
        var heartBeatIter = SensorHistory.getHeartRateHistory({:period => 1});
        var heartBeatSample = heartBeatIter.next();
        var heartBeat = null;
        if (heartBeatSample != null) {
            return heartBeatSample.data;
        }
        return null;
    }


    function getCurrentHeartRate() {
        var info = Activity.getActivityInfo();
        return info.currentHeartRate;
    }

    /**
    Handles heart rate status changes.

    :param profile Profile: user profile
     */
    function updateHeartRate(profile) {
        var heartBeat = null;
        if (mIsBackgroundMode) {
            if (mFlags && MINUTE) {
                // in background mode update HR only once per minute
                heartBeat = getHeartRateFromHistory();
            }
        } else {
            heartBeat = getCurrentHeartRate();
        }

        if (heartBeat == null) {
            mHeartRatePos = null;
            mHeartRateValue = null;
            return;
        }

        var zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        var maxHR = zones[zones.size() - 1];
        var minHR = profile.restingHeartRate;
        if (minHR == 0) {
            minHR = 50;
        }
        mHeartRatePos = (45 + (heartBeat - minHR) * 40 / (maxHR - minHR)).toNumber() % 60;
        if (mHeartRateValue != heartBeat) {
            mFlags |= HEARTBEAT;
            mHeartRateValue = heartBeat;
        }
    }

    /**
    Computes number of colored cells for scale.

    :param value: current value
    :param max: max value
    :param count: count of cells

    :returns: count of colored cells for scale.
     */
    function getFraction(value, max, count) {
        var f = value * (count + 1) / max;
        return (f > count)? count : f;
    }

    /**
    Handles activity state changes.

    :param info ActivityInfo: activity info
    */
    function updateActivity(info) {
        var f;
        if (info.stepGoal == 0) {
            info.stepGoal = 5000;
        }

        if (info.activeMinutesWeekGoal == 0) {
            info.activeMinutesWeekGoal = 150;
        }

        f = getFraction(info.steps, info.stepGoal, 5);
        if (mStepsFraction != f) {
            mFlags |= STEPS;
            mStepsFraction = f;
        }

        mStepsFraction = info.steps * 6 / info.stepGoal;
        mStepsFraction = (mStepsFraction > 5)? 5: mStepsFraction;

        f = getFraction(info.activeMinutesWeek.total, info.activeMinutesWeekGoal, 5);
        if (mActivityFraction != f) {
            mFlags |= ACTIVITY;
            mActivityFraction = f;
        }

        f = getFraction(info.moveBarLevel - ActivityMonitor.MOVE_BAR_LEVEL_MIN,
                        ActivityMonitor.MOVE_BAR_LEVEL_MAX - ActivityMonitor.MOVE_BAR_LEVEL_MIN, 4);
        if (mMovementFraction != f) {
            mFlags |= MOVEMENT;
            mMovementFraction = f;
        }
    }

    /**
    Handles battery updates

    :param stats Stats: system statistics
     */
    function updateBattery(stats) {
        var value = stats.battery.toNumber();
        if (mBatteryValue != value) {
            mFlags |= BATTERY;
            mBatteryValue = value;
            mBatteryPos = (30 + 50 * stats.battery / 100.0f).toNumber() % 60;
        }
    }

    /**
    Resets current state

    :param isInBackground: View entered sleep mode
     */
    function reset(isInBackground) {
        mIsBackgroundMode = isInBackground;
        mFlags = ALL;
        // System.println(["reset", isInBackground, mFlags.format("%x")]);
    }
}