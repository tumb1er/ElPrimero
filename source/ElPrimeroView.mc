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
//
//    var mSmallyFont;
//    var mIconsFont;
//    var mDatesFont;
//    var mDayFont;
//    var mGaugeCenterFont;

    var cCoords; // int32-packed coords (even at high word, odd at low word)
    var cCommonPos = 0; // offset of coords arrays in cCoords
    var cBackgroundPos = 3;
    var cStepsPos = 21;
    var cActivityPos = 26;
    var cMovementPos = 30;
    var cEOF = 35;

    var mSecondCoordsX, mSecondCoordsY;

    var cCommonGaugeBG;
    var cBackgrounds;

    var mBuffer;
//
//    var mStepsScaleFont;
//    var mActivityScaleFont;
//    var mMovementScaleFont;

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
                    Rez.Fonts.hour_sides6,
                    Rez.Fonts.hour_sides7,
                    Rez.Fonts.hour_sides8,
                    Rez.Fonts.hour_sides9,
                    Rez.Fonts.hour_sides10,
                    Rez.Fonts.hour_sides11,
                    Rez.Fonts.hour_sides12,
                    Rez.Fonts.hour_sides13,
                    Rez.Fonts.hour_sides14,
                    Rez.Fonts.hour_sides15,
                    Rez.Fonts.hour_sides16,
                    Rez.Fonts.hour_sides17,
                    Rez.Fonts.hour_sides18
            ],
            true
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
            ],
            true
        );

        mGaugeHand = new Hand(
            Rez.JsonData.gauge_sides_json,
            [
                Rez.Fonts.gauge_sides0
            ],
            true
        );

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

