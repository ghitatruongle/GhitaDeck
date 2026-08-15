/// JavaScript command strings sent to the deck WebView2 by [PresentScreen]
/// and [PresenterViewScreen] (Track 35). Kept as pure functions so the exact
/// commands are unit-testable without a WebView2 runtime.
class PresentDeckCommands {
  PresentDeckCommands._();

  // ---- Navigation ----------------------------------------------------------

  static String goToSlide(int index) => 'goToSlide($index);';

  static String changeSlide(int delta) => 'changeSlide($delta);';

  static String nextSlide() => 'changeSlide(1);';

  static String prevSlide() => 'changeSlide(-1);';

  static String getCurrentSlide() => 'currentSlide;';

  /// Read the deck's current slide index synchronously via executeScript.
  static String getCurrentSlideExpr() => 'currentSlide';

  // ---- Ink / laser overlay (Track 35, P5) ----------------------------------

  /// One-time script that installs a canvas ink overlay on the deck and
  /// exposes `window.ghitaInk` (setTool/setColor/clear). Pointer events are
  /// captured on the deck so strokes overlay the slide exactly. Laser mode
  /// draws a trailing dot at the pointer instead of accumulating ink.
  ///
  /// [color] is a CSS hex like `#ED1C24`; [width] the pen width in px.
  static String installInkOverlay(String color, double width) {
    final safeColor = color.replaceAll(RegExp(r'[^#0-9a-fA-F]'), '');
    final w = width.toString();
    return r'''
(function () {
  if (window.ghitaInkInstalled) return;
  window.ghitaInkInstalled = true;
  const canvas = document.createElement("canvas");
  canvas.id = "ghita-ink";
  canvas.style.cssText = "position:fixed;inset:0;z-index:99990;pointer-events:none;";
  document.body.appendChild(canvas);
  const ctx = canvas.getContext("2d");
  function resize() { canvas.width = innerWidth; canvas.height = innerHeight; }
  resize(); addEventListener("resize", resize);
  let tool = "none", penColor = "''' + safeColor + r'''", penWidth = ''' + w + r''';
  let drawing = false, lastX = 0, lastY = 0, laserX = 0, laserY = 0;
  function pos(e) {
    const r = canvas.getBoundingClientRect();
    return [e.clientX - r.left, e.clientY - r.top];
  }
  window.ghitaInk = {
    setTool(t) { tool = t; if (t !== "laser") ctx.clearRect(0, 0, canvas.width, canvas.height); },
    setColor(c) { penColor = c; },
    setWidth(w2) { penWidth = w2; },
    clear() { ctx.clearRect(0, 0, canvas.width, canvas.height); }
  };
  addEventListener("pointerdown", (e) => {
    if (tool === "pen" || tool === "highlighter") {
      drawing = true; [lastX, lastY] = pos(e);
      ctx.lineWidth = tool === "highlighter" ? Math.max(12, penWidth * 4) : penWidth;
      ctx.lineCap = "round"; ctx.strokeStyle = penColor;
      if (tool === "highlighter") ctx.globalAlpha = 0.35; else ctx.globalAlpha = 1;
      ctx.beginPath(); ctx.moveTo(lastX, lastY);
    }
  });
  addEventListener("pointermove", (e) => {
    const [x, y] = pos(e);
    if (drawing) { ctx.lineTo(x, y); ctx.stroke(); }
    if (tool === "laser") {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.beginPath(); ctx.arc(x, y, 8, 0, Math.PI * 2);
      ctx.fillStyle = penColor; ctx.fill();
    }
  });
  addEventListener("pointerup", () => { drawing = false; ctx.globalAlpha = 1; });
  addEventListener("pointerleave", () => { drawing = false; ctx.globalAlpha = 1; });
})();
''';
  }

  /// Activate a tool (none | pen | highlighter | laser) on the installed
  /// overlay.
  static String setInkTool(String tool) {
    final safe = switch (tool) {
      'pen' || 'highlighter' || 'laser' => tool,
      _ => 'none',
    };
    return 'if (window.ghitaInk) window.ghitaInk.setTool("$safe");';
  }

  static String setInkColor(String color) {
    final safe = color.replaceAll(RegExp(r'[^#0-9a-fA-F]'), '');
    return 'if (window.ghitaInk) window.ghitaInk.setColor("$safe");';
  }

  static String setInkWidth(double width) =>
      'if (window.ghitaInk) window.ghitaInk.setWidth($width);';

  static String clearInk() => 'if (window.ghitaInk) window.ghitaInk.clear();';

  // ---- Magnifier (Track 35, P6) ---------------------------------------------

  /// Zoom the deck wrapper. [factor] 1.0 resets (transform applied to #deck).
  static String setZoom(double factor) {
    final f = factor.clamp(1.0, 3.0).toString();
    return 'const d = document.getElementById("deck"); if (d) { '
        'd.style.transform = ${factor <= 1.0 ? '""' : '"scale($f)"'}; '
        'd.style.transformOrigin = "50% 50%"; }';
  }

