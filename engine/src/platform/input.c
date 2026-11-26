#include <SDL3/SDL.h>
#include <math.h>

#include "platform/platform.h"

#define SYNTH_WINDOW_NS 500000000ull /* mouse events this soon after a touch come from the touch */

static struct {
    bool keys[SDL_SCANCODE_COUNT];
    unsigned mouse_buttons;
    float mx, my, mdx, mdy;
    float axes[SDL_GAMEPAD_AXIS_COUNT];
    bool buttons[SDL_GAMEPAD_BUTTON_COUNT];
    fk_touch touches[FK_MAX_TOUCHES];
    int ntouches;
    const char *device;
    uint64_t last_touch_ns;
} in = {.device = "keyboard"};

void fk_input_reset(void) {
    SDL_zero(in);
    in.device = "keyboard";
}

static void window_size(SDL_WindowID id, float *w, float *h) {
    int iw = 0, ih = 0;
    SDL_Window *window = SDL_GetWindowFromID(id);
    if (window) SDL_GetWindowSize(window, &iw, &ih);
    *w = iw > 0 ? (float)iw : 1.0f;
    *h = ih > 0 ? (float)ih : 1.0f;
}

static void mouse_used(SDL_MouseID which) {
    bool synthetic = which == SDL_TOUCH_MOUSEID || (in.last_touch_ns && SDL_GetTicksNS() - in.last_touch_ns < SYNTH_WINDOW_NS);
    if (!synthetic) in.device = "mouse";
}

static int find_touch(int64_t id) {
    for (int i = 0; i < in.ntouches; i++)
        if (in.touches[i].id == id) return i;
    return -1;
}

void fk_input_event(const void *sdl_event) {
    const SDL_Event *e = sdl_event;
    float w, h;
    int t;
    switch (e->type) {
    case SDL_EVENT_KEY_DOWN:
    case SDL_EVENT_KEY_UP:
        if (e->key.scancode < SDL_SCANCODE_COUNT) in.keys[e->key.scancode] = e->type == SDL_EVENT_KEY_DOWN;
        in.device = "keyboard";
        break;
    case SDL_EVENT_MOUSE_MOTION:
        window_size(e->motion.windowID, &w, &h);
        in.mx = e->motion.x / w;
        in.my = e->motion.y / h;
        in.mdx += e->motion.xrel / w;
        in.mdy += e->motion.yrel / h;
        mouse_used(e->motion.which);
        break;
    case SDL_EVENT_MOUSE_BUTTON_DOWN:
    case SDL_EVENT_MOUSE_BUTTON_UP:
        if (e->type == SDL_EVENT_MOUSE_BUTTON_DOWN) in.mouse_buttons |= 1u << e->button.button;
        else in.mouse_buttons &= ~(1u << e->button.button);
        mouse_used(e->button.which);
        break;
    case SDL_EVENT_GAMEPAD_ADDED:
        SDL_OpenGamepad(e->gdevice.which);
        break;
    case SDL_EVENT_GAMEPAD_REMOVED: /* forget its last state so nothing stays pushed */
        SDL_zeroa(in.axes);
        SDL_zeroa(in.buttons);
        break;
    case SDL_EVENT_GAMEPAD_AXIS_MOTION:
        if (e->gaxis.axis < SDL_GAMEPAD_AXIS_COUNT) {
            float v = SDL_max(-1.0f, e->gaxis.value / 32767.0f);
            in.axes[e->gaxis.axis] = v;
            if (fabsf(v) > 0.5f) in.device = "gamepad"; /* stick drift does not switch devices */
        }
        break;
    case SDL_EVENT_GAMEPAD_BUTTON_DOWN:
    case SDL_EVENT_GAMEPAD_BUTTON_UP:
        if (e->gbutton.button < SDL_GAMEPAD_BUTTON_COUNT) in.buttons[e->gbutton.button] = e->gbutton.down;
        in.device = "gamepad";
        break;
    case SDL_EVENT_FINGER_DOWN:
    case SDL_EVENT_FINGER_MOTION:
        t = find_touch((int64_t)e->tfinger.fingerID);
        if (t < 0 && in.ntouches < FK_MAX_TOUCHES) t = in.ntouches++;
        if (t >= 0) in.touches[t] = (fk_touch){(int64_t)e->tfinger.fingerID, e->tfinger.x, e->tfinger.y};
        in.device = "touch";
        in.last_touch_ns = SDL_GetTicksNS();
        break;
    case SDL_EVENT_FINGER_UP:
    case SDL_EVENT_FINGER_CANCELED:
        t = find_touch((int64_t)e->tfinger.fingerID);
        if (t >= 0) in.touches[t] = in.touches[--in.ntouches];
        in.last_touch_ns = SDL_GetTicksNS();
        break;
    default:
        break;
    }
}

