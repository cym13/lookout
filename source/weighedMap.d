module lookout.weighedMap;

struct WeighedPixel {
    ubyte  weight;
    ubyte  position;
    size_t[] addresses;

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

