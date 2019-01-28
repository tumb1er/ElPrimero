using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Math;
using Toybox.SensorHistory;
using Toybox.Time.Gregorian;
using Toybox.UserProfile;

// buffered background screen offset;

// text align - center vertical and horizontal
const cAlign = Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER;
const cTransparent = Graphics.COLOR_TRANSPARENT;
/**
Watch view.
 */
class ElPrimeroView extends WatchUi.WatchFace {
    // coords.json offsets
    enum {
        PosCommon,
        PosBackground = 3,
        PosGauge3 = 9,
        PosGauge6 = 13,
        PosGauge9 = 17,
        PosSteps = 21,
        PosActivity = 26,
        PosMovement= 30,
        PosEOF=35
    }
    // hands.json offsets
    enum {
        PosSecond,
        PosMinuteLeft = 5,
        PosMinuteRight = 9,
        PosHourLeft = 13,
        PosHourRight = 17,
        PosEOF2 = 21
    }

    var mHourHand;
    var mMinuteHand;
    var mGaugeHand;

    var cCoords; // int32-packed coords (even at high word, odd at low word)

    var mSecondCoords;

    var cCommonGaugeBG;
    var cBackgrounds;

    var mBuffer;
    var mCap;

    var mIsBackgroundMode;

    var mIcons; // bit-packed flags


    // prev clip
    var fx, fy, gx, gy;
    // clip
    var ax, ay, bx, by;

    function initialize() {
        WatchFace.initialize();
        mIsBackgroundMode = false;
        fx = 240;
        fy = 240;
        gx = 0;
        gy = 0;
    }

    function loadCoords(data, start, end) {
        var coords = new [(end - start) * 2];
        for (var i = start; i < end; i++) {
            var xy = getXY(i, data);
            var x = xy[0] - 120;
            var y = xy[1] - 120;
            coords[2 * (i - start)] = getR(x, y);
            coords[2 * (i - start) + 1] = getA(x, y);
        }
        return coords;
    }

