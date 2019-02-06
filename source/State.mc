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

    /**
    1 - sleeping
    2 - alarm
    4 - phone connected
    8 - do not disturb
    16 - notifications
     */
    var mIcons;

    enum {
        SECOND = 1,
        MINUTE = 2,
        DATE = 4,
        G3 = 8,
        G6 = 16,
        G9 = 32,
        STEPS = 64,
        ACTIVITY = 128,
        MOVEMENT = 256,
        BG_TOP = 512,
        BG_LEFT = 1024,
        BG_RIGHT = 2048,
        BG_LEFT_BOTTOM = 4096,
        BG_RIGHT_BOTTOM = 8192,
        BG_BOTTOM = 16384,
        // Sum of all backgrounds
        BACKGROUNDS = 32256
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
        mFlags = 0;
        // System.println(["onUpdateFinished", mFlags.format("%x")]);
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
        if (m < 12 || m > 47 || h < 12 || h > 47) {
            mFlags |= 512 | 64 | 128;
        }
        if (m > 41 && m < 49) {
            mFlags |= 1024 | 64;
        }
        if (m > 11 && m < 20) {
            mFlags |= 2048 | 128 | 256;
        }
        if (m > 36 && m < 43) {
            mFlags |= 4096 | 64;
        }
        if (m > 19 && m < 32) {
            mFlags |= 8192 | 256;
        }
        if (m > 24 && m < 37) {
            mFlags |= 16384;
        }
        // System.println(["updateBackgrounds", mFlags.format("%x"), h, m]);
    }

    /**
    Invalidates gauges backgrouns depending on hand position
     */
    function updateGaugeBackgrounds(t) {
        if (t >= 10 && t <= 22) {
            mFlags |= 8;
        }
        if (t >= 25 && t <= 40) {
            mFlags |= 16;
        }
        if (t >= 40 && t <= 53) {
            mFlags |= 32;
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
            mFlags |= 1; // SECOND
            mSecondPos = pos;
        }
        pos = time.min;
        if (mMinutePos != pos) {
            mFlags |= 2;
            updateBackgrounds(mHourPos, mMinutePos);
            updateGaugeBackgrounds(mHourPos);
            updateGaugeBackgrounds(mMinutePos);
            mMinutePos = pos;
            mHourPos = (time.hour % 12) * 5 + time.min / 12;
            var utc = Gregorian.utcInfo(now, Time.FORMAT_SHORT);
            utc = (utc.hour % 12) * 5 + utc.min / 12;
            if (mUTCPos != utc) {
                mFlags |= 16;
                mUTCPos = utc;
            }
        }
        pos = time.day;
        if (mDay != pos) {
            mFlags |= 4 | BACKGROUNDS;
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
        value += (alreadySleeping || stillSleeping)? 1: 0;
        value += (settings.alarmCount > 0)? 2: 0;
        value += (settings.phoneConnected)? 4: 0;
        value += (settings.doNotDisturb)? 8: 0;
        value += (settings.notificationCount > 0)? 16: 0;
        if (mIcons != value) {
            mFlags |= 16;
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
            mFlags |= 32;
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
            mFlags |= 64;
            mStepsFraction = f;
        }

        mStepsFraction = info.steps * 6 / info.stepGoal;
        mStepsFraction = (mStepsFraction > 5)? 5: mStepsFraction;

        f = getFraction(info.activeMinutesWeek.total, info.activeMinutesWeekGoal, 5);
        if (mActivityFraction != f) {
            mFlags |= 128;
            mActivityFraction = f;
        }

        f = getFraction(info.moveBarLevel - ActivityMonitor.MOVE_BAR_LEVEL_MIN,
                        ActivityMonitor.MOVE_BAR_LEVEL_MAX - ActivityMonitor.MOVE_BAR_LEVEL_MIN, 4);
        if (mMovementFraction != f) {
            mFlags |= 256;
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
            mFlags |= 8;
            mBatteryValue = value;
            mBatteryPos = (30 + 50 * stats.battery / 100.0f).toNumber() % 60;
        }
    }

    function reset(isInBackground) {
        mIsBackgroundMode = isInBackground;
        mFlags = 32767;
        // System.println(["onExitSleep", mFlags.format("%x")]);
    }
}