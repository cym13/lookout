module lookout.region;

import arsd.simpledisplay;

class Region {
    Point origin;
    Point end;
    bool  hasChanged;

    this(Point origin, Point end) {
        this.origin     = origin;
        this.end        = end;
    }

    void redraw(ScreenPainter) {}
}

bool inRegion(Point p, Region r) {
    return (r.origin.x <= p.x && p.x < r.end.x
         && r.origin.y <= p.y && p.y < r.end.y);
}