//        mSmallyFont = WatchUi.loadResource(Rez.Fonts.Smally);
//        mIconsFont = WatchUi.loadResource(Rez.Fonts.Icons);
//        mDatesFont = WatchUi.loadResource(Rez.Fonts.Date);
//        mDayFont = WatchUi.loadResource(Rez.Fonts.Day);
//        mGaugeCenterFont = WatchUi.loadResource(Rez.Fonts.gauge_center);
//        mStepsScaleFont = WatchUi.loadResource(Rez.Fonts.steps_scale);
//        mActivityScaleFont = WatchUi.loadResource(Rez.Fonts.activity_scale);
//        mMovementScaleFont = WatchUi.loadResource(Rez.Fonts.movement_scale);

        cCoords = WatchUi.loadResource(Rez.JsonData.coords_json);

        var data = WatchUi.loadResource(Rez.JsonData.second_json);

        mSecondCoordsX = new [5];
        mSecondCoordsY = new [5];
        for (var i = 0; i < 5; i++) {
            var xy = getXY(i, data);
            var x = xy[0] - 120;
            var y = xy[1] - 120;
            mSecondCoordsX[i] = getR(x, y);
            mSecondCoordsY[i] = getA(x, y);
        }
    }

    function getXY(i, data) {
        var d = data[i / 2];
        var shift = (i % 2 == 0)? 16: 0;
        var x = (d >> (shift + 8)) & 0xFF;
        var y = (d >> shift) & 0xFF;
        return [x, y];
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

    /**
    Draws second hand poligon
    dc - device context
    pos - second hand position [0-59]
    cx, cy - rotation center
     */
    function drawSecondHand(dc, pos, cx, cy) {
        var angle = Math.toRadians(pos * 6);
        var points = new[5];
        for (var i = 0; i < 5; i++) {
            var r = mSecondCoordsX[i];
            var a = mSecondCoordsY[i];
            var x = getX(cx, r, a + angle);
            var y = getY(cy, r, a + angle);
            points[i] = [x, y];
        }
        dc.fillPolygon(points);
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

        for (var i=0; i < cBackgroundPos; i++) {
            var c = getXY(i, cCoords);
            bc.drawBitmap(c[0], c[1], cCommonGaugeBG);
        }

        for (var i=cBackgroundPos; i< cStepsPos; i++) {
            var c = getXY(i, cCoords);
            bc.drawBitmap(c[0], c[1], cBackgrounds[i - cBackgroundPos]);
        }

//        mSmallyFont = WatchUi.loadResource(Rez.Fonts.Smally);
//        mIconsFont = WatchUi.loadResource(Rez.Fonts.Icons);
//        mDatesFont = WatchUi.loadResource(Rez.Fonts.Date);
//        mDayFont = WatchUi.loadResource(Rez.Fonts.Day);
//        mGaugeCenterFont = WatchUi.loadResource(Rez.Fonts.gauge_center);
//        mStepsScaleFont = WatchUi.loadResource(Rez.Fonts.steps_scale);
//        mActivityScaleFont = WatchUi.loadResource(Rez.Fonts.activity_scale);
//        mMovementScaleFont = WatchUi.loadResource(Rez.Fonts.movement_scale);

        var font = WatchUi.loadResource(Rez.Fonts.Smally);
        // Drawing texts
        bc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        // Battery
        bc.drawText(155, 90, font, stats.battery.toNumber(), cAlign);
        // Heartbeat
        if (heartBeat != null) {
            bc.drawText(66, 90, font, heartBeat.toString(), cAlign);
        }
        // Icons
        var s = "ZABSN";
        bc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        font = WatchUi.loadResource(Rez.Fonts.Icons);
        for (var i = cStepsPos; i < 5; i++) {
            var a = Math.toRadians(utc * 6 - 120 + i * 360 / 6);
            var x = 120 - bgX + 12 * Math.sin(-a);
            var y = 165 - bgY + 12 * Math.cos(-a);
            bc.drawText(x, y, font, s.substring(i, i + 1), cAlign);
        }

        // Day of month
        bc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        font = WatchUi.loadResource(Rez.Fonts.Day);
        bc.drawText(172 - bgX, 178 - bgY, font, time.day / 10, cAlign);
        bc.drawText(177 - bgX, 173 - bgY, font, time.day % 10, cAlign);
        font = WatchUi.loadResource(Rez.Fonts.Date);
        // Day of week
        bc.drawText(61, 62, font, time.day_of_week.toUpper(), cAlign);
        // Month
        bc.drawText(160, 62, font, time.month.toUpper(), cAlign);

        // Drawing scales

        // Steps
        bc.setColor(0x55AAFF, Graphics.COLOR_TRANSPARENT);
        font = WatchUi.loadResource(Rez.Fonts.steps_scale);
        for (var i = cStepsPos; i < cActivityPos; i++) {
            var c = getXY(i, cCoords);
            bc.drawText(c[0], c[1], font, i - cStepsPos, Graphics.TEXT_JUSTIFY_LEFT);
        }
        // Activity
        font = WatchUi.loadResource(Rez.Fonts.activity_scale);
        for (var i = cActivityPos; i < cMovementPos; i++) {
            var c = getXY(i, cCoords);
            bc.drawText(c[0], c[1], font, i - cActivityPos, Graphics.TEXT_JUSTIFY_LEFT);
        }
        // Movement
        bc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        font = WatchUi.loadResource(Rez.Fonts.movement_scale);
        for (var i = cMovementPos; i < cEOF; i++) {
            var c = getXY(i, cCoords);
            bc.drawText(c[0], c[1], font, i - cMovementPos, Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Drawing gauge hands

        // Battery;
        font = WatchUi.loadResource(Rez.Fonts.gauge_center);
        pos = (30 + 50 * stats.battery / 100.0f).toNumber() % 60;
        drawHand(bc, mGaugeHand, 0xFFFFFF, 1, [8, 24], [0xFF0000], pos, -2007194504); // 136 92 44 0
        bc.drawText(164 - bgX, 120 - bgY, font, "0", cAlign);

        // Heartbeat;
        if (heartBeat != null) {
            pos = (35 + 50 * heartBeat / 200.0f).toNumber() % 60;
            drawHand(bc, mGaugeHand, 0xFFFFFF, 1, [8, 24], [0xFF0000], pos, 794577784); // 47 92 -45 0
            bc.drawText(75 - bgX, 120 - bgY, font, "0", cAlign);
        }

        // UTC time gauge;
        drawHand(bc, mGaugeHand, 0xFFFFFF, 1, [8, 24], [0x000000], utc, 1552416812); // 92 136 0 44
        bc.drawText(120 - bgX, 164 - bgY, font, "0", cAlign);

        // Drawing clock hands

        // Hour hand
        pos = (time.hour % 12) * 5 + time.min / 12;
        drawHand(bc, mHourHand, 0xAAAAAA, 3, [-15, 20, 69], [0x000000, 0xFFFFFF], pos, 30841); // 0 0 0 1
        // Minute hand
        pos = time.min;
        drawHand(bc, mMinuteHand, 0xAAAAAA, 2, [-15, 45, 93], [0x000000, 0xFFFFFF], pos, 30841); // 0 0 0 1

        // Drawing image to device context
        dc.setColor(0xAAAAAA, 0x000055);
        dc.clear();
        dc.drawBitmap(bgX, bgY, mBuffer);

        // Drawind second hand to device context;
        pos = time.sec;
        drawSecondHand(dc, pos, 120, 120);
        var alpha = Math.toRadians(pos * 6);
        dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(120 + 80 * Math.sin(alpha), 120 - 80 * Math.cos(alpha),
                    120 + 95 * Math.sin(alpha), 120 - 95 * Math.cos(alpha));

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
