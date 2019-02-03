using Toybox.Graphics;
using Toybox.System;
using Toybox.WatchUi;




/**
Draws anti-aliased clock hand from tiles
 */
class Hand {
    var mFontList;       // list of fonts resource ids
    var mTiles;          // tiles data (array of packed x,y, font and char number)
    var mIndex;          // tiles index (16bit end positions in tiles data for each glyph)
    var mFont;           // cached font resource
    var mCurrentFontIdx; // current cached font number
    var mVectorList;     // list of poligons for vector-based drawing
    var mPos;            // last drawn position
    /**
     Unpacks int32-packed to bytes array
     */
    function toBytes(array){
        var res = new [array.size() * 4]b;
        for (var i = 0; i<array.size(); i++) {
            var v = array[i];
            var j = i * 4;
            res[j] = (v >> 24) && 0xFF;
            res[j + 1] = (v >> 16) && 0xFF;
            res[j + 2] = (v >> 8) && 0xFF;
            res[j + 3] = v && 0xFF;
        }
        return res;
    }

    /**
    jsonId - Rez.jsonData identifier for tile data
    fontsList - list of Rez.Fonts identifiers
    vectorList - packed coords for vector hand shape
     */
    function initialize(jsonId, fontsList, vectorList) {
        var json = WatchUi.loadResource(jsonId);
        mTiles = toBytes(json[0]);
        mIndex = toBytes(json[1]);

        mFontList = fontsList;

        mFont = null;
        mCurrentFontIdx = -1;
        mVectorList = vectorList;
    }

    /**
    Unpacks tile position from int32 to low or high 16bit part.

    i - glyph nymber
     */
    function getTileIdx(i) {
        if (i == -1) {
            return 0;
        }
        return mIndex[i * 2] * 256 + mIndex[i * 2 + 1];
    }

    /**
    Draws hand position.

    dc - device context
    pos - position number
    dx, dy - offset for encoded tiles positions
     */
    function draw(dc, pos, dx, dy) {
        var start = getTileIdx(pos - 1);
        var end = getTileIdx(pos);
        for (var j = start; j < end; j++) {
//            var tile = mTiles[j];
//            var f = tile & 0x3F;
//            var char = (tile >> 8) & 0xFF;
//            var x = (tile >> 16) & 0xFF + dx;
//            var y = (tile >> 24) & 0xFF + dy;
            var k = j * 4;
            var f = mTiles[k + 3];
            var char = mTiles[k + 2];
            var x = mTiles[k + 1] + dx;
            var y = mTiles[k] + dy;
            dc.drawText(x, y, getFont(f), char.toChar().toString(), Graphics.TEXT_JUSTIFY_LEFT);
        }
        mPos = pos;

//        // FIXME: OOM prevention
//        if (mFontList.size() > 1) {
//            mFont = null;
//        }
    }

    /**
    Draws hand position with vector polygons

    dc - device context
    pos - position number
    dx, dy - offset from screen center
     */
    function drawVector(dc, pos, dx, dy) {
        if (pos == null) {
            return;
        }
        var angle = Math.toRadians(pos * 6);
        var points = fillRadialPolygon(dc, angle, mVectorList, 120 + dx, 120 + dy);
        dc.fillPolygon(points);
        mPos = pos;
    }

    /**
    Gets cached value for font.

    f - font number
     */
    function getFont(f) {
        if (mCurrentFontIdx != f || mFont == null) {
            // free memory used by prev cached font
            mFont = null;
            // System.println(Lang.format("Loading font $1$", [f]));
//            var used = System.getSystemStats().usedMemory;
            mFont = WatchUi.loadResource(mFontList[f]);
//            var stats = System.getSystemStats();
//            var fontSize = stats.usedMemory - used;
            // System.println(Lang.format("Loaded $1$ bytes, free $2$", [fontSize, stats.freeMemory]));
            mCurrentFontIdx = f;
        }
        return mFont;
    }


}