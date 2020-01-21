module lookout.windowRegion;

import std.algorithm;
import std.format;
import std.typecons;

import arsd.simpledisplay;

import lookout.eventManager;
import lookout.region;

class WindowRegion : Region {
    Nullable!Point  coordinates;
    Nullable!size_t addressOne;
    Nullable!size_t addressTwo;
    uint            pxsize;

    this(Point origin, Point end, uint pxsize) {
        super(origin, end);
        this.currentState = WindowState.DEFAULT;
        this.pxsize = pxsize;
        hasChanged = true;
    }

    void setCoordinateText(Point p) {
        coordinates = p;
        hasChanged = true;
    }

    void removeCoordinateText() {
        coordinates = Nullable!Point.init;
        hasChanged = true;
    }

    void setAddressTextOne(size_t address) {
        this.addressOne = address;
        hasChanged = true;
    }

    void setAddressTextTwo(size_t address) {
        this.addressTwo = address;
        hasChanged = true;
    }

    void removeAddressTextTwo() {
        this.addressTwo = Nullable!size_t.init;
        hasChanged = true;
    }

    override
    void redraw(ScreenPainter painter) {
        if (!hasChanged)
            return;

        hasChanged = false;

        painter.fillColor    = Color.black;
        painter.outlineColor = Color.black;
        painter.drawRectangle(origin, Point(origin.x + 20, end.y));
        painter.drawRectangle(Point(origin.x, end.y-20), end);

        painter.outlineColor = Color.white;

        if (!coordinates.isNull) {
            painter.drawText(Point(origin.x+2, coordinates.get().y-5),
                             format("%02X", 255-(coordinates.get().y / pxsize)));
            painter.drawText(Point(coordinates.get().x-5, end.y-20+2),
                             format("%02X", (coordinates.get().x-20) / pxsize));
        }

        if (!addressOne.isNull) {
            auto textPosition = Point(end.x-486, end.y-20+2);

            if (addressTwo.isNull) {
                painter.drawText(textPosition,
                                 format("%09X - %09X",
                                        addressOne.get(), addressOne.get()));
            }
            else {
                size_t addressOne = min(this.addressOne.get(),
                                        this.addressTwo.get());
                size_t addressTwo = max(this.addressOne.get(),
                                        this.addressTwo.get());

                painter.drawText(textPosition,
                                 format("%09X - %09X",
                                        addressOne, addressTwo));
            }
        }
    }
}

private:

struct WindowState {
    static State DEFAULT;
}

static this() {
    WindowState.DEFAULT = new Default();
}

class Default : State {
    this() {
        EventManager.get().register(&this.notify);
    }

    void notify(Event ev) {}

    State update() {
        return this;
    }
}

