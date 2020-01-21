module lookout.bitmapRegion;

import std.algorithm;
import std.random;
import std.range;

import arsd.simpledisplay;

import lookout.region;

class BitmapRegion : Region {
    size_t  capacity;
    ubyte[] bitmap;
    Point   markOne;
    Point   markTwo;
    bool    selecting;

    this(Point origin, Point end, ubyte[] data) {
        super(origin, end);
        this.currentState = BitmapState.DEFAULT;

        this.markOne = Point(origin.x, origin.y);

        this.capacity = (end.x - origin.x) * (end.y - origin.y) / 8;

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

    void redrawFuture(ScreenPainter painter) {
        if (currentState is BitmapState.DEFAULT) {
            auto cs = cast(Default) currentState;
            drawCursor(painter, cs.position.y);
            currentState = cs.update();
        }
        else if (currentState is BitmapState.SELECTING) {
            auto cs = cast(Selecting) currentState;
            drawSelection(painter, cs.origin.y, cs.position.y);
            currentState = cs.update();
        }
        else if (currentState is BitmapState.SHOWING_SELECTION) {
            auto cs = cast(ShowingSelection) currentState;
            drawSelection(painter, cs.origin.y, cs.position.y);
            currentState = cs.update();
        }
    }

    override
    void redraw(ScreenPainter painter) {
        if (!hasChanged)
            return;

        hasChanged = false;

        painter.fillColor    = Color.black;
        painter.outlineColor = Color.black;
        painter.drawRectangle(origin, end);

        int x = origin.x;
        int y = origin.y;

        size_t minMark = min(markOne.y, markTwo.y);
        size_t maxMark = max(markOne.y, markTwo.y);

        auto currentColor = Color.green;
        painter.outlineColor = currentColor;
        foreach (i,b ; bitmap[].enumerate) {
            x += 1;
            if (x >= end.x) {
                x = origin.x;
                y += 1;
            }

            if (b == 0)
                continue;

            if (selecting
                 && currentColor == Color.green
                 && (y < minMark || y > maxMark))
            {
                currentColor = Color.gray;
                painter.outlineColor = currentColor;
            }
            else if (currentColor == Color.gray
                 && (y >= minMark && y <= maxMark))
            {
                currentColor = Color.green;
                painter.outlineColor = currentColor;
            }

            painter.drawRectangle(Point(x, y),
                                  Point(x + 1, y));
        }

        if (!selecting) {
            painter.outlineColor = Color.red;
            painter.drawLine(Point(origin.x, markOne.y),
                             Point(end.x, markOne.y));
        }
        else {
            painter.outlineColor = Color.red;
            painter.drawLine(Point(origin.x, markOne.y),
                             Point(end.x, markOne.y));
            painter.drawLine(Point(origin.x, markTwo.y),
                             Point(end.x, markTwo.y));
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

    override
    void notify(LookoutEvent ev, Point p) {
        if (ev == LookoutEvent.LB_MOTION)
            LeftButtonPressed = true;
        position = p;
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

    override
    void notify(LookoutEvent ev, Point p) {
        if (ev == LookoutEvent.LB_RELEASED)
            LeftButtonReleased = true;
        position = p;
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

    override
    void notify(LookoutEvent ev, Point p) {
        if (ev == LookoutEvent.LB_PRESSED) {
            LeftButtonClicked = true;
            return;
        }

        if (LeftButtonPressed && ev == LookoutEvent.LB_MOTION) {
            LeftButtonPressed = false;
            return;
        }

        if (LeftButtonPressed && ev == LookoutEvent.LB_RELEASED) {
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
