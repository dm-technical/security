"use strict";

let campaignId = null;
let busy = false;

const log = document.getElementById("log");
const input = document.getElementById("input");
const composer = document.getElementById("composer");
const sendBtn = document.getElementById("send");
const rollsEl = document.getElementById("rolls");
const sheetEl = document.getElementById("sheet");
const modal = document.getElementById("modal");
const modalBody = document.getElementById("modal-body");
const modalTitle = document.getElementById("modal-title");

// ---- rendering ---------------------------------------------------------
function addMessage(role, text) {
  const div = document.createElement("div");
  div.className = "msg " + role;
  div.textContent = text || "";
  log.appendChild(div);
  scrollDown();
  return div;
}

function scrollDown() { log.scrollTop = log.scrollHeight; }

function addRoll(ev) {
  // Chat transcript entry
  const dice = ev.rolls ? ev.rolls.join(" + ") : "";
  const mod = ev.modifier ? (ev.modifier > 0 ? " + " + ev.modifier : " - " + Math.abs(ev.modifier)) : "";
  const line = `🎲 ${ev.reason ? ev.reason + " — " : ""}${ev.notation}: [${dice}]${mod} = ${ev.total}`;
  addMessage("roll", line);

  // Sidebar dice log
  const li = document.createElement("li");
  let cls = "total";
  if (ev.sides === 20 && ev.rolls && ev.rolls.length === 1) {
    if (ev.rolls[0] === 20) cls = "crit";
    else if (ev.rolls[0] === 1) cls = "fumble";
  }
  li.innerHTML = `<span class="reason">${escapeHtml(ev.reason || ev.notation)}</span><br>` +
                 `${ev.notation} → <span class="${cls}">${ev.total}</span>`;
  rollsEl.prepend(li);
}

function escapeHtml(s) {
  const d = document.createElement("div");
  d.textContent = s == null ? "" : String(s);
  return d.innerHTML;
}

function renderSheet(sheet) {
  if (!sheet || !sheet.name) {
    sheetEl.innerHTML = '<div class="sheet-empty">No character yet. Begin a new campaign and the Dungeon Master will guide you through creation.</div>';
    return;
  }
  const hp = Number(sheet.hp ?? 0), maxhp = Number(sheet.max_hp ?? 1);
  const pct = Math.max(0, Math.min(100, (hp / Math.max(1, maxhp)) * 100));
  const stats = sheet.stats || {};
  const statHtml = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
    .filter(k => stats[k] != null)
    .map(k => `<div class="stat"><span class="k">${k}</span><span class="v">${stats[k]}</span></div>`)
    .join("");
  const inv = (sheet.inventory || []).map(i => `<span class="chip">${escapeHtml(i)}</span>`).join("");
  const conds = (sheet.conditions || []).map(c => `<span class="chip cond">${escapeHtml(c)}</span>`).join("");

  sheetEl.innerHTML = `
    <p class="sheet-name">${escapeHtml(sheet.name)}</p>
    <p class="sheet-sub">Level ${sheet.level ?? 1} ${escapeHtml(sheet.race || "")} ${escapeHtml(sheet.char_class || "")}</p>
    <div class="hp-label">HP ${hp} / ${maxhp}${sheet.ac != null ? " · AC " + sheet.ac : ""}${sheet.gold != null ? " · 🪙 " + sheet.gold : ""}</div>
    <div class="hpbar"><div style="width:${pct}%"></div></div>
    ${statHtml ? `<div class="stats">${statHtml}</div>` : ""}
    ${inv ? `<div class="row-label">Inventory</div><div class="chips">${inv}</div>` : ""}
    ${conds ? `<div class="row-label" style="margin-top:8px">Conditions</div><div class="chips">${conds}</div>` : ""}
    ${sheet.notes ? `<div class="row-label" style="margin-top:8px">Notes</div><div style="font-size:13px">${escapeHtml(sheet.notes)}</div>` : ""}
  `;
}

