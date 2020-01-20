module lookout.weighedMapRegion;

import std.algorithm;
import std.typecons;

import arsd.simpledisplay;

import lookout.globalState;
import lookout.region;
import lookout.weighedMap;

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

    this(Point origin, Point end, WeighedMap wmap, size_t dataLength) {
        super(origin, end);
        this.weighedMap = wmap;
        this.dataLength = dataLength;
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

    override
    void redraw(ScreenPainter painter) {
        if (!hasChanged)
            return;

        hasChanged = false;

        if (displayRange.length == 0)
            return;

        painter.fillColor    = Color.black;
        painter.outlineColor = Color.black;
        painter.drawRectangle(origin, end);

        void drawPixel(int x, int y, ubyte weight, ubyte position) {
            Color pixelColor = Color.fromIntegers(
                                           position*weight/64,
                                           weight,
                                           (256-position)*weight/64,
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
                if (weighedMap[x][y].weight == 0)
                    continue;

                if (hasPositionCache) {
                    if (positionCache[x][y].isInRange) {
                        drawPixel(x, y,
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

                drawPixel(x, y, weighedMap[x][y].weight, position);
            }
        }

        // Now we have a cache
        hasPositionCache = true;

        if (cross.isNull)
            return;

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
