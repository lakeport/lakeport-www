let bootPromise = null;
let hydratedSession = null;
let pendingPressId = null;

function startHydration() {
  if (bootPromise) return bootPromise;
  cleanupTriggers();
  bootPromise = import("/runtime/boot.mjs")
    .then(mod => mod.mount({ hmr: false }))
    .then(session => {
      hydratedSession = session;
      if (session && pendingPressId !== null) {
        const id = pendingPressId;
        pendingPressId = null;
        try { session.press(id); } catch {}
      }
      return session;
    });
  return bootPromise;
}

function onPreHydrationClick(ev) {
  if (hydratedSession) return;
  const target = ev.target && typeof ev.target.closest === "function"
    ? ev.target.closest("button[data-node]")
    : null;
  if (!target) return;
  const rawId = target.getAttribute("data-node");
  if (rawId === null) return;
  const parsed = Number(rawId);
  if (!Number.isFinite(parsed)) return;
  ev.preventDefault();
  ev.stopPropagation();
  pendingPressId = parsed;
  startHydration();
}

const INTENT_EVENTS = ["pointerdown", "touchstart", "keydown", "focusin", "input"];

function cleanupTriggers() {
  for (const name of INTENT_EVENTS) {
    window.removeEventListener(name, startHydration, { capture: true });
  }
}

for (const name of INTENT_EVENTS) {
  window.addEventListener(name, startHydration, { capture: true, passive: true, once: true });
}
document.addEventListener("click", onPreHydrationClick, true);
