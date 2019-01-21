using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Math;
using Toybox.SensorHistory;
using Toybox.Time.Gregorian;

// buffered background screen offset;
const bgX = 9;
const bgY = 20;

// text align - center vertical and horizontal
const cAlign = Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER;

/**
Watch view.
 */
class ElPrimeroView extends WatchUi.WatchFace {

    var mHourHand;
    var mMinuteHand;
    var mGaugeHand;

    var mSmallyFont;
    var mIconsFont;

    var cBackgrounds;

    var cCommonGaugeBG;
    var cCommonX = [92, 45, 134];
    var cCommonY = [126, 82, 83];
    var cBackgroundsX = [0, 0,  186, 0,   154, 47,  133, 127, 171, 133, 88,  81,  130, 88,  43, 38, 86, 44];
    var cBackgroundsY = [0, 68, 68,  134, 134, 163, 72,  83,  83,  117, 115, 126, 126, 163, 72, 84, 84, 116];
    var mBuffer;

    var mDatesFont;

    var mDayFont;

    var mStepsScaleFont;
    var mStepsX = [8,   0,   0,  2,  11];
    var mStepsY = [136, 111, 83, 56, 31];

    var mActivityScaleFont;
    var mActivityX = [205, 200, 193, 185];
    var mActivityY = [62,  48,  36,  25 ];

    var mMovementScaleFont;
    var mMovementX = [176, 196, 200, 204, 207];
    var mMovementY = [155, 147, 138, 130, 121];

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
        mHourHand = new Hand(
            Rez.JsonData.hour_sides_json,
            [
                    Rez.Fonts.hour_sides0,
                    Rez.Fonts.hour_sides1,
                    Rez.Fonts.hour_sides2,
                    Rez.Fonts.hour_sides3,
                    Rez.Fonts.hour_sides4,
                    Rez.Fonts.hour_sides5,
                    Rez.Fonts.hour_sides6
            ]
        );

        mMinuteHand = new Hand(
            Rez.JsonData.minute_sides_json,
            [
                Rez.Fonts.minute_sides0,
                Rez.Fonts.minute_sides1,
                Rez.Fonts.minute_sides2,
                Rez.Fonts.minute_sides3,
                Rez.Fonts.minute_sides4,
                Rez.Fonts.minute_sides5,
                Rez.Fonts.minute_sides6,
                Rez.Fonts.minute_sides7
            ]
            );

        mGaugeHand = new Hand(
            Rez.JsonData.gauge_sides_json,
            [
                Rez.Fonts.gauge_sides0
            ]
         );

        mSmallyFont = WatchUi.loadResource(Rez.Fonts.Smally);
        mIconsFont = WatchUi.loadResource(Rez.Fonts.Icons);
        cBackgrounds = [
            WatchUi.loadResource(Rez.Drawables.BGTop),
            WatchUi.loadResource(Rez.Drawables.BGLeft),
            WatchUi.loadResource(Rez.Drawables.BGRight),
            WatchUi.loadResource(Rez.Drawables.BGLeftBottom),
            WatchUi.loadResource(Rez.Drawables.BGRightBottom),
            WatchUi.loadResource(Rez.Drawables.BGBottom),

            WatchUi.loadResource(Rez.Drawables.G3Top),
            WatchUi.loadResource(Rez.Drawables.G3Left),
            WatchUi.loadResource(Rez.Drawables.G3Right),
            WatchUi.loadResource(Rez.Drawables.G3Bottom),

            WatchUi.loadResource(Rez.Drawables.G6Top),
            WatchUi.loadResource(Rez.Drawables.G6Left),
            WatchUi.loadResource(Rez.Drawables.G6Right),
            WatchUi.loadResource(Rez.Drawables.G6Bottom),

            WatchUi.loadResource(Rez.Drawables.G9Top),
            WatchUi.loadResource(Rez.Drawables.G9Left),
            WatchUi.loadResource(Rez.Drawables.G9Right),
            WatchUi.loadResource(Rez.Drawables.G9Bottom)
        ];

        cCommonGaugeBG = WatchUi.loadResource(Rez.Drawables.GaugeBG);

        mBuffer = new Graphics.BufferedBitmap({
            :width=>218,
            :height=>200
        });

        mDatesFont = WatchUi.loadResource(Rez.Fonts.Date);
        mDayFont = WatchUi.loadResource(Rez.Fonts.Day);

        mStepsScaleFont = WatchUi.loadResource(Rez.Fonts.steps_scale);

        mActivityScaleFont = WatchUi.loadResource(Rez.Fonts.activity_scale);

