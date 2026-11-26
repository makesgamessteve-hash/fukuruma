// Runs inside the Emscripten module before main: mounts the IndexedDB-backed folder SDL uses for
// stored values (SDL_GetPrefPath is /libsdl/... in the browser) and loads it before the game starts.
Module['preRun'] = Module['preRun'] || [];
Module['preRun'].push(function () {
  FS.mkdir('/libsdl');
  FS.mount(IDBFS, {}, '/libsdl');
  addRunDependency('fk-storage');
  FS.syncfs(true, function (err) {
    if (err) console.warn('stored settings could not be loaded', err);
    removeRunDependency('fk-storage');
  });
});
