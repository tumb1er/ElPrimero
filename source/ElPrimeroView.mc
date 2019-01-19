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

// position of Gauge3 within buffer;
const g3X = 136 - bgX;
const g3Y = 92 - bgY;

// screen Gauge3 position;
const g3centerX = g3X + bgX;
const g3centerY = g3Y + bgY;

// position of Gauge6 within buffer;
const g6X = 90 - bgX;
const g6Y = 135 - bgY;

// screen Gauge6 position;
const g6centerX = g6X + bgX;
const g6centerY = g6Y + bgY;

// position of Gauge9 within buffer;
const g9X = 47 - bgX;
const g9Y = 92 - bgY;

// screen Gauge9 position;
const g9centerX = g9X + bgX;
const g9centerY = g9Y + bgY;

// position of battery text within buffer;
const batX = 164 - bgX;
const batY = 110 - bgY;

// position of hear rate text within buffer;
const hrX = 75 - bgX;
const hrY = 110 - bgY;

// position of week text;
const weekX = 69 - bgX;
const weekY = 82 - bgY;

// position of month text;
const monthX = 169 - bgX;
const monthY = 82 - bgY;

// position of day first digit;
//const day1X = 172 - bxX;
//const day1Y = 180 - bgY;
//
//// position of day second digit;
//const day2X = 180 - bxX;
//const day2Y = 173 - bgY;

const cAlign = Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER;


class ElPrimeroView extends WatchUi.WatchFace {
    var mSmallyFont;

    var mBackgrounds;
    var mBGPositions = [
        [0,0],
        [0,68],
        [186,68],
        [0,134],
        [154,134],
        [47,163]
    ];
    var mGauge3;
    var mGauge6;
    var mGauge9;
    var mBuffer;

    var mMinuteFonts = [
        Rez.Fonts.minute_sides0,
        Rez.Fonts.minute_sides1,
        Rez.Fonts.minute_sides2,
        Rez.Fonts.minute_sides3,
        Rez.Fonts.minute_sides4,
        Rez.Fonts.minute_sides5,
        Rez.Fonts.minute_sides6,
        Rez.Fonts.minute_sides7
    ];

    var mMinuteTiles;
    var mMinuteIndex;

    var mHourFonts = [
        Rez.Fonts.hour_sides0,
        Rez.Fonts.hour_sides1,
        Rez.Fonts.hour_sides2,
        Rez.Fonts.hour_sides3,
        Rez.Fonts.hour_sides4,
        Rez.Fonts.hour_sides5,
        Rez.Fonts.hour_sides6
    ];

    var mHourTiles;
    var mHourIndex;

    var mGaugeFonts = [
        Rez.Fonts.gauge_sides0
    ];

    var mGaugeTiles;
    var mGaugeIndex;

    var mFontCacheIdx;
    var mFontCache;

    var mDatesFont;

    var mDayFont;

    var mStepsScaleFont;
    var mStepsX;
    var mStepsY;

    function initialize() {
        WatchFace.initialize();
        mFontCacheIdx = [-1, -1, -1];
        mFontCache = [null, null, null];
    }

