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

    var mBackground;
    var mGauge3;
    var mGauge6;
    var mGauge9;
    var mBuffer;

    var mMinuteFonts = [
        Rez.Fonts.minute_sides0,
        Rez.Fonts.minute_sides1,
        Rez.Fonts.minute_sides2,
        Rez.Fonts.minute_sides3
    ];

    var mMinuteTiles;

    var mHourFonts = [
        Rez.Fonts.hour_sides0,
        Rez.Fonts.hour_sides1,
        Rez.Fonts.hour_sides2
    ];

    var mHourTiles;


    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
        mSmallyFont = WatchUi.loadResource(Rez.Fonts.Smally);
        mBackground = WatchUi.loadResource(Rez.Drawables.Background);
        mGauge3 = WatchUi.loadResource(Rez.Drawables.Gauge3);
        mGauge6 = WatchUi.loadResource(Rez.Drawables.Gauge6);
        mGauge9 = WatchUi.loadResource(Rez.Drawables.Gauge9);
        mBuffer = new Graphics.BufferedBitmap({
            :width=>mBackground.getWidth(),
            :height=>mBackground.getHeight()
        });

        mMinuteTiles = WatchUi.loadResource(Rez.JsonData.minute_sides_json);
        mHourTiles = WatchUi.loadResource(Rez.JsonData.hour_sides_json);
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }


    function drawHand(dc, glyph, fonts) {
        var prev_font = null;
        var font = null;
        for (var j = 0; j < glyph.size(); j++) {
            var tile = glyph[j];
            var f = (tile % 64).toNumber();
            tile /= 64;
            var c = (tile % 4).toNumber();
            tile /= 4;
            var char = (tile % 256).toNumber();
            tile /= 256;
            var x = (tile / 256).toNumber() - bgX;
            var y = (tile % 256).toNumber() - bgY;

            if (prev_font != f) {
            font = WatchUi.loadResource(fonts[f]);
                prev_font = f;
            }
            dc.drawText(x, y, font, char.toChar().toString(), Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // Update the view
    function onUpdate(dc) {
        var time = System.getClockTime();
        var stats = System.getSystemStats();
        dc.setColor(0xFFFFFF, 0x000055);
        dc.clear();
        var bc = mBuffer.getDc();
        bc.drawBitmap(0, 0, mBackground);
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

        drawHand(bc, mHourTiles[t], mHourFonts);

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

        drawHand(bc, mMinuteTiles[time.min], mMinuteFonts);

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
