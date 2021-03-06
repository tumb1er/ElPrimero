using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Application.Properties;

// buffered background screen offset;

// text align - center vertical and horizontal
const cAlign = Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER;
const cTransparent = Graphics.COLOR_TRANSPARENT;
/**
Watch view.
 */
class ElPrimeroView extends WatchUi.WatchFace {

    var CFonts = Rez.Fonts;
    var CDrawables = Rez.Drawables;
    var CJsonData = Rez.JsonData;
    var CStrings = Rez.Strings;
    // coords.json offsets
    enum {
        PosLogo = 20,
        PosGlyphs = 28,
        PosGauges = 40,
        PosSteps = 43,
        PosActivity = 48,
        PosMovement = 52,
        PosEOF = 57
    }
    // hands.json offsets
    enum {
        PosSecond,
        PosMinute = 5,
        PosHour = 13,
        PosEOF2 = 21
    }

    var mHourHand;
    var mMinuteHand;
    var mGaugeHand;

    var cCoords; // int32-packed coords (even at high word, odd at low word)

    var mSecondCoords;

    var mBuffer;
    var mCap;

    // String resources
    var cWeekDays, cMonths, cIcons;

    // internal state
    var mState;

    // prev clip
    var fx, fy, gx, gy;
    // clip
    var ax, ay, bx, by;

    // buffer pos
    var bufx, bufy, center;

    var mTimer;
    var mSecondTimestamp = null;
    var mSecondValue = null;

    var mBackgroundFont;
    var mSmallyFont, mIconsFont, mDayFont, mDateFont, mGaugeFont;
    var mStepsFont, mActivityFont, mMovementFont;

    function initialize() {
        WatchFace.initialize();
        ax = 240;
        ay = 240;
        bx = 0;
        by = 0;
        mState = new State();
    }

    function loadCoords(data, start, end) {
        var coords = new [(end - start) * 2];
        for (var i = start; i < end; i++) {
            var xy = getXY(i, data);
            // 120 here is signed value alignment offset
            var x = xy[0] - 120;
            var y = xy[1] - 120;
            coords[2 * (i - start)] = getR(x, y);
            coords[2 * (i - start) + 1] = getA(x, y);
        }
        return coords;
    }

    // Load your resources here
    function onLayout(dc) {
        mTimer = new Timer.Timer();

        bufx = loadResource(CStrings.bufferX).toNumber();
        bufy = loadResource(CStrings.bufferY).toNumber();
        center = loadResource(CStrings.center).toNumber();

        var data = loadResource(CJsonData.hands_json);
        mSecondCoords = loadCoords(data, PosSecond, PosMinute);
        mHourHand = new Hand(
            CJsonData.hour_sides_json,
            [
                CFonts.hour_sides0,
                CFonts.hour_sides1,
                CFonts.hour_sides2,
                CFonts.hour_sides3,
                CFonts.hour_sides4,
                CFonts.hour_sides5,
                CFonts.hour_sides6,
                CFonts.hour_sides7,
                CFonts.hour_sides8,
                CFonts.hour_sides9,
                CFonts.hour_sides10,
                CFonts.hour_sides11,
                CFonts.hour_sides12,
                CFonts.hour_sides13,
                CFonts.hour_sides14,
                CFonts.hour_sides15,
                CFonts.hour_sides16,
                CFonts.hour_sides17
            ],
            loadCoords(data, PosHour, PosEOF2)
        );

        mMinuteHand = new Hand(
            CJsonData.minute_sides_json,
            [
                CFonts.minute_sides0,
                CFonts.minute_sides1,
                CFonts.minute_sides2,
                CFonts.minute_sides3,
                CFonts.minute_sides4,
                CFonts.minute_sides5,
                CFonts.minute_sides6,
                CFonts.minute_sides7
            ],
            loadCoords(data, PosMinute, PosHour)
        );

        mGaugeHand = new Hand(
            CJsonData.gauge_sides_json,
            [
                CFonts.gauge_sides0
            ],
            null
        );

        mBuffer = new Graphics.BufferedBitmap({
            :width=>218,
            :height=>200
        });
        mCap = loadResource(CDrawables.Cap);

        cCoords = loadResource(CJsonData.coords_json);
        cWeekDays = loadResource(Rez.Strings.WeekDays);
        cMonths = loadResource(Rez.Strings.Months);
        cIcons = loadResource(Rez.Strings.Icons);

        mBackgroundFont = loadResource(Rez.Fonts.Background);
        mSmallyFont = loadResource(CFonts.Smally);
        mIconsFont =loadResource(CFonts.Icons);
        mDayFont = loadResource(CFonts.Day);
        mDateFont = loadResource(CFonts.Date);
        mGaugeFont = loadResource(CFonts.gauge_center);
        mStepsFont = loadResource(CFonts.steps_scale);
        mActivityFont = loadResource(CFonts.activity_scale);
        mMovementFont = loadResource(CFonts.movement_scale);

        syncVersion();
    }