  // ---- Black / white screen (Track 35, P7) ----------------------------------

  /// Cover the screen with [color] (e.g. `#000000` or `#FFFFFF`); empty
  /// removes the cover.
  static String setScreen(String color) {
    if (color.isEmpty) {
      return 'const o = document.getElementById("ghita-screen-ov");'
          ' if (o) o.remove();';
    }
    final safe = color.replaceAll(RegExp(r'[^#0-9a-fA-F]'), '');
    return 'let o = document.getElementById("ghita-screen-ov");'
        'if (!o) { o = document.createElement("div");'
        'o.id = "ghita-screen-ov"; o.style.cssText = '
        '"position:fixed;inset:0;z-index:99995;pointer-events:none;";'
        'document.body.appendChild(o); } o.style.background = "$safe";';
  }

  /// Install pro-presentation keyboard handling inside the deck itself
  /// (Track 35, P4/P7): G = grid navigator, B/W = black/white screen,
  /// P = pen, L = laser, M = magnifier, ? = help. Typing 1–9 then Enter jumps
  /// directly to that slide. Works even when the WebView2 owns keyboard focus.
  static String installProKeys() => r'''
(function () {
  if (window.ghitaProKeys) return;
  window.ghitaProKeys = true;
  let gNum = "";
  let gGrid = null;
  function closeGrid() { if (gGrid) { gGrid.remove(); gGrid = null; } }
  function showGrid() {
    closeGrid();
    gGrid = document.createElement("div");
    gGrid.style.cssText = "position:fixed;inset:0;z-index:99994;background:rgba(0,0,0,0.75);display:flex;flex-wrap:wrap;align-content:center;justify-content:center;gap:10px;padding:30px;";
    for (let i = 0; i < totalSlides; i++) {
      const t = document.createElement("button");
      t.textContent = (i + 1);
      t.style.cssText = "width:64px;height:42px;font-size:16px;font-weight:600;border-radius:8px;border:2px solid #3a8fd4;background:#1a2a4a;color:#fff;cursor:pointer;";
      t.onclick = (function (idx) { return function () { goToSlide(idx); closeGrid(); }; })(i);
      gGrid.appendChild(t);
    }
    document.body.appendChild(gGrid);
  }
  document.addEventListener("keydown", (e) => {
    if (e.target && e.target.tagName === "INPUT") return;
    const k = e.key;
    if (/^[0-9]$/.test(k)) { gNum += k; e.preventDefault(); return; }
    if (k === "Enter" && gNum) {
      const idx = parseInt(gNum, 10) - 1;
      if (idx >= 0 && idx < totalSlides) goToSlide(idx);
      gNum = ""; closeGrid(); e.preventDefault(); return;
    }
    if (k !== "Enter") gNum = "";
    if (k === "g" || k === "G") { showGrid(); e.preventDefault(); }
    else if (k === "Escape") { closeGrid(); }
    else if (k === "b" || k === "B") {
      const o = document.getElementById("ghita-screen-ov");
      if (o && o.style.background === "rgb(0, 0, 0)") o.remove();
      else { const s = document.createElement("div"); s.id = "ghita-screen-ov"; s.style.cssText = "position:fixed;inset:0;z-index:99995;background:#000;pointer-events:none;"; document.body.appendChild(s); }
      e.preventDefault();
    }
    else if (k === "w" || k === "W") {
      const o = document.getElementById("ghita-screen-ov");
      if (o && o.style.background === "rgb(255, 255, 255)") o.remove();
      else { const s = document.createElement("div"); s.id = "ghita-screen-ov"; s.style.cssText = "position:fixed;inset:0;z-index:99995;background:#fff;pointer-events:none;"; document.body.appendChild(s); }
      e.preventDefault();
    }
    else if (k === "p" || k === "P") { if (window.ghitaInk) window.ghitaInk.setTool("pen"); e.preventDefault(); }
    else if (k === "l" || k === "L") { if (window.ghitaInk) window.ghitaInk.setTool("laser"); e.preventDefault(); }
    else if (k === "m" || k === "M") { document.body.classList.toggle("ghita-mag"); e.preventDefault(); }
    else if (k === "?") { window.dispatchEvent(new CustomEvent("ghita-help")); }
  });
})();
''';

  /// Install the deck so the presenter view can read the active slide and be
  /// told which slide to show. `presenterGoTo(i)` uses the player's own
  /// goToSlide; `presenterCurrent()` returns the live index.
  static String installPresenterSync() => r'''
(function () {
  if (window.ghitaPresenterSync) return;
  window.ghitaPresenterSync = true;
  window.presenterGoTo = function (i) { goToSlide(i); };
  window.presenterCurrent = function () { return currentSlide; };
})();
''';

  static String presenterGoTo(int index) => 'presenterGoTo($index);';

  static String presenterCurrent() => 'presenterCurrent();';
}