        mMovementScaleFont = WatchUi.loadResource(Rez.Fonts.movement_scale);
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    /**
    Draws hand with and it decorations

    dc - device context
    hand - HandView instance
    color - color for hand
    paths - array of RadialPath instances
    colors - corresponding colors
    pos - hand position (0-59)
    offset - int32-encoded offsets for hand and rects position
    hx, hy - correction for hand tiles position
    cx, cy - rotation center
     */
    function drawHand(dc, hand, color, width, coords, colors, pos, offset) {
        var hx = (offset >> 24) & 0xFF;
        var hy = (offset >> 16) & 0xFF;
        var cx = (offset >> 8) & 0xFF;
        var cy = offset & 0xFF;
        var r = Math.toRadians(pos * 6);
        for (var i = 0; i < colors.size(); i++) {
            dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
            drawRadialRect(dc, r, width, coords[i], coords[i + 1], cx - bgX, cy - bgY);
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        hand.draw(dc, pos, hx, hy);
    }

    // Update the view
    function onUpdate(dc) {
        // Prepare all data
        var time = System.getClockTime();
        var stats = System.getSystemStats();
        var heartBeatIter = SensorHistory.getHeartRateHistory({});
        var heartBeatSample = heartBeatIter.next();
        var heartBeat = null;
        if (heartBeatSample != null) {
            heartBeat = heartBeatSample.data;
        }
        var pos;
        var now = Time.now();
        time = Gregorian.info(now, Time.FORMAT_MEDIUM);

        var utc = Gregorian.utcInfo(now, Time.FORMAT_MEDIUM);
        utc = (utc.hour % 12) * 5 + utc.min / 12;

        var bc = mBuffer.getDc();
        // Drawing clock backgrounds
        bc.setColor(0xFFFFFF, 0x000055);
        bc.clear();

        for (var i=0; i < cCommonX.size(); i++) {
            bc.drawBitmap(cCommonX[i], cCommonY[i], cCommonGaugeBG);
        }

        for (var i=0; i< cBackgrounds.size(); i++) {
            bc.drawBitmap(cBackgroundsX[i], cBackgroundsY[i], cBackgrounds[i]);
        }

        // Drawing texts
        bc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        // Battery
        bc.drawText(155, 90, mSmallyFont, stats.battery.toNumber(), cAlign);
        // Heartbeat
        if (heartBeat != null) {
            bc.drawText(66, 90, mSmallyFont, heartBeat.toString(), cAlign);
        }
        // Icons
        var s = "ZABSN";
        bc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 5; i++) {
            var a = Math.toRadians(utc * 6 - 120 + i * 360 / 6);
            var x = 120 - bgX + 12 * Math.sin(-a);
            var y = 165 - bgY + 12 * Math.cos(-a);
            bc.drawText(x, y, mIconsFont, s.substring(i, i + 1), cAlign);
        }

        // Day of month
        bc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        bc.drawText(172 - bgX, 178 - bgY, mDayFont, time.day / 10, cAlign);
        bc.drawText(177 - bgX, 173 - bgY, mDayFont, time.day % 10, cAlign);
        // Day of weeek
        bc.drawText(61, 62, mDatesFont, time.day_of_week.toUpper(), cAlign);
        // Month
        bc.drawText(160, 62, mDatesFont, time.month.toUpper(), cAlign);

        // Drawing scales

        // Steps
        bc.setColor(0x55AAFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 5; i++) {
            bc.drawText(mStepsX[i], mStepsY[i], mStepsScaleFont, i, Graphics.TEXT_JUSTIFY_LEFT);
        }
        // Activity
        for (var i = 0; i < 4; i++) {
            bc.drawText(mActivityX[i], mActivityY[i], mActivityScaleFont, i, Graphics.TEXT_JUSTIFY_LEFT);
        }
        // Movement
        bc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 5; i++) {
            bc.drawText(mMovementX[i], mMovementY[i], mMovementScaleFont, i, Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Drawing gauge hands

        // Battery;
        pos = (30 + 50 * stats.battery / 100.0f).toNumber() % 60;
        drawHand(bc, mGaugeHand, 0xFFFFFF, 1, [8, 24], [0xFF0000], pos, -2007194504); // 136 92 44 0

        // Heartbeat;
        if (heartBeat != null) {
            pos = (35 + 50 * heartBeat / 200.0f).toNumber() % 60;
            drawHand(bc, mGaugeHand, 0xFFFFFF, 1, [8, 24], [0xFF0000], pos, 794577784); // 47 92 -45 0
        }

        // UTC time gauge;
        drawHand(bc, mGaugeHand, 0xFFFFFF, 1, [8, 24], [0x000000], utc, 1518827684); // 90 135 0 44

        // Drawing clock hands

        // Hour hand
        pos = (time.hour % 12) * 5 + time.min / 12;
        drawHand(bc, mHourHand, 0xAAAAAA, 3, [-15, 20, 69], [0x000000, 0xFFFFFF], pos, 30841); // 0 0 0 1
        // Minute hand
        pos = time.min;
        drawHand(bc, mMinuteHand, 0xAAAAAA, 2, [-15, 45, 93], [0x000000, 0xFFFFFF], pos, 30841); // 0 0 0 1

        // Drawing image to device context
        dc.setColor(0xFFFFFF, 0x000055);
        dc.clear();
        dc.drawBitmap(bgX, bgY, mBuffer);

    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
    }

}
