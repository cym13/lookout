module lookout.app;

import std;
import arsd.simpledisplay;

auto pxsize = 3;

struct WeighedPixel {
    ubyte  weight;
    ubyte  position;
    size_t address;

    void increase(ubyte new_position) {
        if (weight == 0) {
            position = new_position;
            weight = 1;
            return;
        }

        position = (position + new_position) / 2;

        if (weight < 255)
            weight += 1;
    }
}

alias WeighedMap = WeighedPixel[256][256];

struct AddressRange {
    size_t origin;
    size_t end;

    this(size_t origin, size_t end) {
        if (origin > end) {
            this.origin = end;
            this.end    = origin;
        }
        else {
            this.origin = origin;
            this.end    = end;
        }
    }

    bool contains(size_t address) {
        return (origin <= address && address <= end);
    }
}

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

class WeighedMapRegion : Region {
    WeighedMap weighedMap;
    Nullable!Point cross;
    Nullable!AddressRange displayRange;

    this(Point origin, Point end, WeighedMap wmap) {
        super(origin, end);
        this.weighedMap = wmap;
        hasChanged = true;
    }

    void setDisplayRange(size_t start, size_t finish) {
        displayRange = AddressRange(start, finish);
        hasChanged = true;
    }

    void removeDisplayRange() {
        displayRange = Nullable!AddressRange.init;
        hasChanged = true;
    }

    override
    void redraw(ScreenPainter painter) {
        if (!hasChanged)
            return;

        hasChanged = false;

        painter.fillColor    = Color.black;
        painter.outlineColor = Color.black;
        painter.drawRectangle(origin, end);

        void drawPixel(int x, int y, WeighedPixel pixel) {
            Color pixelColor = Color.fromIntegers(
                                           pixel.position*pixel.weight/64,
                                           pixel.weight,
                                           (256-pixel.position)*pixel.weight/64,
                                       );

            painter.fillColor    = pixelColor;
            painter.outlineColor = pixelColor;

            painter.drawRectangle(Point(origin.x + x*pxsize,
                                        origin.y + y*pxsize),
                                  Point(origin.x + (x+1)*pxsize,
                                        origin.y + (y+1)*pxsize));
        }

        foreach (x ; 0..256) {
            foreach (y ; 0..256) {
                if (displayRange.isNull ||
                        displayRange.get().contains(weighedMap[x][y].address))
                {
                    drawPixel(x, y, weighedMap[x][y]);
                }
            }
        }

        if (cross.isNull)
            return;

        painter.fillColor    = Color.red;
        painter.outlineColor = Color.red;
        painter.drawLine(Point(cross.get().x, origin.y),
                         Point(cross.get().x, end.y));
        painter.drawLine(Point(origin.x, cross.get().y),
                         Point(end.x, cross.get().y));
    }

    void setCross(Point p) {
        cross = nullable(p);
        hasChanged = true;
    }

    void removeCross() {
        cross = Nullable!Point.init;
        hasChanged = true;
    }
}

class WindowRegion : Region {
    Nullable!Point  coordinates;
    Nullable!size_t addressOne;
    Nullable!size_t addressTwo;

