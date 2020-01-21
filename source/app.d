module lookout.app;

import std.algorithm;
import std.conv;
import std.file;
import std.random;
import std.range;
import std.stdio;
import std.variant;

import arsd.simpledisplay;

import lookout.bitmapRegion;
import lookout.hexdumpRegion;
import lookout.region;
import lookout.weighedMap;
import lookout.weighedMapRegion;
import lookout.windowRegion;
import lookout.eventManager;

void redraw(SimpleWindow window, Region[] regions, OperatingSystemFont font) {
    auto painter = window.draw();
    painter.setFont(font);

    foreach (region ; regions)
        region.redraw(painter);
}

int main(string[] args) {
    if (args.length == 1) {
        writeln("Usage: lookout FILE");
        return 1;
    }

    uint pxsize = 3;

    auto window = new SimpleWindow(256*pxsize + 20 + 256 + 280,
                                   256*pxsize + 20,
                                   "Lookout: " ~ args[1]);

    ubyte[] data = cast(ubyte[])read(args[1]);


    // Sample big files
    ubyte[] sampledData;

    if (data.length > 1024*1024)
        sampledData = data.randomSample(1024*1024).array;
    else
        sampledData = data;

    WeighedMap weighedMap;

    // Populate weighedMap
    foreach (index, coordinates ; sampledData.slide(2).enumerate()) {
        ubyte x = coordinates[0];
        ubyte y = 255 - coordinates[1];

        weighedMap[x][y].increase(cast(ubyte) (index*256 / sampledData.length));
        weighedMap[x][y].addresses ~= index;
    }

    weighedMap.rescale();

    auto windowRegion = new WindowRegion(
                                Point(0, 0),
                                Point(window.width, window.height),
                                pxsize
                            );

    auto weighedMapRegion = new WeighedMapRegion(
                                Point(20, 0),
                                Point(256*pxsize + 20, 256*pxsize),
                                weighedMap,
                                sampledData.length,
                                pxsize,
                            );

    // Padd small files
    auto bitmapOrigin = Point(weighedMapRegion.end.x, 0);
    auto bitmapEnd    = Point(weighedMapRegion.end.x + 256, 256*pxsize);
    auto bitmapCapacity = (bitmapEnd.x - bitmapOrigin.x)
                        * (bitmapEnd.y - bitmapOrigin.y) / 8;

    if (sampledData.length < bitmapCapacity) {
        sampledData ~= repeat(0).take(bitmapCapacity - sampledData.length)
                         .map!(to!ubyte)
                         .array;
    }

    auto bitmapRegion = new BitmapRegion(bitmapOrigin, bitmapEnd, sampledData);

    auto hexdumpRegion = new HexdumpRegion(
                                Point(bitmapRegion.end.x, 0),
                                Point(bitmapRegion.end.x + 280, window.height),
                                data
                            );

    auto eventManager = EventManager.get();

    bool isSelectingFromBitmap;
    size_t addressOne, addressTwo;
    size_t fakeAddressOne, fakeAddressTwo;

    auto font = new OperatingSystemFont("fixed", 13);

    Region[] regionsToBeDrawn = [
        windowRegion,
        weighedMapRegion,
        bitmapRegion,
        hexdumpRegion,
    ];

    window.redraw(regionsToBeDrawn, font);
    window.eventLoop(20,
        delegate () {
            window.redraw(regionsToBeDrawn, font);
        },
        delegate (MouseEvent event) {
            // New State/Event system
            if (event.type == MouseEventType.motion &&
                    event.modifierState & ModifierState.leftButtonDown)
            {
                eventManager.notify(Event.get(LookoutEvent.MOUSE_LB_MOTION,
                                              Point(event.x, event.y)));
            }
            else if (event.type == MouseEventType.buttonReleased &&
                    event.button == MouseButton.left)
            {
                eventManager.notify(Event.get(LookoutEvent.MOUSE_LB_RELEASED,
                                              Point(event.x, event.y)));
            }
            else if (event.type == MouseEventType.buttonPressed &&
                    event.button == MouseButton.left)
            {
                eventManager.notify(Event.get(LookoutEvent.MOUSE_LB_PRESSED,
                                              Point(event.x, event.y)));
            }
            else {
                eventManager.notify(Event.get(LookoutEvent.MOUSE_MOTION,
                                              Point(event.x, event.y)));
            }
        },
    );

    return 0;
}