    // Load your resources here
    function onLayout(dc) {
        mSmallyFont = WatchUi.loadResource(Rez.Fonts.Smally);
        mBackgrounds = [
            WatchUi.loadResource(Rez.Drawables.BGTop),
            WatchUi.loadResource(Rez.Drawables.BGLeft),
            WatchUi.loadResource(Rez.Drawables.BGRight),
            WatchUi.loadResource(Rez.Drawables.BGLeftBottom),
            WatchUi.loadResource(Rez.Drawables.BGRightBottom),
            WatchUi.loadResource(Rez.Drawables.BGBottom)
        ];
        mGauge3 = WatchUi.loadResource(Rez.Drawables.Gauge3);
        mGauge6 = WatchUi.loadResource(Rez.Drawables.Gauge6);
        mGauge9 = WatchUi.loadResource(Rez.Drawables.Gauge9);
        mBuffer = new Graphics.BufferedBitmap({
            :width=>218,
            :height=>200
        });

        var json;
        json = WatchUi.loadResource(Rez.JsonData.minute_sides_json);
        mMinuteTiles = json[0];
        mMinuteIndex = json[1];
        json = WatchUi.loadResource(Rez.JsonData.hour_sides_json);
        mHourTiles = json[0];
        mHourIndex = json[1];
        json = WatchUi.loadResource(Rez.JsonData.gauge_sides_json);
        mGaugeTiles = json[0];
        mGaugeIndex = json[1];

        mDatesFont = WatchUi.loadResource(Rez.Fonts.Date);
        mDayFont = WatchUi.loadResource(Rez.Fonts.Day);

        mStepsScaleFont = WatchUi.loadResource(Rez.Fonts.steps_scale);
        mStepsX = [8,   0,   0,  2,  11];
        mStepsY = [136, 111, 83, 56, 31];
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    function unpackValue(i, index) {
        if (i == -1) {
            return 0;
        }
        var shift = (i % 2)? 0: 16;
        return (index[i / 2] >> shift) && 0x0000FFFF;
    }

    function drawHand(dc, glyph, tiles, index, fonts, n, dx, dy) {
        var start = unpackValue(glyph - 1, index);
        var end = unpackValue(glyph, index);
        for (var j = start; j < end; j++) {
            var tile = tiles[j];
            var b = (tile & 0x000000FF);
            var f = b % 64;
            var c = b / 64;
            var char = (tile & 0x0000FF00) >> 8;
            var x = (tile & 0x00FF0000) >> 16 - bgX + dx;
            b = (tile & 0xFF000000) >> 24;
            var y = b & 0xFF - bgY + dy;
            if (mFontCache[n] != f || mFontCacheIdx[n] == null) {
                mFontCacheIdx[n] = null;
                System.println(Lang.format("Loading font $1$ for $2$", [f, n]));
                var used = System.getSystemStats().usedMemory;
                mFontCacheIdx[n] = WatchUi.loadResource(fonts[f]);
                var stats = System.getSystemStats();
                System.println(Lang.format("Loaded $1$ bytes, free $2$", [stats.usedMemory - used, stats.freeMemory]));
                mFontCache[n] = f;
            }
            dc.drawText(x, y, mFontCacheIdx[n], char.toChar().toString(), Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    function onPartialUpdate(dc) {
        onUpdate(dc);
    }

    // Update the view
    function onUpdate(dc) {
        var time = System.getClockTime();
        var stats = System.getSystemStats();
        var heartBeatIter = SensorHistory.getHeartRateHistory({});
        var heartBeatSample = heartBeatIter.next();
        var heartBeat = null;
        dc.setColor(0xFFFFFF, 0x000055);
        dc.clear();
        var bc = mBuffer.getDc();
        bc.setColor(0xFFFFFF, 0x000055);
        bc.clear();
        for (var i=0; i< 6; i++) {
            var pos = mBGPositions[i];
            var bg = mBackgrounds[i];
            bc.drawBitmap(pos[0], pos[1], bg);
        }
        bc.drawBitmap(g3X, g3Y, mGauge3);
        bc.drawBitmap(g6X, g6Y, mGauge6);
        bc.drawBitmap(g9X, g9Y, mGauge9);
        bc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        bc.drawText(batX, batY, mSmallyFont, stats.battery.toNumber(), cAlign);
        if (heartBeatSample != null) {
            heartBeat = heartBeatSample.data;
            if (heartBeat != null) {
                bc.drawText(hrX, hrY, mSmallyFont, heartBeat.toString(), cAlign);
            }
        }

        var t = (time.hour % 12) * 5 + time.min / 12;

        var angle = Math.toRadians(-t * 360/60);


        bc.setPenWidth(8);

        bc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        bc.drawLine(120 - bgX + 15 * Math.sin(angle),
                    120 - bgY + 15 * Math.cos(angle),
                    120 - bgX - 20 * Math.sin(angle),
                    120 - bgY - 20 * Math.cos(angle));

        bc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        bc.drawLine(120 - bgX - 20 * Math.sin(angle),
                    120 - bgY - 20 * Math.cos(angle),
                    120 - bgX - 70 * Math.sin(angle),
                    120 - bgY - 70 * Math.cos(angle));

        bc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);

        drawHand(bc, t, mHourTiles, mHourIndex, mHourFonts, 0, 0, 0);

        angle = Math.toRadians(-time.min * 360/60);

        bc.setPenWidth(5);
        bc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        bc.drawLine(120 - bgX + 15 * Math.sin(angle),
                    120 - bgY + 15 * Math.cos(angle),
                    120 - bgX - 45 * Math.sin(angle),
                    120 - bgY - 45 * Math.cos(angle));

        bc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        bc.drawLine(120 - bgX - 45 * Math.sin(angle),
                    120 - bgY - 45 * Math.cos(angle),
                    120 - bgX - 95 * Math.sin(angle),
                    120 - bgY - 95 * Math.cos(angle));

        bc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);

        drawHand(bc, time.min, mMinuteTiles, mMinuteIndex, mMinuteFonts, 1, 0, 0);

        bc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);

        t = (30 + 50 * stats.battery / 100.0f).toNumber() % 60;

        drawHand(bc, t, mGaugeTiles, mGaugeIndex, mGaugeFonts, 2, g3centerX, g3centerY);

        if (heartBeat != null) {
            t = (35 + 50 * heartBeat / 200.0f).toNumber() % 60;
            drawHand(bc, t, mGaugeTiles, mGaugeIndex, mGaugeFonts, 2, g9centerX, g9centerY);
        }

        time = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);

        bc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        bc.drawText(weekX, weekY, mDatesFont, time.day_of_week.toUpper(), cAlign);
        bc.drawText(monthX, monthY, mDatesFont, time.month.toUpper(), cAlign);

        bc.drawText(172 - bgX, 178 - bgY, mDayFont, time.day / 10, cAlign);
        bc.drawText(177 - bgX, 173 - bgY, mDayFont, time.day % 10, cAlign);

        bc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 5; i++) {
            bc.drawText(mStepsX[i], mStepsY[i], mStepsScaleFont, i, Graphics.TEXT_JUSTIFY_LEFT);
        }

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