    this(Point origin, Point end) {
        super(origin, end);
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

        painter.fillColor    = Color.white;
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

class BitmapRegion : Region {
    size_t  capacity;
    ubyte[] bitmap;
    Point   markOne;
    Point   markTwo;
    bool    selecting;

    this(Point origin, Point end, ubyte[] data) {
        super(origin, end);

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

        foreach (i,b ; bitmap[].enumerate) {
            x += 1;
            if (x >= end.x) {
                x = origin.x;
                y += 1;
            }

            if (b == 0)
                continue;

            if (selecting && (y < min(markOne.y, markTwo.y) ||
                              y > max(markOne.y, markTwo.y)))
            {
                painter.fillColor    = Color.gray;
                painter.outlineColor = Color.gray;
            }
            else {
                painter.fillColor    = Color.green;
                painter.outlineColor = Color.green;
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

class HexdumpRegion : Region {
    size_t address;
    ubyte[] data;

    this(Point origin, Point end, ref ubyte[] data) {
        super(origin, end);
        this.data = data;
        hasChanged = true;
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

    void setAddress(size_t address) {
        this.address = address;
        hasChanged = true;
    }

    override
    void redraw(ScreenPainter painter) {
        if (!hasChanged)
            return;

        hasChanged = false;

        painter.fillColor    = Color.black;
        painter.outlineColor = Color.black;
        painter.drawRectangle(origin, end);

        painter.outlineColor = Color.white;

        painter.drawText(Point(origin.x + 5, origin.y + 5), hexdump(address));
    }
}

void redraw(SimpleWindow window, Region[] regions) {
    auto painter = window.draw();

    foreach (region ; regions)
        region.redraw(painter);
}

void rescale(ref WeighedMap weighedMap) {
    ubyte maxweight;
    foreach (x ; 0 .. 256) {
        foreach (y ; 0 .. 256) {
            if (weighedMap[x][y].weight != 0 && weighedMap[x][y].weight < 10)
                weighedMap[x][y].weight = 10;
            if (weighedMap[x][y].weight > maxweight)
                maxweight = weighedMap[x][y].weight;
        }
    }

    if (maxweight == 255)
        return;

    ulong ratio = 255 / maxweight;

    foreach (x ; 0 .. 256) {
        foreach (y ; 0 .. 256) {
            weighedMap[x][y].weight *= weighedMap[x][y].weight;
        }
    }
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
    if (data.length > 1024*1024)
        data = data.randomSample(1024*1024).array;

    WeighedMap weighedMap;

    // Populate weighedMap
    foreach (index, coordinates ; data.slide(2).enumerate()) {
        ubyte x = coordinates[0];
        ubyte y = 255 - coordinates[1];

        weighedMap[x][y].increase(cast(ubyte) (index * 256 / data.length));
        weighedMap[x][y].address = index;
    }

    weighedMap.rescale();

    auto windowRegion = new WindowRegion(
                                Point(0, 0),
                                Point(window.width, window.height)
                            );

    auto wmRegion = new WeighedMapRegion(
                                Point(20, 0),
                                Point(256*pxsize + 20, 256*pxsize),
                                weighedMap
                            );

    // Padd small files
    auto bitmapOrigin = Point(wmRegion.end.x, 0);
    auto bitmapEnd    = Point(wmRegion.end.x + 256, 256*pxsize);
    auto bitmapCapacity = (bitmapEnd.x - bitmapOrigin.x)
                        * (bitmapEnd.y - bitmapOrigin.y) / 8;

    if (data.length < bitmapCapacity) {
        data ~= repeat(0).take(bitmapCapacity - data.length)
                         .map!(to!ubyte)
                         .array;
    }

    auto bitmapRegion = new BitmapRegion(bitmapOrigin, bitmapEnd, data);

    auto hexdumpRegion = new HexdumpRegion(
                                Point(bitmapRegion.end.x, 0),
                                Point(bitmapRegion.end.x + 280, window.height),
                                data
                            );

    Region[] regionsToBeDrawn = [
        wmRegion,
        windowRegion,
        bitmapRegion,
        hexdumpRegion,
    ];

    bool isSelecting;
    size_t addressOne, addressTwo;

    window.redraw(regionsToBeDrawn);
    window.eventLoop(20,
        delegate () {
            window.redraw(regionsToBeDrawn);
        },
        delegate (MouseEvent event) {
            // Mouse in weighedmap panel
            if (Point(event.x, event.y).inRegion(wmRegion)) {
                wmRegion.setCross(Point(event.x, event.y));
                windowRegion.setCoordinateText(Point(event.x, event.y));
            }
            else {
                wmRegion.removeCross();
                windowRegion.removeCoordinateText();
            }

            // Mouse in bitmap panel
            if (Point(event.x, event.y).inRegion(bitmapRegion)) {
                hexdumpRegion.setAddress(event.y * data.length
                              / (bitmapRegion.end.y - bitmapRegion.origin.y));

                if (!isSelecting) {
                    bitmapRegion.setMarkOne(Point(event.x, event.y));

                    addressOne = event.y * data.length
                              / (bitmapRegion.end.y - bitmapRegion.origin.y);

                    if (!bitmapRegion.selecting) {
                        windowRegion.setAddressTextOne(addressOne);
                    }
                }

                if (event.type == MouseEventType.motion &&
                        event.modifierState & ModifierState.leftButtonDown) {
                    isSelecting = true;

                    bitmapRegion.setMarkTwo(Point(event.x, event.y));
                    addressTwo = event.y * data.length
                          / (bitmapRegion.end.y - bitmapRegion.origin.y);
                    windowRegion.setAddressTextTwo(addressTwo);

                    wmRegion.setDisplayRange(addressOne, addressTwo);
                }
            }

            // Stop address range selection
            if (isSelecting && event.type == MouseEventType.buttonPressed) {
                isSelecting = false;
                bitmapRegion.removeMarkTwo();
                windowRegion.removeAddressTextTwo();

                wmRegion.removeDisplayRange();
            }
        },
    );

    return 0;
}
