using Toybox.Math;
/**
 Draws thick rotated line

 dc - device context
 angle - rotation angle in radians
 width - half of line width
 start, end - radial R coordinates of line
 cx, cy - rotation center coords
 */
function drawRadialRect(dc, angle, width, start, end, cx, cy) {
    var sina = Math.sin(angle);
    var cosa = Math.cos(angle);
    var dx = width * cosa;
    var dy = width * sina;

    var sx = start * sina;
    var sy = - start * cosa;
    var ex = end * sina;
    var ey = - end * cosa;
    dc.fillPolygon([
       [cx + sx + dx, cy + sy + dy],
       [cx + sx - dx, cy + sy - dy],
       [cx + ex - dx, cy + ey - dy],
       [cx + ex + dx, cy + ey + dy]
    ]);
}


/*
Get X coordinate from radius and angle.
*/
function getX(cx, r, a) {
    return cx - r * Math.sin(-a);
}
/*
Get Y coordinate from radius and angle.
*/
function getY(cy, r, a) {
    return cy - r * Math.cos(-a);
}
/*
Get radius coordinate from point.
*/
function getR(x, y) {
    return Math.sqrt(x * x + y * y);
}
/*
Get angle coordinate from points in radians.
*/
function getA(x, y) {
    return Math.atan2(-x, -y);
}