void fk_input_frame_end(void) { in.mdx = in.mdy = 0; }

int fk_input_key_code(const char *name) {
    SDL_Scancode code = SDL_GetScancodeFromName(name);
    return code == SDL_SCANCODE_UNKNOWN ? -1 : (int)code;
}

int fk_input_axis_code(const char *name) { return (int)SDL_GetGamepadAxisFromString(name); }
int fk_input_button_code(const char *name) { return (int)SDL_GetGamepadButtonFromString(name); }
bool fk_input_key(int code) { return in.keys[code]; }
bool fk_input_mouse_button(int button) { return button >= 1 && button <= 8 && (in.mouse_buttons & (1u << button)); }
float fk_input_axis(int code) { return in.axes[code]; }
bool fk_input_button(int code) { return in.buttons[code]; }
const char *fk_input_device(void) { return in.device; }

void fk_input_mouse(float *x, float *y, float *dx, float *dy) {
    *x = in.mx;
    *y = in.my;
    *dx = in.mdx;
    *dy = in.mdy;
}

int fk_input_touches(fk_touch out[FK_MAX_TOUCHES]) {
    SDL_memcpy(out, in.touches, sizeof in.touches);
    return in.ntouches;
}

void fk_input_emulate_key(int code, bool down) {
    SDL_Event e = {.type = down ? SDL_EVENT_KEY_DOWN : SDL_EVENT_KEY_UP};
    e.key.scancode = (SDL_Scancode)code;
    e.key.down = down;
    fk_input_event(&e);
}

void fk_input_emulate_mouse_button(int button, bool down) {
    SDL_Event e = {.type = down ? SDL_EVENT_MOUSE_BUTTON_DOWN : SDL_EVENT_MOUSE_BUTTON_UP};
    e.button.button = (Uint8)button;
    e.button.down = down;
    fk_input_event(&e);
}

void fk_input_emulate_axis(int code, float value) {
    SDL_Event e = {.type = SDL_EVENT_GAMEPAD_AXIS_MOTION};
    e.gaxis.axis = (Uint8)code;
    e.gaxis.value = (Sint16)(SDL_clamp(value, -1.0f, 1.0f) * 32767.0f);
    fk_input_event(&e);
}

void fk_input_emulate_button(int code, bool down) {
    SDL_Event e = {.type = down ? SDL_EVENT_GAMEPAD_BUTTON_DOWN : SDL_EVENT_GAMEPAD_BUTTON_UP};
    e.gbutton.button = (Uint8)code;
    e.gbutton.down = down;
    fk_input_event(&e);
}

void fk_input_emulate_touch(int64_t id, bool down, float x, float y) {
    SDL_Event e = {.type = !down ? SDL_EVENT_FINGER_UP : find_touch(id) < 0 ? SDL_EVENT_FINGER_DOWN : SDL_EVENT_FINGER_MOTION};
    e.tfinger.fingerID = (SDL_FingerID)id;
    e.tfinger.x = x;
    e.tfinger.y = y;
    fk_input_event(&e);
}
