// Chaos is landscape (1280x720). iPhone in-app browsers (Messenger, Instagram) and a phone with
// rotation lock never turn the page, so a portrait phone would get a tiny letterboxed strip.
// This turns the game sideways in portrait: the canvas is drawn rotated 90 degrees to fill the
// screen, Godot is told the window is landscape, and every touch/click is mapped back.
// Source of the copy inlined in export_presets.cfg (Web -> html/head_include); keep them equal
// (tests/run_tests.gd checks). Why (Nov 26, 2026): DuffQuest's "turn sideways" note didn't help
// testers stuck in Messenger's browser.
(function () {
  var realW = Object.getOwnPropertyDescriptor(Window.prototype, "innerWidth") || null;
  var realH = Object.getOwnPropertyDescriptor(Window.prototype, "innerHeight") || null;
  function rw() { return realW ? realW.get.call(window) : document.documentElement.clientWidth; }
  function rh() { return realH ? realH.get.call(window) : document.documentElement.clientHeight; }
  function sideways() { return rh() > rw(); }
  // Godot sizes its canvas from innerWidth/innerHeight (canvas_resize_policy 2): swap them.
  try {
    Object.defineProperty(window, "innerWidth", { configurable: true, get: function () { return sideways() ? rh() : rw(); } });
    Object.defineProperty(window, "innerHeight", { configurable: true, get: function () { return sideways() ? rw() : rh(); } });
  } catch (e) {}
  function canvas() { return document.getElementById("canvas"); }
  function place() {
    var c = canvas();
    if (!c) return;
    if (sideways()) {
      c.style.position = "fixed";
      c.style.left = "0px";
      c.style.top = "0px";
      c.style.transformOrigin = "0 0";
      c.style.transform = "translateX(" + rw() + "px) rotate(90deg)";
    } else {
      c.style.transform = "";
    }
  }
  // Godot maps a touch with canvas.getBoundingClientRect() and clientX/Y; hand it the unrotated box.
  function patchRect() {
    var c = canvas();
    if (!c || c.__chaosRect) return;
    var orig = c.getBoundingClientRect.bind(c);
    c.getBoundingClientRect = function () {
      if (!sideways()) return orig();
      var w = rh(), h = rw();
      return { x: 0, y: 0, left: 0, top: 0, right: w, bottom: h, width: w, height: h };
    };
    c.__chaosRect = true;
  }
  // Screen point (sx, sy) -> unrotated canvas point: u = sy, v = screenWidth - sx.
  function fix(o) {
    var sx = o.clientX, sy = o.clientY;
    try {
      Object.defineProperty(o, "clientX", { configurable: true, value: sy });
      Object.defineProperty(o, "clientY", { configurable: true, value: rw() - sx });
    } catch (e) {}
  }
  function onPointer(ev) {
    if (!sideways() || ev.__chaosFixed) return;
    ev.__chaosFixed = true;
    if (ev.changedTouches) {
      var seen = [];
      [ev.touches, ev.changedTouches, ev.targetTouches].forEach(function (list) {
        if (!list) return;
        for (var i = 0; i < list.length; i++) {
          var t = list[i];
          if (seen.indexOf(t) < 0 && !t.__chaosFixed) { seen.push(t); fix(t); t.__chaosFixed = true; }
        }
      });
    } else if (typeof ev.clientX === "number") {
      fix(ev);
    }
  }
  ["touchstart", "touchmove", "touchend", "touchcancel", "mousedown", "mousemove", "mouseup"].forEach(function (n) {
    window.addEventListener(n, onPointer, { capture: true, passive: true });
  });
  function tick() { patchRect(); place(); }
  window.addEventListener("resize", tick, true);
  window.addEventListener("orientationchange", tick, true);
  document.addEventListener("DOMContentLoaded", tick);
  setInterval(tick, 500);
})();
