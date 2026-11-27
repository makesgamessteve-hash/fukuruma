// WebXR (webxr spec): an ENTER VR button where the browser offers immersive VR. The session drives the game's frames
// (the requestAnimationFrame the main loop asks for is the session's), reports each frame's head pose and the distance
// between the eyes to the engine (fk_web_xr: stereo, and the head turns the view), and the game's window drawing goes
// to the headset's framebuffer. The session's end restores the page.
// shortcut: the picture is drawn at the canvas's size, not the headset's own resolution, and each eye uses the game's
// projection, not the headset's; use the views' viewports and projections with the VR resolution preset (M7 tuning).
(function () {
  if (typeof navigator === 'undefined' || !navigator.xr) return;
  function setup() {
    const button = document.createElement('button');
    button.id = 'enter-vr';
    button.textContent = 'ENTER VR';
    button.hidden = true;
    button.style.cssText = 'position:fixed;right:1em;bottom:1em;padding:.6em 1.2em;font:bold 16px system-ui;' +
      'background:#f0a040;color:#05060f;border:0;border-radius:.4em;cursor:pointer;z-index:10';
    document.body.appendChild(button);
    navigator.xr.isSessionSupported('immersive-vr').then((ok) => { button.hidden = !ok; }, () => {});
    button.addEventListener('click', async () => {
      const gl = Module.canvas.getContext('webgl2');
      const session = await navigator.xr.requestSession('immersive-vr', { optionalFeatures: ['local-floor'] });
      if (gl.makeXRCompatible) await gl.makeXRCompatible();
      const layer = new XRWebGLLayer(session, gl);
      session.updateRenderState({ baseLayer: layer });
      const space = await session.requestReferenceSpace('local');
      const raf = window.requestAnimationFrame, bind = gl.bindFramebuffer.bind(gl);
      gl.bindFramebuffer = (target, fb) => bind(target, fb === null ? layer.framebuffer : fb); // the window: the headset
      window.requestAnimationFrame = (callback) => session.requestAnimationFrame((time, frame) => {
        const pose = frame.getViewerPose(space);
        if (pose) {
          const o = pose.transform.orientation, v = pose.views;
          let ipd = 0.064;
          if (v.length === 2) {
            const a = v[0].transform.position, b = v[1].transform.position;
            ipd = Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z) || ipd;
          }
          Module._fk_web_xr(1, ipd, o.x, o.y, o.z, o.w);
        }
        let lx = 0, ly = 0, rx = 0, ry = 0, buttons = 0; // the controllers (xr-standard mapping), as a gamepad
        const pressed = (pad, i) => pad.buttons[i] && pad.buttons[i].pressed;
        for (const source of session.inputSources || []) {
          const pad = source.gamepad;
          if (!pad) continue;
          if (source.handedness === 'left') {
            lx = pad.axes[2] || 0, ly = pad.axes[3] || 0;
            buttons |= (pressed(pad, 0) ? 4 : 0) | (pressed(pad, 4) ? 8 : 0) | (pressed(pad, 5) ? 32 : 0);
          } else {
            rx = pad.axes[2] || 0, ry = pad.axes[3] || 0;
            buttons |= (pressed(pad, 0) ? 1 : 0) | (pressed(pad, 4) ? 2 : 0) | (pressed(pad, 5) ? 16 : 0);
          }
        }
        Module._fk_web_xr_pad(lx, ly, rx, ry, buttons);
        callback(time);
      });
      window.fukurumaXRPulse = (strength, ms) => { // rumble: the controllers' haptics
        for (const source of session.inputSources || []) {
          const motor = source.gamepad && source.gamepad.hapticActuators && source.gamepad.hapticActuators[0];
          if (motor && motor.pulse) motor.pulse(Math.min(1, strength), ms);
        }
      };
      document.body.dataset.xr = 'on';
      button.hidden = true;
      session.addEventListener('end', () => {
        window.requestAnimationFrame = raf;
        gl.bindFramebuffer = bind;
        Module._fk_web_xr(0, 0, 0, 0, 0, 1);
        Module._fk_web_xr_pad(0, 0, 0, 0, 0);
        window.fukurumaXRPulse = undefined;
        document.body.dataset.xr = 'off';
        button.hidden = false;
      });
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', setup);
  else setup();
})();
