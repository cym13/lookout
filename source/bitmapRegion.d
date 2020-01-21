module lookout.bitmapRegion;

import std.algorithm;
import std.random;
import std.range;

import arsd.simpledisplay;

import lookout.region;
import lookout.eventManager;

class BitmapRegion : Region {
    size_t  capacity;
    ubyte[] bitmap;
    Point   markOne;
    Point   markTwo;
    bool    selecting;

    EventManager eventManager;

    this(Point origin, Point end, ubyte[] data) {
        super(origin, end);
        this.currentState = BitmapState.DEFAULT;
        this.eventManager = EventManager.get();
        this.markOne      = Point(origin.x, origin.y);
        this.capacity     = (end.x - origin.x) * (end.y - origin.y) / 8;

        ubyte[] bitsOf(ubyte x) {
            ubyte[] result;

            foreach (i ; 1 .. 9)
                result ~= (x >> (8-i)) % 2;

            return result;
        }

        this.bitmap = data.randomSample(capacity)
                          .map!(x => bitsOf(x))
                          .join
                          .array;
        hasChanged = true;
    }

    void setMarkOne(Point p) {
        markOne = p;
        hasChanged = true;
    }

    void removeMarkOne() {
        markOne = Point(origin.x, origin.y);
        hasChanged = true;
    }

    void setMarkTwo(Point p) {
        selecting = true;
        markTwo = p;
        hasChanged = true;
    }

    void removeMarkTwo() {
        selecting = false;
        markOne = Point(end.x, end.y);
        hasChanged = true;
    }

    void drawCursor(ScreenPainter painter, int position) {
        painter.outlineColor = Color.red;
        painter.drawLine(Point(0, position), Point(width, position));
    }

    void drawSelection(ScreenPainter painter, int start, int finish) {
        painter.outlineColor = Color.gray;
        painter.fillColor    = Color.gray;
        painter.drawRectangle(Point(0, 0),      Point(width, start));
        painter.drawRectangle(Point(0, finish), Point(width, height));

        drawCursor(painter, start);
        drawCursor(painter, finish);
    }

    override
    void redraw(ScreenPainter painter) {
        if (currentState is BitmapState.DEFAULT) {
            auto cs = cast(Default) currentState;
            eventManager.notify(Event.get!int(
                                    LookoutEvent.BM_CHANGE_CURSOR,
                                    cs.position.y * 256 / this.height
                                ));
            drawCursor(painter, cs.position.y);
            currentState = cs.update();
        }
        else if (currentState is BitmapState.SELECTING) {
            auto cs = cast(Selecting) currentState;
            drawSelection(painter, cs.origin.y, cs.position.y);
            eventManager.notify(Event.get!int(
                                    LookoutEvent.BM_CHANGE_CURSOR,
                                    cs.position.y * 256 / this.height
                                ));
            currentState = cs.update();
        }
        else if (currentState is BitmapState.SHOWING_SELECTION) {
            auto cs = cast(ShowingSelection) currentState;
            drawSelection(painter, cs.origin.y, cs.position.y);
            eventManager.notify(Event.get!int(
                                    LookoutEvent.BM_CHANGE_CURSOR,
                                    cs.position.y * 256 / this.height
                                ));
            currentState = cs.update();
        }
    }
}

private:

struct BitmapState {
    static State DEFAULT;
    static State SELECTING;
    static State SHOWING_SELECTION;
}

static this() {
    BitmapState.DEFAULT           = new Default();
    BitmapState.SELECTING         = new Selecting();
    BitmapState.SHOWING_SELECTION = new ShowingSelection();
}

class Default : State {
    Point position;
    bool LeftButtonPressed;

    this() {
        EventManager.get().register(&this.notify);
    }

    override
    void notify(Event ev) {
        if (ev.type == LookoutEvent.MOUSE_LB_MOTION) {
            LeftButtonPressed = true;
            position = ev.data.get!Point;
        }
        else if (ev.type == LookoutEvent.MOUSE_MOTION) {
            position = ev.data.get!Point;
        }
    }

    override
    State update() {
        if (LeftButtonPressed) {
            LeftButtonPressed = false;

            auto next = cast(Selecting) BitmapState.SELECTING;
            next.origin   = this.position;
            next.position = this.position;

            return next;
        }
        return BitmapState.DEFAULT;
    }
}

class Selecting : State {
    Point origin;
    Point position;
    bool  LeftButtonReleased;

    this() {
        EventManager.get().register(&this.notify);
    }

    override
    void notify(Event ev) {
        if (ev.type == LookoutEvent.MOUSE_LB_RELEASED) {
            LeftButtonReleased = true;
            position = ev.data.get!Point;
        }
        else if (ev.type == LookoutEvent.MOUSE_MOTION) {
            position = ev.data.get!Point;
        }
    }

    override
    State update() {
        if (LeftButtonReleased) {
            LeftButtonReleased = false;
            auto next = cast(ShowingSelection) BitmapState.SHOWING_SELECTION;
            next.origin   = this.origin;
            next.position = this.position;
            return next;
        }
        return BitmapState.SELECTING;
    }
}

class ShowingSelection : State {
    Point origin;
    Point position;
    bool  LeftButtonPressed;
    bool  LeftButtonClicked;

    this() {
        EventManager.get().register(&this.notify);
    }

    override
    void notify(Event ev) {
        if (ev.type == LookoutEvent.MOUSE_LB_PRESSED) {
            LeftButtonClicked = true;
            return;
        }

        if (LeftButtonPressed && ev.type == LookoutEvent.MOUSE_LB_MOTION) {
            LeftButtonPressed = false;
            return;
        }

        if (LeftButtonPressed && ev.type == LookoutEvent.MOUSE_LB_RELEASED) {
            LeftButtonClicked = true;
            return;
        }
    }

    override
    State update() {
        if (LeftButtonClicked) {
            LeftButtonClicked = false;
            return BitmapState.DEFAULT;
        }
        return BitmapState.SHOWING_SELECTION;
    }
}
