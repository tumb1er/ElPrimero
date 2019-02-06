using Toybox.Time.Gregorian;
using Toybox.System;
using Toybox.UserProfile;
using Toybox.ActivityMonitor;
using Toybox.SensorHistory;

/**
State computes differences to be drawn on watch face and current values.
 */
class State {

    var mSecondPos = 0, mMinutePos = 0, mHourPos = 0, mUTCPos;
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

        // joined flags
        TIME = 454, // BATTERY | ICONS | HEARTBEAT | HOUR | MINUTE
        DATE = 56, // DAY_OF_WEEK | DAY_OF_MONTH | MONTH
        ALL = 4095 // sum of all flags - background invalidated
    }

    /**
    1 - second invalidated
    2 - minute invalidated
    * hour hand is invalidated every time when minute hand moves
    4 - date invalidated
    8 - G3 invalidated
    16 - G6 invalidated
    32 - G9 invalidated
    64 - steps scale invalidated
    128 - activity scale invalidated
    256 - movement scale invalidated
    512 - BG Top
    1024 - BG Left
    2048 - BG Right
    4096 - BG Left Bottom
    8192 - BG Right Bottom
    16384 - BG Bottom
     */
    var mFlags = 0;

    function initialize() {
        update();
    }

    function onUpdateStart() {
        // System.println(["onUpdateStart", mFlags.format("%x")]);
        update();
        return mFlags;
    }

    function onUpdateFinished() {
        // System.println(["onUpdateFinished", mFlags.format("%x")]);
        mFlags = 0;
    }

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
     */
    function updateBackgrounds(h, m) {
        System.println(["updateBackgrounds", mFlags.format("%x"), h, m]);
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
     */
    function updateGaugeBackgrounds(t) {
        if (t >= 10 && t <= 22) {
            mFlags |= BATTERY;
        }
        if (t >= 25 && t <= 40) {
            mFlags |= ICONS;
        }
        if (t >= 40 && t <= 53) {
            mFlags |= HEARTBEAT;
        }
    }

    /**
    Handles current datetime changes.

    return Time info
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

    time Info: unpacked date time info
    settings DeviceSetting: device settings
    profile Profile: user profile
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
            System.println("Icons changed");
            mFlags |= ICONS;
            mIcons = value;
        }
    }

    /**
    Handles heart rate status changes.

    profile Profile: user profile
     */
    function updateHeartRate(profile) {
        var zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        var maxHR = zones[zones.size() - 1];
        var minHR = profile.restingHeartRate;
        if (minHR == 0) {
            minHR = 50;
        }
        zones = null;
        var heartBeatIter = SensorHistory.getHeartRateHistory({:period => 1});
        var heartBeatSample = heartBeatIter.next();
        var heartBeat = null;
        if (heartBeatSample != null) {
            heartBeat = heartBeatSample.data;
        }
        if (heartBeat != null) {
            mHeartRatePos = (45 + (heartBeat - minHR) * 40 / (maxHR - minHR)).toNumber() % 60;
        } else {
            mHeartRatePos = null;
        }
        if (mHeartRateValue != heartBeat) {
            mFlags |= HEARTBEAT;
            mHeartRateValue = heartBeat;
        }
    }

    function getFraction(value, max, count) {
        var f = value * (count + 1) / max;
        return (f > count)? count : f;
    }

    /**
    Handles activity state changes.

    info ActivityInfo: activity info
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

    stats Stats: system statistics
     */

    function updateBattery(stats) {
        var value = stats.battery.toNumber();
        if (mBatteryValue != value) {
            mFlags |= BATTERY;
            mBatteryValue = value;
            mBatteryPos = (30 + 50 * stats.battery / 100.0f).toNumber() % 60;
        }
    }

    function reset(isInBackground) {
        mIsBackgroundMode = isInBackground;
        mFlags = ALL;
        // System.println(["reset", isInBackground, mFlags.format("%x")]);
    }
}