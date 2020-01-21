module lookout.weighedMapRegion;

import std.algorithm;
import std.typecons;

import std.stdio;

import arsd.simpledisplay;

import lookout.region;
import lookout.weighedMap;
import lookout.eventManager;

class WeighedMapRegion : Region {
    WeighedMap     weighedMap;
    Nullable!Point cross;
    AddressRange   displayRange;
    size_t         dataLength;

    /* This cache maintains address positions relatively to an
     * AddressRange. It avoids searching in-range addresses and computing
     * their mean address when the range doesn't change accross redraws.
     */
    struct CacheAddress {
        bool  isInRange;
        ubyte position;
    }
    CacheAddress[256][256] positionCache;
    bool hasPositionCache = false;
    uint pxsize;

    this(Point origin,
         Point end,
         WeighedMap wmap,
         size_t dataLength,
         uint pxsize)
    {
        super(origin, end);
        this.weighedMap = wmap;
        this.dataLength = dataLength;
        this.currentState = WeighedMapState.DEFAULT;
        this.pxsize = pxsize;
        displayRange = AddressRange(0, dataLength);

        hasChanged = true;
    }

    void setDisplayRange(size_t start, size_t finish) {
        displayRange     = AddressRange(start, finish);
        hasPositionCache = false;
        hasChanged       = true;
    }

    void removeDisplayRange() {
        displayRange     = AddressRange(0, dataLength);
        hasPositionCache = false;
        hasChanged       = true;
    }

    void drawPixel(ScreenPainter painter,
                   Point p,
                   ubyte weight,
                   ubyte position)
    {
        Color pixelColor = Color.fromIntegers(
                                       position*weight/64,
                                       weight,
                                       (256-position)*weight/64,
                                   );

        painter.fillColor    = pixelColor;
        painter.outlineColor = pixelColor;

        painter.drawRectangle(Point(origin.x + p.x*pxsize,
                                    origin.y + p.y*pxsize),
                              Point(origin.x + (p.x+1)*pxsize,
                                    origin.y + (p.y+1)*pxsize));
    }

    void drawWeighMap(ScreenPainter painter) {
        painter.fillColor    = Color.black;
        painter.outlineColor = Color.black;
        painter.drawRectangle(origin, end);

        foreach (x ; 0..256) {
            foreach (y ; 0..256) {
                if (weighedMap[x][y].weight == 0)
                    continue;

                if (hasPositionCache) {
                    if (positionCache[x][y].isInRange) {
                        drawPixel(painter,
                                  Point(x, y),
                                  weighedMap[x][y].weight,
                                  positionCache[x][y].position);
                    }
                    continue;
                }

                // No cache available yet, computing it

                size_t[] addrInRange;

                foreach (addr ; weighedMap[x][y].addresses)
                    if (displayRange.contains(addr))
                        addrInRange ~= addr;

                if (addrInRange.length == 0) {
                    positionCache[x][y].isInRange = false;
                    continue;
                }
                else {
                    positionCache[x][y].isInRange = true;
                }

                ulong meanAddr = addrInRange.fold!"a+b" / addrInRange.length;

                // Garanted < 256
                ubyte position = ((meanAddr-displayRange.origin)
                                    * 256 / displayRange.length) % 256;

                positionCache[x][y].position  = position;

                drawPixel(painter,
                          Point(x, y),
                          weighedMap[x][y].weight,
                          position);
            }
        }

        // Now we have a cache
        hasPositionCache = true;
    }

    void drawCross(ScreenPainter painter, Point p) {
        painter.outlineColor = Color.red;
        painter.drawLine(Point(p.x, origin.y), Point(p.x, end.y));
        painter.drawLine(Point(origin.x, p.y), Point(end.x, p.y));
    }

    override
    void redraw(ScreenPainter painter) {
        if (currentState == WeighedMapState.DEFAULT) {
            auto cs = cast(Default) currentState;

            if (displayRange.length == 0)
                return;

            drawWeighMap(painter);

            if (!cs.position.inRegion(this))
                return;

            drawCross(painter, cs.position);

            currentState = cs.update();
        }
        else if (currentState == WeighedMapState.SELECTING) {
            auto cs = cast(Selecting) currentState;
            currentState = cs.update();
        }
        else if (currentState == WeighedMapState.SHOWING_SELECTION) {
            auto cs = cast(ShowingSelection) currentState;
            currentState = cs.update();
        }
    }
}

struct AddressRange {
    size_t origin;
    size_t end;
    size_t length;

    this(size_t origin, size_t end) {
        if (origin > end) {
            this.origin = end;
            this.end    = origin;
        }
        else {
            this.origin = origin;
            this.end    = end;
        }

        this.length = this.end - this.origin;
    }

    bool contains(size_t address) {
        return origin <= address && address <= end;
    }

    bool containsAny(size_t[] addresses) {
        return addresses[].any!(address => origin <= address && address <= end);
    }
}

private:

struct WeighedMapState {
    static State DEFAULT;
    static State SELECTING;
    static State SHOWING_SELECTION;
}

static this() {
    WeighedMapState.DEFAULT           = new Default();
    WeighedMapState.SELECTING         = new Selecting();
    WeighedMapState.SHOWING_SELECTION = new ShowingSelection();
}

class Default : State {
    Point position;
    bool  LeftButtonPressed;

    this() {
        EventManager.get().register(&this.notify);
    }

    override
    void notify(Event ev) {
        switch (ev.type) {
            case LookoutEvent.MOUSE_LB_MOTION:
                LeftButtonPressed = true;
                position = ev.data.get!Point;
                break;

            case LookoutEvent.MOUSE_MOTION:
                position = ev.data.get!Point;
                break;

            default:
                break;
        }
    }

    override
    State update() {
        if (LeftButtonPressed) {
            LeftButtonPressed = false;

        /* At the moment, don't bother with selection

            auto next = cast(Selecting) WeighedMapState.SELECTING;
            next.origin   = this.position;
            next.position = this.position;

            return next;
        */
        }
        return WeighedMapState.DEFAULT;
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
        switch (ev.type) {
            case LookoutEvent.MOUSE_LB_RELEASED:
                LeftButtonReleased = true;
                position = ev.data.get!Point;
                break;

            case LookoutEvent.MOUSE_MOTION:
                position = ev.data.get!Point;
                break;

            default:
                break;
        }
    }

    override
    State update() {
        if (LeftButtonReleased) {
            LeftButtonReleased = false;
            auto next = cast(ShowingSelection) WeighedMapState.SHOWING_SELECTION;
            next.origin   = this.origin;
            next.position = this.position;
            return next;
        }
        return WeighedMapState.SELECTING;
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
        switch (ev.type) {
            case LookoutEvent.MOUSE_LB_PRESSED:
                LeftButtonClicked = true;
                break;

            case LookoutEvent.MOUSE_LB_MOTION:
                if (LeftButtonPressed)
                    LeftButtonPressed = false;
                break;

            case LookoutEvent.MOUSE_LB_RELEASED:
                if (LeftButtonPressed)
                    LeftButtonClicked = true;
                break;

            default:
                break;
        }
    }

    override
    State update() {
        if (LeftButtonClicked) {
            LeftButtonClicked = false;
            return WeighedMapState.DEFAULT;
        }
        return WeighedMapState.SHOWING_SELECTION;
    }
}
