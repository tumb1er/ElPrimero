using Toybox.Time.Gregorian;
using Toybox.System;
using Toybox.UserProfile;

/**
State computes differences to be drawn on watch face and current values.
 */
class State {

    var mSecondPos = 0, mMinutePos = 0, mHourPos = 0, mUTCPos;
    var mDay = 0, mWeekDay = 0, mMonth = 0;

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
    8 - G6 invalidated
     */
    var mFlags = 0;

    function initialize() {
        update();
    }

    function update() {
        var settings = System.getDeviceSettings();
        var profile = UserProfile.getProfile();

        var time = updateDateTime();
        updateIconStatus(time, settings, profile);
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
                mFlags |= 8;
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
            mFlags |= 8;
            mIcons = value;
        }
    }

}