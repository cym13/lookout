module lookout.app;

import std.algorithm;
import std.conv;
import std.file;
import std.random;
import std.range;
import std.stdio;

import arsd.simpledisplay;

import lookout.bitmapRegion;
import lookout.globalState;
import lookout.hexdumpRegion;
import lookout.region;
import lookout.weighedMap;
import lookout.weighedMapRegion;
import lookout.windowRegion;

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
                                Point(window.width, window.height)
                            );

    auto weighedMapRegion = new WeighedMapRegion(
                                Point(20, 0),
                                Point(256*pxsize + 20, 256*pxsize),
                                weighedMap,
                                sampledData.length
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

    Region[] regionsToBeDrawn = [
        weighedMapRegion,
        windowRegion,
        bitmapRegion,
        hexdumpRegion,
    ];

    bool isSelectingFromBitmap;
    size_t addressOne, addressTwo;
    size_t fakeAddressOne, fakeAddressTwo;

    auto font = new OperatingSystemFont("fixed", 13);

    window.redraw(regionsToBeDrawn, font);
    window.eventLoop(20,
        delegate () {
            window.redraw(regionsToBeDrawn, font);
        },
        delegate (MouseEvent event) {
            // Mouse in weighedmap panel
            if (Point(event.x, event.y).inRegion(weighedMapRegion)) {
                weighedMapRegion.setCross(Point(event.x, event.y));
                windowRegion.setCoordinateText(Point(event.x, event.y));
            }
            else {
                weighedMapRegion.removeCross();
                windowRegion.removeCoordinateText();
            }

            // Mouse in bitmap panel
            if (Point(event.x, event.y).inRegion(bitmapRegion)) {
                hexdumpRegion.setAddress(event.y * data.length
                              / (bitmapRegion.end.y - bitmapRegion.origin.y));

                if (!isSelectingFromBitmap) {
                    bitmapRegion.setMarkOne(Point(event.x, event.y));

                    addressOne = event.y * data.length
                              / (bitmapRegion.end.y - bitmapRegion.origin.y);

                    fakeAddressOne = addressOne*sampledData.length/data.length;

                    if (!bitmapRegion.selecting) {
                        windowRegion.setAddressTextOne(addressOne);
                    }
                }

                if (event.type == MouseEventType.motion &&
                        event.modifierState & ModifierState.leftButtonDown) {
                    isSelectingFromBitmap = true;

                    bitmapRegion.setMarkTwo(Point(event.x, event.y));
                    addressTwo = event.y * data.length
                          / (bitmapRegion.end.y - bitmapRegion.origin.y);
                    fakeAddressTwo = addressTwo*sampledData.length/data.length;
                    windowRegion.setAddressTextTwo(addressTwo);

                    weighedMapRegion.setDisplayRange(fakeAddressOne,
                                                     fakeAddressTwo);
                }
            }

            // Stop address range selection
            if (isSelectingFromBitmap &&
                    event.type == MouseEventType.buttonPressed)
            {
                isSelectingFromBitmap = false;
                bitmapRegion.removeMarkTwo();
                windowRegion.removeAddressTextTwo();

                weighedMapRegion.removeDisplayRange();
            }
        },
    );

    return 0;
}
