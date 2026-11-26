#include <SDL3/SDL.h>

#include "platform/platform.h"
#include "utest.h"

UTEST(input, keys_and_device) {
    fk_input_reset();
    int d = fk_input_key_code("D");
    ASSERT_GE(d, 0);
    EXPECT_EQ(fk_input_key_code("NoSuchKey"), -1);
    fk_input_emulate_key(d, true);
    EXPECT_TRUE(fk_input_key(d));
    EXPECT_STREQ(fk_input_device(), "keyboard");
    fk_input_frame_end();
    fk_input_emulate_key(d, false);
    EXPECT_FALSE(fk_input_key(d));
}

/* A press and release between two frames still shows for one frame (fast taps on slow devices). */
UTEST(input, quick_presses_last_a_frame) {
    fk_input_reset();
    int d = fk_input_key_code("D"), a = fk_input_button_code("a");
    fk_touch t[FK_MAX_TOUCHES];
    fk_input_emulate_key(d, true);
    fk_input_emulate_key(d, false);
    fk_input_emulate_button(a, true);
    fk_input_emulate_button(a, false);
    fk_input_emulate_mouse_button(1, true);
    fk_input_emulate_mouse_button(1, false);
    fk_input_emulate_touch(7, true, 0.5f, 0.5f);
    fk_input_emulate_touch(7, false, 0, 0);
    EXPECT_TRUE(fk_input_key(d));
    EXPECT_TRUE(fk_input_button(a));
    EXPECT_TRUE(fk_input_mouse_button(1));
    EXPECT_EQ(fk_input_touches(t), 1);
    fk_input_frame_end();
    EXPECT_FALSE(fk_input_key(d));
    EXPECT_FALSE(fk_input_button(a));
    EXPECT_FALSE(fk_input_mouse_button(1));
    EXPECT_EQ(fk_input_touches(t), 0);
    /* pressed again before the frame end: it stays down */
    fk_input_emulate_key(d, true);
    fk_input_emulate_key(d, false);
    fk_input_emulate_key(d, true);
    fk_input_frame_end();
    EXPECT_TRUE(fk_input_key(d));
    fk_input_emulate_key(d, false);
    EXPECT_FALSE(fk_input_key(d));
    /* more quick presses than can wait: the rest are released at once */
    for (int i = 0; i < 40; i++) fk_input_emulate_key(100 + i, true);
    fk_input_emulate_key(d, true);
    fk_input_emulate_key(d, false);
    EXPECT_FALSE(fk_input_key(d));
    fk_input_frame_end();
}

UTEST(input, gamepad) {
    fk_input_reset();
    int x = fk_input_axis_code("leftx"), a = fk_input_button_code("a");
    ASSERT_GE(x, 0);
    ASSERT_GE(a, 0);
    EXPECT_EQ(fk_input_axis_code("wobble"), -1);
    fk_input_emulate_axis(x, 0.3f); /* small movement: no device switch */
    EXPECT_STREQ(fk_input_device(), "keyboard");
    fk_input_emulate_axis(x, -2.0f); /* clamped */
    EXPECT_NEAR(fk_input_axis(x), -1.0f, 1e-6);
    EXPECT_STREQ(fk_input_device(), "gamepad");
    fk_input_emulate_button(a, true);
    EXPECT_TRUE(fk_input_button(a));
    SDL_Event e = {.type = SDL_EVENT_GAMEPAD_REMOVED};
    fk_input_event(&e);
    EXPECT_FALSE(fk_input_button(a));
    EXPECT_EQ(fk_input_axis(x), 0.0f);
    e.type = SDL_EVENT_GAMEPAD_ADDED; /* an id that does not exist: opening fails quietly */
    e.gdevice.which = 12345;
    fk_input_event(&e);
}

UTEST(input, mouse) {
    fk_input_reset();
    SDL_Event e = {.type = SDL_EVENT_MOUSE_MOTION};
    e.motion.x = 0.25f; /* no window with this id: positions stay in pixels of a 1x1 window */
    e.motion.xrel = 0.5f;
    fk_input_event(&e);
    float x, y, dx, dy;
    fk_input_mouse(&x, &y, &dx, &dy);
    EXPECT_NEAR(x, 0.25f, 1e-6);
    EXPECT_NEAR(dx, 0.5f, 1e-6);
    EXPECT_STREQ(fk_input_device(), "mouse");
    fk_input_frame_end();
    fk_input_mouse(&x, &y, &dx, &dy);
    EXPECT_EQ(dx, 0.0f);
    fk_input_emulate_mouse_button(3, true);
    EXPECT_TRUE(fk_input_mouse_button(3));
    EXPECT_FALSE(fk_input_mouse_button(1));
    EXPECT_FALSE(fk_input_mouse_button(0));
    fk_input_frame_end();
    fk_input_emulate_mouse_button(3, false);
    EXPECT_FALSE(fk_input_mouse_button(3));
}

UTEST(input, touches) {
    fk_input_reset();
    fk_touch t[FK_MAX_TOUCHES];
    fk_input_emulate_touch(5, true, 0.25f, 0.75f);
    ASSERT_EQ(fk_input_touches(t), 1);
    EXPECT_EQ(t[0].id, 5);
    EXPECT_NEAR(t[0].y, 0.75f, 1e-6);
    EXPECT_STREQ(fk_input_device(), "touch");
    fk_input_emulate_touch(5, true, 0.5f, 0.5f); /* moves the same finger */
    ASSERT_EQ(fk_input_touches(t), 1);
    EXPECT_NEAR(t[0].x, 0.5f, 1e-6);
    /* Mouse events that the browser or SDL make from a touch keep the device on "touch". */
    SDL_Event e = {.type = SDL_EVENT_MOUSE_BUTTON_DOWN};
    e.button.which = SDL_TOUCH_MOUSEID;
    e.button.button = 1;
    fk_input_event(&e);
    e.button.which = 0; /* within 500 ms of a touch */
    fk_input_event(&e);
    EXPECT_STREQ(fk_input_device(), "touch");
    for (int i = 0; i < FK_MAX_TOUCHES + 2; i++) fk_input_emulate_touch(100 + i, true, 0.1f, 0.1f);
    EXPECT_EQ(fk_input_touches(t), FK_MAX_TOUCHES);
    fk_input_frame_end();
    fk_input_emulate_touch(5, false, 0, 0);
    EXPECT_EQ(fk_input_touches(t), FK_MAX_TOUCHES - 1);
    fk_input_emulate_touch(999, false, 0, 0); /* lifting an unknown finger is harmless */
    e.type = SDL_EVENT_WINDOW_SHOWN;          /* other events are ignored */
    fk_input_event(&e);
    EXPECT_EQ(fk_input_touches(t), FK_MAX_TOUCHES - 1);
}
