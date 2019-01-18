using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Math;

// buffered background screen offset;
const bgX = 9;
const bgY = 20;

// position of Gauge3 within buffer;
const g3X = 136 - bgX;
const g3Y = 92 - bgY;

// position of Gauge6 within buffer;
const g6X = 90 - bgX;
const g6Y = 135 - bgY;

// position of Gauge9 within buffer;
const g9X = 47 - bgX;
const g9Y = 92 - bgY;

// position of battery text within buffer;
const batX = 164 - bgX;
const batY = 110 - bgY;

// position of hear rate text within buffer;
const hrX = 75 - bgX;
const hrY = 110 - bgY;

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
        Rez.Fonts.minute_sides5
    ];

    var mMinuteTiles;
    var mMinuteIndex;

    var mHourFonts = [
        Rez.Fonts.hour_sides0,
        Rez.Fonts.hour_sides1,
        Rez.Fonts.hour_sides2,
        Rez.Fonts.hour_sides3,
        Rez.Fonts.hour_sides4
    ];

    var mHourTiles;
    var mHourIndex;

    var mTileFonts;
    var mPrevFonts;

    var mGaugeFont;
    var mGaugeTiles;
    var mGaugeIndex;

    function initialize() {
        WatchFace.initialize();
        mTileFonts = [-1, -1];
        mPrevFonts = [null, null];
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
        mGaugeFont = WatchUi.loadResource(Rez.Fonts.gauge_sides0);
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

    function drawHand(dc, glyph, tiles, index, fonts, n) {
        var start = unpackValue(glyph - 1, index);
        var end = unpackValue(glyph, index);
        for (var j = start; j < end; j++) {
            var tile = tiles[j];
            var b = (tile & 0x000000FF);
            var f = b % 64;
            var c = b / 64;
            var char = (tile & 0x0000FF00) >> 8;
            var x = (tile & 0x00FF0000) >> 16 - bgX;
            b = (tile & 0xFF000000) >> 24;
            var y = b & 0xFF - bgY;
            if (mPrevFonts[n] != f || mTileFonts[n] == null) {
                mTileFonts[n] = null;
                mTileFonts[1-n] = null;
                mTileFonts[n] = WatchUi.loadResource(fonts[f]);
                mPrevFonts[n] = f;
            }
            dc.drawText(x, y, mTileFonts[n], char.toChar().toString(), Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // Update the view
    function onUpdate(dc) {
        var time = System.getClockTime();
        var stats = System.getSystemStats();
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
        bc.drawText(hrX, hrY, mSmallyFont, "42", cAlign);

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

        drawHand(bc, t, mHourTiles, mHourIndex, mHourFonts, 0);

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

        drawHand(bc, time.min, mMinuteTiles, mMinuteIndex, mMinuteFonts, 1);

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
