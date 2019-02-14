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

    var mHeartRatePos = null, mHeartRateValue = null, mSleepHRThreshold = null, mSleepHRMultiplier=1.2;

    var mStepsFraction = 0, mActivityFraction = 0, mMovementFraction = 0;
    var mBatteryPos = 0, mBatteryValue = 0;

    var mIsBackgroundMode = false;
    var mIsPowersafeMode = false;

    var mBackgroundTime = null;

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
        var profile = UserProfile.getProfile();
        var now = Time.now();
        var time = updateDateTime(now);
        if (!mIsBackgroundMode || !mIsPowersafeMode && mFlags & MINUTE || mFlags & HOUR) {
            // update data:
            // - in active mode
            // - once per minute in background mode
            // - with hour hand movement (12min) in powersafe mode
            updateIconStatus(time, profile);
            updateHeartRate(profile);
            updateActivity();
            updatePowerSafeMode(now);
        }
        if (mFlags & HOUR) {
            // update battery with hour hand movement
            updateBattery();

        }
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
    function updateDateTime(now) {
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
    :param profile Profile: user profile
     */
    function updateIconStatus(time, profile) {
        var settings = System.getDeviceSettings();
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

    /**
    Get avg heartbeat for previous minute from history
     */
    function getHeartRateFromHistory() {
        var heartBeatIter = SensorHistory.getHeartRateHistory({:period => 1});
        var heartBeatSample = heartBeatIter.next();
        if (heartBeatSample != null) {
            return heartBeatSample.data;
        }
        return null;
    }

    /**
    Get realtime heartbeat value
     */
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
            heartBeat = getHeartRateFromHistory();
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
        mSleepHRThreshold = minHR * mSleepHRMultiplier;
        if (mHeartRateValue != heartBeat) {
            mFlags |= HEARTBEAT;
            mHeartRateValue = heartBeat;
            mHeartRatePos = (45 + (heartBeat - minHR) * 40 / (maxHR - minHR)).toNumber() % 60;
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
    */
    function updateActivity() {
        var info = ActivityMonitor.getInfo();
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
                        ActivityMonitor.MOVE_BAR_LEVEL_MAX - ActivityMonitor.MOVE_BAR_LEVEL_MIN, 5);
        if (mMovementFraction != f) {
            mFlags |= MOVEMENT;
            mMovementFraction = f;
        }
    }

    /**
    Handles battery updates
     */
    function updateBattery() {
        var stats = System.getSystemStats();
        var value = stats.battery.toNumber();
        if (mBatteryValue != value) {
            mFlags |= BATTERY;
            mBatteryValue = value;
            mBatteryPos = (30 + 50 * stats.battery / 100.0f).toNumber() % 60;
        }
    }

    /**
    Detects entering and leaving powersafe mode

    :param time Moment: current time
     */
    function updatePowerSafeMode(time) {
        if (!mIsBackgroundMode){
            if (mIsPowersafeMode) {
                System.println("Interrupt powersafe mode");
            }
            mIsPowersafeMode = false;
            return;
        }

        // via do not disturb;
        var flag = (mIcons && DND) > 0;
        // via full movement scale;
        flag = flag || mMovementFraction == 5;
        // via missing heartbeat
        flag = flag || mHeartRateValue == null;
        // via low heartrate
        flag = flag || mHeartRateValue != null && mSleepHRThreshold != null && mHeartRateValue < mSleepHRThreshold;

        // enter powersafe mode only from background mode
        flag = flag && mIsBackgroundMode;
        // enter powersafe mode 60 seconds later than background mode activated
        flag = flag && mBackgroundTime != null && time.subtract(mBackgroundTime).value() >= 60;

        if (mIsPowersafeMode != flag) {
            if (mIsPowersafeMode) {
                System.println("Exited powersafe mode");
            } else {
                System.println("Entered powersafe mode");
            }
            mIsPowersafeMode = flag;
            mFlags |= ALL;
        }
    }

    /**
    Resets current state

    :param isInBackground: View entered sleep mode
     */
    function reset(isInBackground) {
        mIsBackgroundMode = isInBackground;
        mBackgroundTime = Time.now();
        mFlags = ALL;
        // System.println(["reset", isInBackground, mFlags.format("%x")]);
    }
}