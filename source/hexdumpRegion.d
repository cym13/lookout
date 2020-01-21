module lookout.hexdumpRegion;

import std.algorithm;
import std.conv;
import std.format;
import std.range;

import arsd.simpledisplay;

import lookout.region;
import lookout.eventManager;

class HexdumpRegion : Region {
    size_t  address;
    ubyte[] data;

    this(Point origin, Point end, ref ubyte[] data) {
        super(origin, end);
        this.data = data;
        this.currentState = HexmapRegionState.DEFAULT;
        hasChanged = true;
    }

    override
    void notify(Event ev) {
        if (ev.type == LookoutEvent.BM_CHANGE_CURSOR) {
            this.address = positionToAddress(ev.data.get!int);
            hasChanged = true;
        }
    }

    size_t positionToAddress(int pos) {
        return min(pos * data.length / 256, data.length-8*45);
    }

    string hexdump(size_t address) {
        import std.ascii: isGraphical;

        address = address - (address % 16);

        // TODO make it better

        string result;

        foreach (i, c ; data[address .. address + 8*45].chunks(8).enumerate())
        {
            result ~= format(
                        "%09X  %02X%02X%02X%02X %02X%02X%02X%02X  %s\n",
                        address + i*8,
                        c[0], c[1], c[2], c[3], c[4], c[5], c[6], c[7],
                        c.map!(x => x.isGraphical ? x : '.')
                         .map!(x => (cast(char) x).to!string)
                         .join()
                    );
        }
        return result;
    }

    override
    void redraw(ScreenPainter painter) {
        if (!hasChanged)
            return;

        hasChanged = false;

        if (currentState != HexmapRegionState.DEFAULT)
            return;

        painter.fillColor    = Color.black;
        painter.outlineColor = Color.black;
        painter.drawRectangle(origin, end);

        painter.outlineColor = Color.white;

        painter.drawText(Point(origin.x + 5, origin.y + 5), hexdump(address));
    }
}

private:

struct HexmapRegionState {
    static State DEFAULT;
}

static this() {
    HexmapRegionState.DEFAULT = new Default();
}

class Default : State {
    ulong position;

    this() {
        EventManager.get().register(&this.notify);
    }

    void notify(Event ev) {}

    State update() {
        return this;
    }
}