    // Load your resources here
    function onLayout(dc) {
        var data = WatchUi.loadResource(Rez.JsonData.hands_json);
        mSecondCoords = loadCoords(data, PosSecond, PosMinuteLeft);
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
                Rez.Fonts.hour_sides17
            ],
            [
                loadCoords(data, PosHourLeft, PosHourRight),
                loadCoords(data, PosHourRight, PosEOF2)
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
            ],
            [
                loadCoords(data, PosMinuteLeft, PosMinuteRight),
                loadCoords(data, PosMinuteRight, PosHourLeft)
            ]
        );

        mGaugeHand = new Hand(
            Rez.JsonData.gauge_sides_json,
            [
                Rez.Fonts.gauge_sides0
            ],
            []
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
        mCap = WatchUi.loadResource(Rez.Drawables.Cap);

        cCoords = WatchUi.loadResource(Rez.JsonData.coords_json);
    }

    function getXY(i, data) {
        var d = data[i / 2];
        var shift = (i % 2 == 0)? 16: 0;
        var x = (d >> (shift + 8)) & 0xFF;
        var y = (d >> shift) & 0xFF;
        return [x, y];
    }

    function updateClip(x, y) {
        if (ax > x) {
            ax = x;
        }
        if (bx < x) {
            bx = x;
        }
        if (ay > y) {
            ay = y;
        }
        if (by < y) {
            by = y;
        }

    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    /**
    Draws hour and minute hands to device or buffer

    dc - device or buffer context
    time - local time info
    cx, cy - rotation center
    vector - bool flag to draw vector-based or font-based hands
     */
    function drawHourMinuteHands(dc, time, cx, cy, vector) {
        var hpos, hangle, mpos, mangle;
        hpos = (time.hour % 12) * 5 + time.min / 12;
        hangle = Math.toRadians(hpos * 6);
        mpos = time.min;
        mangle = Math.toRadians(mpos * 6);

        // Accents
        dc.setColor(0x000000, cTransparent);
        drawRadialRect(dc, hangle, 3, -10, 30, cx, cy);
        drawRadialRect(dc, mangle, 2, -10, 45, cx, cy);

        // Main part
        dc.setColor(0xFFFFFF, cTransparent);
        drawRadialRect(dc, hangle, 3, 30, 69, cx, cy);
        drawRadialRect(dc, mangle, 2, 45, 93, cx, cy);

        // Hands
        dc.setColor(0xAAAAAA, cTransparent);

        if (vector) {
            mHourHand.drawVector(dc, hpos, cx - 120, cy - 120);
            mMinuteHand.drawVector(dc, mpos, cx - 120, cy - 120);
        } else {
            mHourHand.draw(dc, hpos, cx - 120, cy - 120);
            mMinuteHand.draw(dc, mpos, cx - 120, cy - 120);
        }
    }

    /**
    Draws second hand poligon and accent

    * second hand is always drawed directly to device
    * thus, center is always (120, 120)
    * accent r radial coord is (80, 95)

    dc - device only context
    time - local time
     */
    function drawSecondHand(dc, time, withBuffer) {
        fx = ax;
        fy = ay;
        gx = bx;
        gy = by;
        ax = 240;
        ay = 240;
        bx = 0;
        by = 0;
        var angle = Math.toRadians(time.sec * 6);
        var sa = Math.sin(angle);
        var ca = Math.cos(angle);
        var x1 = 120 + 80 * sa;
        var y1 = 120 - 80 * ca;
        var x2 = 120 + 95 * sa;
        var y2 = 120 - 95 * ca;
        var points = fillRadialPolygon(dc, angle, mSecondCoords, 120, 120);
        // End of accent;
        updateClip(x2, y2);
        // Back part of hand corner coords
        updateClip(points[3][0], points[3][1]);
        updateClip(points[4][0], points[4][1]);

        if (withBuffer) {
            var mx = (fx < ax)? fx: ax;
            var my = (fy < ay)? fy: ay;
            var nx = (gx > bx)? gx: bx;
            var ny = (gy > by)? gy: by;
            dc.setClip(mx, my, Math.ceil(nx - mx + 1), Math.ceil(ny - my + 1));
            // FIXME: debug rect
            dc.setColor(0x00FF00, cTransparent);
            dc.drawRectangle(mx, my, Math.ceil(nx - mx + 1), Math.ceil(ny - my + 1));
            dc.drawBitmap(10, 20, mBuffer);
        }

        // Draw second hand main polygon
        dc.setColor(0x555555, cTransparent);
        dc.fillPolygon(points);
        // Draw red line for hand accent
        dc.setColor(0xFF0000, cTransparent);
        dc.drawLine(x1, y1, x2, y2);
        // Draw second hand cap;
        dc.drawBitmap(116, 116, mCap);
    }

    /**
    Draws background for gauge

    dc - device context
    number - index of gauge (used for compute common and gauge backgrounds position indices)
     */
    function drawGaugeBackground(dc, number) {
        var c = getXY(number, cCoords);
            dc.drawBitmap(c[0], c[1], cCommonGaugeBG);

        for (var i=PosGauge3 + number * 4; i < PosGauge3 + number * 4 + 4; i++) {
            c = getXY(i, cCoords);
            dc.drawBitmap(c[0], c[1], cBackgrounds[i - PosBackground]);
        }
    }

    /**
    Draws gauge hand

    dc - device context
    pos - gauge hand position [0-59]
    dx, dy - offsets for accent
    cap - font for gauge cap
     */
    function drawGaugeHand(dc, pos, dx, dy, cap) {
        var angle = Math.toRadians(pos * 6);
        dc.setColor(0xFF0000, cTransparent);
        drawRadialRect(dc, angle, 1, 8, 24, 120 - 10 + dx, 120 - 20 + dy);

        dc.setColor(0xFFFFFF, cTransparent);
        mGaugeHand.draw(dc, pos, 92 - 10 + dx, 91 - 20 + dy);

        dc.drawText(120 - 10 + dx, 120 - 1 - 20 + dy, cap, "0", cAlign);
    }

    /**
    Draws icons in utc gauge

    dc - device context
    pos - gauge hand position for proper icon rotation
     */
    function drawIcons(dc, pos, font) {
        var s = "ZABSN";
        for (var i = 0; i < 5; i++) {
            var a = Math.toRadians(pos * 6 - 120 + i * 360 / 6);
            var x = 120 - 10 + 12 * Math.sin(-a);
            var y = 165 - 20 + 12 * Math.cos(-a);
            dc.setColor((mIcons && (1 << i))? 0xFFFFFF: 0xAAAAAA, cTransparent);
            dc.drawText(x, y, font, s.substring(i, i + 1), cAlign);
        }

    }

    function onPartialUpdate(dc) {
        drawSecondHand(dc, System.getClockTime(), true);
    }

    /**
    Retrieves icons status from system.

    time - current time;
     */
    function updateIconStatus(time) {
        mIcons = 0;
        var settings = System.getDeviceSettings();
        var profile = UserProfile.getProfile();
        var alreadySleeping = time.hour * 3600 + time.min * 60 + time.sec > profile.sleepTime.value();
        var stillSleeping = time.hour * 3600 + time.min * 60 + time.sec < profile.wakeTime.value();

        mIcons += (alreadySleeping || stillSleeping)? 1: 0;
        mIcons += (settings.alarmCount > 0)? 2: 0;
        mIcons += (settings.phoneConnected)? 4: 0;
        mIcons += (settings.doNotDisturb)? 8: 0;
        mIcons += (settings.notificationCount > 0)? 16: 0;
    }

    // Update the view
    function onUpdate(dc) {
        // Prepare all data
        var stats = System.getSystemStats();
        var heartBeatIter = SensorHistory.getHeartRateHistory({});
        var heartBeatSample = heartBeatIter.next();
        var heartBeat = null;
        if (heartBeatSample != null) {
            heartBeat = heartBeatSample.data;
        }
        var pos, angle;

        // Getting UTC and local time info
        var now = Time.now();
        var time = Gregorian.info(now, Time.FORMAT_MEDIUM);
        var utc = Gregorian.utcInfo(now, Time.FORMAT_MEDIUM);

        utc = (utc.hour % 12) * 5 + utc.min / 12;

        updateIconStatus(time);

        var bc = mBuffer.getDc();
        // Drawing clock backgrounds
        bc.setColor(0xFFFFFF, 0x000055);
        bc.clear();

        for (var i=PosBackground; i< PosGauge3; i++) {
            var c = getXY(i, cCoords);
            bc.drawBitmap(c[0], c[1], cBackgrounds[i - PosBackground]);
        }

        for (var i=0; i< 3; i++) {
            drawGaugeBackground(bc, i);
        }

        var font = WatchUi.loadResource(Rez.Fonts.Smally);
        // Drawing texts
        bc.setColor(0xFFFFFF, cTransparent);
        // Battery
        bc.drawText(155, 90, font, stats.battery.toNumber(), cAlign);
        // Heartbeat
        if (heartBeat != null) {
            bc.drawText(66, 90, font, heartBeat.toString(), cAlign);
        }
        // Icons
        font = WatchUi.loadResource(Rez.Fonts.Icons);
        drawIcons(bc, utc, font);

        // Day of month
        bc.setColor(0x000000, cTransparent);
        font = WatchUi.loadResource(Rez.Fonts.Day);
        bc.drawText(172 - 10, 178 - 20, font, time.day / 10, cAlign);
        bc.drawText(177 - 10, 173 - 20, font, time.day % 10, cAlign);
        font = WatchUi.loadResource(Rez.Fonts.Date);
        // Day of week
        bc.drawText(61, 62, font, time.day_of_week.toUpper(), cAlign);
        // Month
        bc.drawText(160, 62, font, time.month.toUpper(), cAlign);

        // Drawing scales

        // Steps
        bc.setColor(0x55AAFF, cTransparent);
        font = WatchUi.loadResource(Rez.Fonts.steps_scale);
        for (var i = PosSteps; i < PosActivity; i++) {
            var c = getXY(i, cCoords);
            bc.drawText(c[0], c[1], font, i - PosSteps, Graphics.TEXT_JUSTIFY_LEFT);
        }
        // Activity
        font = WatchUi.loadResource(Rez.Fonts.activity_scale);
        for (var i = PosActivity; i < PosMovement; i++) {
            var c = getXY(i, cCoords);
            bc.drawText(c[0], c[1], font, i - PosActivity, Graphics.TEXT_JUSTIFY_LEFT);
        }
        // Movement
        bc.setColor(0xFF0000, cTransparent);
        font = WatchUi.loadResource(Rez.Fonts.movement_scale);
        for (var i = PosMovement; i < PosEOF; i++) {
            var c = getXY(i, cCoords);
            bc.drawText(c[0], c[1], font, i - PosMovement, Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Drawing gauge hands
        font = WatchUi.loadResource(Rez.Fonts.gauge_center);
        // Battery;
        pos = (30 + 50 * stats.battery / 100.0f).toNumber() % 60;
        drawGaugeHand(bc, pos, 44, 0, font);
        // UTC;
        drawGaugeHand(bc, utc, 0, 44, font);
        // Heartbeat
        if (heartBeat != null) {
            pos = (35 + 50 * (heartBeat + 70) / 200.0f).toNumber() % 60;
            drawGaugeHand(bc, pos, -45, 0, font);
        }

        // Drawing clock hands
        drawHourMinuteHands(bc, time, 120 - 10, 120 - 20, mIsBackgroundMode);

        // Drawing image to device context
        dc.setColor(0xAAAAAA, 0x000055);
        dc.clear();
        dc.clearClip();
        dc.drawBitmap(10, 20, mBuffer);


        // Drawind second hand to device context;
        drawSecondHand(dc, time, false);

    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
        mIsBackgroundMode = false;
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
        mIsBackgroundMode = true;
    }

}
