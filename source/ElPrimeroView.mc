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

    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    // Update the view
    function onUpdate(dc) {

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
