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