// ---- streaming ---------------------------------------------------------
async function send(message) {
  if (busy || !campaignId) return;
  busy = true;
  setEnabled(false);

  if (message) addMessage("player", message);

  let dmDiv = null;     // current streaming DM bubble
  const ensureDm = () => {
    if (!dmDiv) { dmDiv = addMessage("dm", ""); dmDiv.classList.add("cursor"); }
    return dmDiv;
  };

  try {
    const resp = await fetch("/api/send", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: campaignId, message }),
    });
    if (!resp.ok) {
      const err = await resp.json().catch(() => ({}));
      addMessage("system", "Error: " + (err.error || resp.statusText));
      return;
    }

    const reader = resp.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      let idx;
      while ((idx = buffer.indexOf("\n\n")) >= 0) {
        const chunk = buffer.slice(0, idx);
        buffer = buffer.slice(idx + 2);
        if (!chunk.startsWith("data:")) continue;
        const ev = JSON.parse(chunk.slice(5).trim());
        handleEvent(ev, ensureDm, () => { dmDiv = null; });
      }
    }
  } catch (e) {
    addMessage("system", "Connection error: " + e.message);
  } finally {
    if (dmDiv) dmDiv.classList.remove("cursor");
    busy = false;
    setEnabled(true);
    input.focus();
  }
}

function handleEvent(ev, ensureDm, resetDm) {
  if (ev.type === "text") {
    const d = ensureDm();
    d.textContent += ev.text;
    scrollDown();
  } else if (ev.type === "roll") {
    resetDm();           // close the current bubble so the roll sits inline
    addRoll(ev);
  } else if (ev.type === "sheet") {
    renderSheet(ev.sheet);
  } else if (ev.type === "error") {
    addMessage("system", "⚠ " + ev.text);
  } else if (ev.type === "done") {
    if (ev.sheet) renderSheet(ev.sheet);
    resetDm();
  }
}

function setEnabled(on) {
  input.disabled = !on;
  sendBtn.disabled = !on;
}

// ---- actions -----------------------------------------------------------
async function newCampaign() {
  if (busy) return;
  const r = await fetch("/api/new", { method: "POST" });
  const data = await r.json();
  campaignId = data.id;
  log.innerHTML = "";
  rollsEl.innerHTML = "";
  renderSheet(null);
  addMessage("system", "A new campaign begins…");
  send("Let's begin. Start a new campaign and guide me through creating my character.");
}

async function saveCampaign() {
  if (!campaignId) return;
  const name = prompt("Save campaign as:", "");
  if (name === null) return;
  const r = await fetch("/api/save", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ id: campaignId, name }),
  });
  const data = await r.json();
  if (data.ok) addMessage("system", `Saved as “${data.name}”.`);
  else addMessage("system", "Save failed: " + (data.error || "unknown"));
}

async function openLoad() {
  const r = await fetch("/api/saves");
  const data = await r.json();
  modalTitle.textContent = "Load a campaign";
  modalBody.innerHTML = "";
  if (data.autosave) {
    modalBody.appendChild(saveRow("_autosave", "↻ Resume last session"));
  }
  if (!data.saves.length && !data.autosave) {
    modalBody.innerHTML = "<p style='color:var(--muted)'>No saved campaigns yet.</p>";
  }
  data.saves.forEach(s => modalBody.appendChild(saveRow(s.name, s.name)));
  modal.classList.remove("hidden");
}

function saveRow(name, label) {
  const row = document.createElement("div");
  row.className = "save-item";
  const span = document.createElement("span");
  span.textContent = label;
  const btn = document.createElement("button");
  btn.textContent = "Load";
  btn.onclick = () => loadCampaign(name);
  row.appendChild(span);
  row.appendChild(btn);
  return row;
}

async function loadCampaign(name) {
  const r = await fetch("/api/load", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name }),
  });
  const data = await r.json();
  if (data.error) { alert(data.error); return; }
  campaignId = data.id;
  modal.classList.add("hidden");
  log.innerHTML = "";
  rollsEl.innerHTML = "";
  renderSheet(data.sheet);
  (data.transcript || []).forEach(m => addMessage(m.role === "player" ? "player" : "dm", m.text));
  addMessage("system", "Campaign loaded. The story continues…");
  input.focus();
}

// ---- wiring ------------------------------------------------------------
composer.addEventListener("submit", (e) => {
  e.preventDefault();
  const text = input.value.trim();
  if (!text || busy) return;
  input.value = "";
  send(text);
});

input.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey) {
    e.preventDefault();
    composer.requestSubmit();
  }
});

document.getElementById("btn-new").onclick = newCampaign;
document.getElementById("btn-save").onclick = saveCampaign;
document.getElementById("btn-load").onclick = openLoad;
document.getElementById("modal-close").onclick = () => modal.classList.add("hidden");
modal.addEventListener("click", (e) => { if (e.target === modal) modal.classList.add("hidden"); });

// Auto-start a fresh campaign on first load.
newCampaign();
