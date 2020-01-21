module lookout.eventManager;

import std.variant;

import arsd.simpledisplay;

class EventManager {
    private static EventManager instance;

    static EventManager get() {
        if (instance is null)
            instance = new EventManager();
        return instance;
    }

    Callback[] callbacks;

    private this() {}

    void register(Callback cb) {
        callbacks ~= cb;
    }

    void notify(Event ev) {
        import std.stdio;
        writeln(ev);
        foreach (cb ; callbacks)
            cb(ev);
    }
}

alias Callback = void delegate(Event);

enum LookoutEvent {
    NOTHING,

    MOUSE_MOTION,
    MOUSE_LB_PRESSED,
    MOUSE_LB_RELEASED,
    MOUSE_LB_MOTION,

    BM_CHANGE_CURSOR,
}

struct Event {
    LookoutEvent type;
    Variant      data;

    static Event get(T)(LookoutEvent type, T data) {
        Event result;
        result.type = type;
        result.data = data;
        return result;
    }
}
