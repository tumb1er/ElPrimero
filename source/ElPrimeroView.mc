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
    enum {
        PosCommon,
        PosBackground = 3,
        PosSteps = 21,
        PosActivity = 26,
        PosMovement= 30,
        PosEOF=35
    }
    var mHourHand;
    var mMinuteHand;
    var mGaugeHand;

    var cCoords; // int32-packed coords (even at high word, odd at low word)

    var mSecondCoordsX, mSecondCoordsY;

    var cCommonGaugeBG;
    var cBackgrounds;

    var mBuffer;

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
                    Rez.Fonts.hour_sides17
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

    function drawHandDetails(dc, pos, cx, cy, params) {
        var angle = Math.toRadians(pos * 6);
        for (var i = 0; i < params[:colors].size(); i++) {
            dc.setColor(params[:colors][i], Graphics.COLOR_TRANSPARENT);
            drawRadialRect(dc, angle, params[:width], params[:coords][i], params[:coords][i + 1], cx, cy);
        }
    }

    /**
    Draws hour and minute hands to device or buffer

    dc - device or buffer context
    time - local time info
    cx, cy - rotation center
    vector - bool flag to draw vector-based or font-based hands
     */
    function drawHourMinuteHands(dc, time, cx, cy, vector) {
        var pos;
        // Hour hand
        pos = (time.hour % 12) * 5 + time.min / 12;
        drawHandDetails(dc, pos, cx, cy + 1, {:width => 3, :colors => [0x000000, 0xFFFFFF], :coords => [-10, 20, 69]});
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        mHourHand.draw(dc, pos, 0, 0);
        // Minute hand
        pos = time.min;
        drawHandDetails(dc, pos, cx, cy + 1, {:width => 2, :colors => [0x000000, 0xFFFFFF], :coords => [-10, 45, 93]});
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        mMinuteHand.draw(dc, pos, 0, 0);
    }

    /**
    Draws second hand poligon and accent

    * second hand is always drawed directly to device
    * thus, center is always (120, 120)
    * accent r radial coord is (80, 95)

    dc - device only context
    time - local time
     */
    function drawSecondHand(dc, time) {
        var angle = Math.toRadians(time.sec * 6);
        var points = new[5];
        // Prepare polygon coords
        for (var i = 0; i < 5; i++) {
            var r = mSecondCoordsX[i];
            var a = mSecondCoordsY[i];
            var x = getX(120, r, a + angle);
            var y = getY(120, r, a + angle);
            points[i] = [x, y];
        }
        // Fill polygon with grey
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(points);
        // Draw red line for hand accent
        dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(120 + 80 * Math.sin(angle), 120 - 80 * Math.cos(angle),
                    120 + 95 * Math.sin(angle), 120 - 95 * Math.cos(angle));
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
        var pos;

        // Getting UTC and local time info
        var now = Time.now();
        var time = Gregorian.info(now, Time.FORMAT_MEDIUM);
        var utc = Gregorian.utcInfo(now, Time.FORMAT_MEDIUM);

        utc = (utc.hour % 12) * 5 + utc.min / 12;

        var bc = mBuffer.getDc();
        // Drawing clock backgrounds
        bc.setColor(0xFFFFFF, 0x000055);
        bc.clear();

        for (var i=PosCommon; i < PosBackground; i++) {
            var c = getXY(i, cCoords);
            bc.drawBitmap(c[0], c[1], cCommonGaugeBG);
        }

        for (var i=PosBackground; i< PosSteps; i++) {
            var c = getXY(i, cCoords);
            bc.drawBitmap(c[0], c[1], cBackgrounds[i - PosBackground]);
        }

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
        for (var i = 0; i < 5; i++) {
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
        bc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        font = WatchUi.loadResource(Rez.Fonts.movement_scale);
        for (var i = PosMovement; i < PosEOF; i++) {
            var c = getXY(i, cCoords);
            bc.drawText(c[0], c[1], font, i - PosMovement, Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Drawing gauge hands

        // Battery;
        font = WatchUi.loadResource(Rez.Fonts.gauge_center);
        pos = (30 + 50 * stats.battery / 100.0f).toNumber() % 60;
        drawHandDetails(bc, pos, 120 - bgX + 44, 120 - bgY, {:width => 1, :colors => [0xFF0000], :coords => [8, 24]});
        bc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        mGaugeHand.draw(bc, pos, 136 - bgX, 92 - bgY);
        bc.drawText(164 - bgX, 120 - bgY, font, "0", cAlign);

        // Heartbeat;
        if (heartBeat != null) {
            pos = (35 + 50 * heartBeat / 200.0f).toNumber() % 60;
            drawHandDetails(bc, pos, 120 - bgX - 45, 120 - bgY,
                {:width => 1, :colors => [0xFF0000], :coords => [8, 24]});
            bc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            mGaugeHand.draw(bc, pos, 47 - bgX, 92 - bgY);
            bc.drawText(75 - bgX, 120 - bgY, font, "0", cAlign);
        }

        // UTC time gauge;
        drawHandDetails(bc, utc, 120 - bgX, 120 - bgY + 44, {:width => 1, :colors => [0x000000], :coords => [8, 24]});
        bc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        mGaugeHand.draw(bc, utc, 92 - bgX, 136 - bgY);
        bc.drawText(120 - bgX, 164 - bgY, font, "0", cAlign);

        // Drawing image to device context
        dc.setColor(0xAAAAAA, 0x000055);
        dc.clear();
        dc.drawBitmap(bgX, bgY, mBuffer);

        // Drawing clock hands
        drawHourMinuteHands(dc, time, 120, 120, false);

        // Drawind second hand to device context;
        drawSecondHand(dc, time);

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
