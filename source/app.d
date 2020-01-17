module lookout.app;

import std;
import arsd.simpledisplay;

auto pxsize = 3;


struct WeighedPixel {
    ubyte weight;
    ubyte position;

    void increase(ubyte new_position) {
        if (weight == 0)
            position = new_position;
        else
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
            if (weighedMap[x][y].weight > maxweight)
                maxweight = weighedMap[x][y].weight;
        }
    }

    if (maxweight == 255)
        return;

    ulong ratio = 256 / maxweight;

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

    auto window = new SimpleWindow(256*pxsize + 20, 256*pxsize + 20,
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

    Region[] regionsToBeDrawn = [
        wmRegion,
        windowRegion,
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
