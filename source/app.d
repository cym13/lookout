module lookout.app;

import std;
import arsd.simpledisplay;

auto pxsize = 3;


struct WeighedPixel {
    ubyte weight;
    ubyte position;

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

class Region {
    Point origin;
    Point end;

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

    this(Point origin, Point end, WeighedMap wmap) {
        super(origin, end);
        this.weighedMap = wmap;
    }

    override
    void redraw(ScreenPainter painter) {
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
                    drawPixel(x, y, weighedMap[x][y]);
            }
        }

        if (cross.isNull)
            return;

        painter.fillColor    = Color.red;
        painter.outlineColor = Color.red;
        painter.drawLine(Point(cross.get.x, origin.y),
                         Point(cross.get.x, end.y));
        painter.drawLine(Point(origin.x, cross.get.y),
                         Point(end.x, cross.get.y));

    }

    void setCross(Point p) {
        cross = nullable(p);
    }

    void removeCross() {
        cross = Nullable!Point.init;
    }
}

class WindowRegion : Region {
    Nullable!Point coordinates;

    this(Point origin, Point end) {
        super(origin, end);
    }

    void setCoordinateText(Point p) {
        coordinates = p;
    }

    void removeCoordinateText() {
        coordinates = Nullable!Point.init;
    }

    override
    void redraw(ScreenPainter painter) {
        if (!coordinates.isNull) {
            painter.outlineColor = Color.white;


            painter.drawText(Point(origin.x+2, coordinates.get.y-5),
                             format("%02X", 255-(coordinates.get.y / pxsize)));
            painter.drawText(Point(coordinates.get.x-5, end.y-20+2),
                             format("%02X", (coordinates.get.x-20) / pxsize));
        }
    }
}

class BitmapRegion : Region {
    size_t capacity;
    ubyte[] bitmap;

    this(Point origin, Point end, ubyte[] data) {
        super(origin, end);

        this.capacity = (end.x - origin.x) * (end.y - origin.y) / 8;

        if (data.length < this.capacity)
            data ~= repeat(0).take(this.capacity - data.length)
                             .map!(to!ubyte)
                             .array;

        ubyte[] bitsOf(ubyte x) {
            ubyte[] result;

            foreach (i ; 1 .. 9)
                result ~= (x >> (8-i)) % 2;

            return result;
        }

        data.randomSample(capacity)
            .map!(x => bitsOf(x))
            .each!writeln;

        this.bitmap = data.randomSample(capacity)
                          .map!(x => bitsOf(x))
                          .join
                          .array;
    }

    override
    void redraw(ScreenPainter painter) {
        painter.fillColor = Color.green;
        painter.outlineColor = Color.green;

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

            painter.drawRectangle(Point(x, y),
                                  Point(x + 1, y));
        }
    }
}

void redraw(SimpleWindow window, Region[] regions) {
    auto painter = window.draw();
    painter.clear();

    painter.fillColor    = Color.black;
    painter.outlineColor = Color.black;
    painter.drawRectangle(Point(0, 0), Point(window.width, window.height));

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

    auto window = new SimpleWindow(256*pxsize + 20 + 256,
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
    }

    weighedMap.rescale();

    auto windowRegion = new WindowRegion(
                                Point(0, 0),
                                Point(window.width, window.height));

    auto wmRegion = new WeighedMapRegion(Point(20, 0),
                                         Point(256*pxsize + 20, 256*pxsize),
                                         weighedMap);

    auto bitmapRegion = new BitmapRegion(
                                Point(256*pxsize + 20, 0),
                                Point(256*(pxsize+1) + 20, 256*pxsize),
                                data
                            );


    Region[] regionsToBeDrawn = [
        wmRegion,
        windowRegion,
        bitmapRegion,
    ];

    bool hasChanged;

    window.redraw(regionsToBeDrawn);
    window.eventLoop(20,
        delegate () {
            if (hasChanged) {
                hasChanged = false;
                window.redraw(regionsToBeDrawn);
            }
        },
        delegate (MouseEvent event) {
            if (Point(event.x, event.y).inRegion(wmRegion)) {
                wmRegion.setCross(Point(event.x, event.y));
                windowRegion.setCoordinateText(Point(event.x, event.y));
            }
            else {
                wmRegion.removeCross();
                windowRegion.removeCoordinateText();
            }

            hasChanged = true;
        },
    );

    return 0;
}
