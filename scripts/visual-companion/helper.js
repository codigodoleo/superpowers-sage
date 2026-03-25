(() => {
  const statusEl = document.getElementById("vc-status");
  const infoEl = document.getElementById("vc-info");

  async function sendEvent(payload) {
    try {
      const res = await fetch("/event", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      if (statusEl) statusEl.textContent = "Event saved";
    } catch (err) {
      if (statusEl) statusEl.textContent = `Event error: ${err.message}`;
    }
  }

  document.addEventListener("click", (ev) => {
    const target = ev.target.closest("[data-choice]");
    if (!target) return;

    const payload = {
      type: "choice",
      section: target.getAttribute("data-section") || "unknown",
      choice: target.getAttribute("data-choice") || target.textContent.trim(),
      source: "browser",
      text: target.textContent.trim(),
      timestamp: new Date().toISOString(),
    };

    sendEvent(payload);

    document.querySelectorAll("[data-choice].selected").forEach((el) => {
      el.classList.remove("selected");
    });
    target.classList.add("selected");
    if (infoEl)
      infoEl.textContent = `Selected: ${payload.choice} (${payload.section})`;
  });
})();