    /**
    Synchronizes displayed version for settings screen.
     */
    function syncVersion(){
    	var settingsVersion = null;
    	try {
        	settingsVersion = Properties.getValue("appVersion");
		} catch (e instanceof Properties.InvalidKeyException) {}
        var resourcesVersion = loadResource(Rez.Strings.InternalVersion);
        if (!resourcesVersion.equals(settingsVersion)) {
        	try {
            	Properties.setValue("appVersion", resourcesVersion);
            } catch (e instanceof Properties.InvalidKeyException) {}
        }
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

    function invalidateHourMinuteHands(dc, cx, cy) {
        if (mHourHand.mPos != mState.mHourPos) {
            // System.println("invalidateHands: hour");

            // erasing hour hand at previous position
            dc.setColor(mState.mBackgroundColor, cTransparent);
            mHourHand.drawVector(dc, mHourHand.mPos, cx - center, cy + 1 - center, center);
        }

        if (mMinuteHand.mPos != mState.mMinutePos) {
            // System.println("invalidateHands: min");

            // erasing minute hand at previous position
            dc.setColor(mState.mBackgroundColor, cTransparent);
            mMinuteHand.drawVector(dc, mMinuteHand.mPos, cx - center, cy + 1 - center, center);
        }

    }

    /**
    Draws hour or minute hand
    dc - device context
    hand - mHourHand or mMinuteHand
    pos - hand position
    coords - packed width and points for details rectangles
    toBuffer - draw to buffer or device directly
    vector - vector mode drawing
     */
    function drawClockHand(dc, hand, pos, coords, toBuffer, vector) {
        var cx, cy, angle, width, negative, middle, end;
        if (toBuffer) {
            cx = center - bufx;
            cy = center - bufy;
        } else {
            cx = center;
            cy = center;
        }
        width = coords && 0xFF;
        negative = -((coords >> 8) && 0xFF);
        middle = (coords >> 16) && 0xFF;
        end = (coords >> 24) && 0xFF;
        angle = Math.toRadians(pos * 6);

//        if (width == 3) {
//             System.println(["drawClockHand (hour)", vector]);
//        } else {
//             System.println(["drawClockHand (min)", vector]);
//        }

        // vector hand
        if (vector) {
            dc.setColor(0xAAAAAA, cTransparent);
            hand.drawVector(dc, pos, cx - center, cy + 1 - center, center);
        }

        // details
        dc.setColor(0x000000, cTransparent);
        drawRadialRect(dc, angle, width, negative, middle, cx, cy + 1);
        dc.setColor(0xFFFFFF, cTransparent);
        drawRadialRect(dc, angle, width, middle, end, cx, cy + 1);

        // glyph
        if (!vector) {
            dc.setColor(0xAAAAAA, cTransparent);
            // 120 here is json coords alignment
            hand.draw(dc, pos, cx - 120, cy - 120);
        }
    }

    /**
    Draws second hand poligon and accent

    * second hand is always drawed directly to device
    * thus, center is always (center, center)
    * accent r radial coord is (80, 95)

    dc - device only context
    time - local time
     */
    function drawSecondHand(dc, withBuffer) {
        // System.println(["drawSecondHand", withBuffer]);
        fx = ax;
        fy = ay;
        gx = bx;
        gy = by;
        ax = 240;
        ay = 240;
        bx = 0;
        by = 0;
        var pos;
        var timer = System.getTimer();
        if (mSecondValue == mState.mSecondPos && mSecondTimestamp != null && mSecondTimestamp + 250 < timer) {
            // second draw of same second
            pos = mState.mSecondPos * 6 + 3;
        } else {
            // first draw of current second
            pos = mState.mSecondPos * 6;
            mSecondValue = mState.mSecondPos;
        }
        mSecondTimestamp = timer;
        var angle = Math.toRadians(pos);
        var sa = Math.sin(angle);
        var ca = Math.cos(angle);
        var x1 = center + 80 * sa;
        var y1 = center - 80 * ca;
        var x2 = center + 95 * sa;
        var y2 = center - 95 * ca;
        var points = fillRadialPolygon(dc, angle, mSecondCoords, center, center);
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
            dc.drawBitmap(bufx, bufy, mBuffer);
        }

        // Draw second hand main polygon
        dc.setColor(0x555555, cTransparent);
        dc.fillPolygon(points);
        // Draw red line for hand accent
        dc.setColor(0xFF0000, cTransparent);
        dc.drawLine(x1, y1, x2, y2);
        // Draw second hand cap;
        dc.drawBitmap(center - 4, center - 4, mCap);
    }

