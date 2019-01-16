using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;

// buffered background screen offset;
const bgX = 9;
const bgY = 20;

class ElPrimeroView extends WatchUi.WatchFace {
    var mSmallyFont;
    var mBackground;
    var mBuffer;

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
        mSmallyFont = WatchUi.loadResource(Rez.Fonts.Smally);
        mBackground = WatchUi.loadResource(Rez.Drawables.Background);
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
        dc.setColor(0xFFFFFF, 0x000055);
        dc.clear();
        dc.drawBitmap(9, 20, mBackground);
        dc.drawText(120, 120, mSmallyFont, "12345:68790", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
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
