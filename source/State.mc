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

    /**
    1 - sleeping
    2 - alarm
    4 - phone connected
    8 - do not disturb
    16 - notifications
     */
    var mIcons;

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
     */
    var mFlags = 0;

    function initialize() {
        update();
    }

    function update() {
        var settings = System.getDeviceSettings();
        var profile = UserProfile.getProfile();
        var activityInfo = ActivityMonitor.getInfo();

        var time = updateDateTime();
        updateIconStatus(time, settings, profile);
        updateHeartRate(profile);
        updateActivity(activityInfo);
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
            mFlags |= 1;
            mSecondPos = pos;
        }
        pos = time.min;
        if (mMinutePos != pos) {
            mFlags |= 2;
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
            mFlags |= 4;
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
        var heartBeatIter = SensorHistory.getHeartRateHistory({});
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

}