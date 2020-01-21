module lookout.region;

import arsd.simpledisplay;

import lookout.eventManager;

class Region {
    Point origin;
    Point end;
    bool  hasChanged;
    State currentState;

    this(Point origin, Point end) {
        assert(origin.x < end.x);
        assert(origin.y < end.y);

        this.origin     = origin;
        this.end        = end;

        EventManager.get().register(&this.notify);
    }

    @property
    int width() {
        return end.x - origin.x;
    }

    @property
    int height() {
        return end.y - origin.y;
    }

    void notify(Event ev) {}

    void redraw(ScreenPainter) {}
}

bool inRegion(Point p, Region r) {
    return (r.origin.x <= p.x && p.x < r.end.x
         && r.origin.y <= p.y && p.y < r.end.y);
}

interface State {
    void notify(Event ev);
    State update();
}

