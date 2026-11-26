/* Entry point: SDL drives the loop on every platform (including the browser) through its main callbacks. */
#define SDL_MAIN_USE_CALLBACKS 1
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <stdlib.h>

#include "app/app.h"
#include "platform/platform.h"

static SDL_AppResult result(fk_status s) {
    return s == FK_RUNNING ? SDL_APP_CONTINUE : s == FK_DONE ? SDL_APP_SUCCESS : SDL_APP_FAILURE;
}

SDL_AppResult SDL_AppInit(void **state, int argc, char **argv) {
    (void)state;
    return result(fk_app_init(argc, argv, SDL_GetBasePath()));
}

SDL_AppResult SDL_AppIterate(void *state) {
    (void)state;
    return result(fk_app_iterate());
}

SDL_AppResult SDL_AppEvent(void *state, SDL_Event *event) {
    (void)state;
    fk_input_event(event);
    return event->type == SDL_EVENT_QUIT ? SDL_APP_SUCCESS : SDL_APP_CONTINUE;
}

void SDL_AppQuit(void *state, SDL_AppResult r) {
    (void)state;
    (void)r;
    int code = fk_app_quit();
#ifdef __EMSCRIPTEN__
    (void)code;
#else
    if (code > 1) { /* SDL only knows success (0) and failure (1); timeouts exit with 2. */
        SDL_Quit();
        exit(code);
    }
#endif
}