    /**
    Draws background for gauge

    dc - device context
    number - index of gauge (used for compute common and gauge backgrounds position indices)
     */
    function drawGaugeBackground(dc, number) {
        // System.println(Lang.format("drawGaugeBackground $1$", [number]));
        var c = getXY(number + PosGauges, cCoords);
        dc.setColor(0x000000, 0x000000);
        dc.fillCircle(c[0] + 10, c[1], 28);

        var startPos = (number == 0)? 0: 4 * number - 1;
        for (var i = startPos; i < startPos + number + 3; i++) {
            c = getXY(PosGlyphs + i, cCoords);
            var char = 60 + i;
            if (char == 61 || char == 69) {
                dc.setColor(0xFF0000, cTransparent);
            } else if (char == 68) {
                dc.setColor(0x5555FF, cTransparent);
            } else {
                dc.setColor(0xFFFFFF, cTransparent);
            }
            dc.drawText(10 + c[0], -1 + c[1], mBackgroundFont, char.toChar(), Graphics.TEXT_JUSTIFY_LEFT);
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
        if (pos == null) {
            return;
        }
        var angle = Math.toRadians(pos * 6);
        dc.setColor(0xFF0000, cTransparent);
        drawRadialRect(dc, angle, 1, 8, 24, center - bufx + dx, center - bufy + dy);

        dc.setColor(0xFFFFFF, cTransparent);
        mGaugeHand.draw(dc, pos, 82 + dx, 71 + dy);

        dc.drawText(center - bufx + dx, center - bufy - 1 + dy, cap, "0", cAlign);
    }

    /**
    Draws icons in utc gauge

    dc - device context
    pos - gauge hand position for proper icon rotation
    font - icons font
     */
    function drawIcons(dc, pos, font) {
        if (pos == null) {
            return;
        }
        for (var i = 0; i < 5; i++) {
            var a = Math.toRadians(pos * 6 - 120 + i * 360 / 6);
            var x = 120 - 10 + 12 * Math.sin(-a);
            var y = 165 - 20 + 12 * Math.cos(-a);
            dc.setColor((mState.mIcons && (1 << i))? 0xFFFFFF: 0x5555AA, cTransparent);
            dc.drawText(x, y, font, cIcons.substring(i, i + 1), cAlign);
        }

    }

    function drawBackgrounds(bc, flags) {
        var char, coords, pos;
        if (flags == State.ALL) {
            // System.println("drawBackgrounds: all");

            bc.setColor(0xFFFFFF, mState.mBackgroundColor);
            bc.clear();
            for (pos=0; pos < PosGlyphs; pos++) {
                coords = getXY(pos, cCoords);
                char = pos + 32;
                bc.drawText(10 + coords[0], -1 + coords[1], mBackgroundFont, char.toChar(), Graphics.TEXT_JUSTIFY_LEFT);
            }
        } else if ((flags & State.MINUTE) && mMinuteHand.mPos != null) {
            // System.println("drawBackgrounds: minute/ticks");

            bc.setColor(0xFFFFFF, mState.mBackgroundColor);
            char = 32 + mMinuteHand.mPos / 3;
            coords = getXY(mMinuteHand.mPos / 3, cCoords);
            bc.drawText(10 + coords[0], -1 + coords[1], mBackgroundFont, char.toChar(), Graphics.TEXT_JUSTIFY_LEFT);

            pos = (mMinuteHand.mPos + 12) % 60 / 3;
            if (pos + PosLogo < PosGlyphs) {
                // System.println("drawBackgrounds: minute/logo");
                char = 52 + pos;
                coords = getXY(pos + PosLogo, cCoords);
                bc.drawText(10 + coords[0], -1 + coords[1], mBackgroundFont, char.toChar(), Graphics.TEXT_JUSTIFY_LEFT);
            }

            pos = (mHourHand.mPos + 12) % 60 / 3;
            if (pos + PosLogo < PosGlyphs) {
                // System.println("drawBackgrounds: hour/logo");

                char = 52 + pos;
                coords = getXY(pos + PosLogo, cCoords);
                bc.drawText(10 + coords[0], -1 + coords[1], mBackgroundFont, char.toChar(), Graphics.TEXT_JUSTIFY_LEFT);
            }
        }

        for (var i=0; i< 3; i++) {
            if (flags & (State.BATTERY << i)) {
                drawGaugeBackground(bc, i);
            }
        }
    }

    function onPartialUpdate(dc) {
        if (!mState.mIsPowersafeMode) {
            var time = mState.updateDateTime(Time.now());
            // System.println(Lang.format("$1$:$2$:$3$ onPartialUpdate", [time.hour, time.min, time.sec]));
            drawSecondHand(dc, true);
        }
    }

    // Update the view
    function onUpdate(dc) {
        // Prepare all data
        var flags = mState.onUpdateStart();
        var time = System.getClockTime();
        // System.println(Lang.format("$1$:$2$:$3$ onUpdate", [time.hour, time.min, time.sec]));
        var pos, angle;

        var bc = mBuffer.getDc();

        if ((flags & State.HOUR) || !mState.mIsPowersafeMode) {
            // redraw buffer if not in powersafe or hour hand moved

            // in active/background mode eraze previous hands positions
            invalidateHourMinuteHands(bc, center - bufx, center - bufy);
            // System.println("drawBackgrounds");
            drawBackgrounds(bc, flags);

            if (flags & State.BATTERY){
                // System.println("G3 text");
                // Battery
                bc.setColor(0xFFFFFF, cTransparent);
                bc.drawText(155, 90, mSmallyFont, mState.mBatteryValue, cAlign);
            }

            if (flags & State.HEARTBEAT) {
                // System.println("G9 text");
                // Heartbeat
                if (mState.mHeartRateValue != null) {
                    bc.setColor(0xFFFFFF, cTransparent);
                    bc.drawText(66, 90, mSmallyFont, mState.mHeartRateValue, cAlign);
                }
            }

            if (flags & State.ICONS) {
                // System.println("G6 icons");
                // Icons
                drawIcons(bc, mState.mUTCPos, mIconsFont);
            }

            if (flags & State.DAY_OF_MONTH) {
                 // System.println("Day of month");
                // Day of month
                bc.setColor(0x000000, cTransparent);
                bc.drawText(center + 53 - bufx, center + 58 - bufy, mDayFont, mState.mDay / 10, cAlign);
                bc.drawText(center + 58 - bufx, center + 53 - bufy, mDayFont, mState.mDay % 10, cAlign);
            }

            if (flags & State.DAY_OF_WEEK) {
                // System.println("Day of week");
                bc.setColor(0x000000, cTransparent);
                // Day of week
                bc.drawText(61, 62, mDateFont, cWeekDays.substring(mState.mWeekDay * 3 - 3, mState.mWeekDay * 3), cAlign);
            }
            if (flags & State.MONTH) {
                // System.println("Month");
                // Month
                bc.setColor(0x000000, cTransparent);
                bc.drawText(160, 62, mDateFont, cMonths.substring(mState.mMonth * 3 - 3, mState.mMonth * 3), cAlign);
            }
            // Drawing scales

            if (flags & State.STEPS) {
                 // System.println("steps");
                // Steps
                for (var i = PosSteps; i < PosActivity; i++) {
                    var c = getXY(i, cCoords);
                    bc.setColor((i < mState.mStepsFraction + PosSteps)? 0xFFFFFF: 0x5555AA, cTransparent);
                    bc.drawText(c[0], c[1], mStepsFont, i - PosSteps, Graphics.TEXT_JUSTIFY_LEFT);
                }
            }

            if (flags & State.ACTIVITY) {
                 // System.println("activity");

                // Activity
                for (var i = PosActivity; i < PosMovement; i++) {
                    var c = getXY(i, cCoords);
                    bc.setColor((i < mState.mActivityFraction + PosActivity)? 0xFFFFFF: 0x5555AA, cTransparent);
                    bc.drawText(c[0], c[1], mActivityFont, i - PosActivity, Graphics.TEXT_JUSTIFY_LEFT);
                }
            }
            if (flags & State.MOVEMENT) {
                 // System.println("movement");
                // Movement
                bc.setColor(0xFF0000, cTransparent);
                for (var i = PosMovement; i < PosEOF; i++) {
                    var c = getXY(i, cCoords);
                    bc.setColor((i < mState.mMovementFraction + PosMovement)? 0xFF0000: 0xAAAAAA, cTransparent);
                    bc.drawText(c[0], c[1], mMovementFont, i - PosMovement, Graphics.TEXT_JUSTIFY_LEFT);
                }
            }
            if (flags & State.BATTERY) {
                // Battery;
                 // System.println("G3 hand");

                drawGaugeHand(bc, mState.mBatteryPos, 44, 0, mGaugeFont);
            }
            if (flags & State.ICONS) {
                 // System.println("G6 hand");
                // UTC;
                drawGaugeHand(bc, mState.mUTCPos, 0, 44, mGaugeFont);
            }
            if (flags & State.HEARTBEAT) {
                 // System.println("G9 hand");
                // Heartbeat
                if (mState.mHeartRatePos != null) {
                    drawGaugeHand(bc, mState.mHeartRatePos, -45, 0, mGaugeFont);
                }
            }

            if (flags & State.TIME) {
                // draw hour hand to buffer
                drawClockHand(bc, mHourHand, mState.mHourPos, 1159596547, true,
                              mState.mIsPowersafeMode); // 69, 30, -10, 3
            }
        }

        if ((flags & State.TIME) && !mState.mIsPowersafeMode) {
            // Drawing clock hands to buffer in active/background modes
            drawClockHand(bc, mMinuteHand, mState.mMinutePos, 1563232770, true, false); // 93, 45, -10, 2

        }


        // Drawing image to device context
        if (flags == State.ALL) {
            // System.println("Clear DC");
            dc.setColor(0xAAAAAA, mState.mBackgroundColor);
            dc.clearClip();
            dc.clear();
        }

        // System.println("draw buffer");
        dc.clearClip();
        dc.drawBitmap(bufx, bufy, mBuffer);

        if (!mState.mIsPowersafeMode) {
            // System.println("second hand");
            // Drawind second hand to device context;
            // (only in active/background modes
            drawSecondHand(dc, false);
        } else {
            // Draw minute hands in powersafe mode
            drawClockHand(dc, mMinuteHand, mState.mMinutePos, 1563232770, false, true); // 93, 45, -10, 2

        }
        mState.onUpdateFinished();
        if (!(mState.mIsBackgroundMode) && mState.mTwoHertzMode) {
			mTimer.stop();
			try {
        		mTimer.start(method(:timerCallback), 500, false);
        	} catch ( ex ) {
        		System.println(["2Hz error", ex.getErrorMessage()]);
        	}
        }
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
        mState.reset(true);
        System.println("onShow");
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
        System.println("onHide");
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
        System.println("onExitSleep");
        mState.reset(false);
        
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
        System.println("onEnterSleep");
        mState.reset(true);
    }

    function timerCallback() {
        // System.println("RequestUpdate");
        WatchUi.requestUpdate();
    }

}
