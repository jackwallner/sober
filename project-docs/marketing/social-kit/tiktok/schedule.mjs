// Schedule queue.json slots in TikTok Studio web on the Sober Chrome (jmbp2:9226 via `ssh -L 9226`).
//   node schedule.mjs queue.json [--only 2026-11-03] [--id L1] [--dry]
// --dry fills everything and stops before the Schedule button. Every slot is verified before it is
// scheduled; a slot that fails verification is skipped and reported. Results go to scheduled.jsonl.
import fs from "fs";
import { freshTab, page } from "./cdp.mjs";

const args = process.argv.slice(2);
const opt = k => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : null; };
const queue = JSON.parse(fs.readFileSync(args[0]));
const dry = args.includes("--dry");
const only = opt("--only"), onlyId = opt("--id");
const log = new URL("./scheduled.jsonl", import.meta.url);
const done = fs.existsSync(log) ? fs.readFileSync(log, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse) : [];
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const sleep = ms => new Promise(r => setTimeout(r, ms));

let p, ev, step = "";
async function connect(url) {
  if (p) if (p) p.close();
await freshTab("https://www.tiktok.com/tiktokstudio/content");
  await freshTab(url);
  await sleep(5000);
  p = await page();
  ev = expr => p.evaluate(expr);
}

async function waitFor(expr, ms = 60000, what = expr) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (await ev(expr).catch(() => false)) return;
    await sleep(500);
  }
  throw new Error(`timed out: ${what}`);
}

const byText = (sel, text) => `[...document.querySelectorAll(${JSON.stringify(sel)})].find(e=>e.innerText?.trim()===${JSON.stringify(text)})`;
const leaf = text => `[...document.querySelectorAll("*")].find(e=>e.childElementCount==0&&e.innerText?.trim()===${JSON.stringify(text)})`;
const switchFor = label => `[...document.querySelectorAll("[role=switch], input[type=checkbox]")].find(s=>{let c=s;for(let i=0;i<6&&c.innerText.length<5;i++)c=c.parentElement;return c.innerText.startsWith(${JSON.stringify(label)})})`;

async function selectAllAndDelete() {
  await p.send("Input.dispatchKeyEvent", { type: "keyDown", key: "a", code: "KeyA", modifiers: 4, windowsVirtualKeyCode: 65, commands: ["selectAll"] });
  await p.send("Input.dispatchKeyEvent", { type: "keyUp", key: "a", code: "KeyA", modifiers: 4, windowsVirtualKeyCode: 65 });
  await p.key("Backspace", "Backspace", 8);
}

async function enter() {
  await p.send("Input.dispatchKeyEvent", { type: "keyDown", key: "Enter", code: "Enter", windowsVirtualKeyCode: 13, text: "\r" });
  await p.send("Input.dispatchKeyEvent", { type: "keyUp", key: "Enter", code: "Enter", windowsVirtualKeyCode: 13 });
}

async function fillCaption(text) {
  await p.clickEl(`document.querySelector(".public-DraftEditor-content")`);
  await sleep(300);
  await selectAllAndDelete();
  const lines = text.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.includes("#")) {
      // Type hashtags word by word, closing each suggestion popup with a space.
      for (const word of line.split(" ")) { await p.type(word); await sleep(700); await p.type(" "); await sleep(300); }
      await p.key("Escape", "Escape", 27);
    } else if (line) {
      await p.type(line);
    }
    if (i < lines.length - 1) { await enter(); await sleep(100); }
  }
  await sleep(800);
}

async function setDate(iso) {
  const [y, m, d] = iso.split("-").map(Number);
  const want = `${MONTHS[m - 1]} ${d}, ${y}`;
  for (let tries = 0; tries < 3; tries++) {
    const cur = await ev(`document.querySelector("[aria-label='Select date']").innerText.trim()`);
    if (cur === want) return;
    await p.clickEl(`document.querySelector("[aria-label='Select date']")`);
    await sleep(800);
    // Month view: day buttons of the shown month come before the trailing next-month ones.
    const header = await ev(`document.querySelector("[class*=DatePicker__header], [class*=DatePicker__title]")?.innerText || ""`);
    if (header && !header.includes(MONTHS[m - 1]) && !header.includes(String(m))) {
      await p.clickEl(`document.querySelector("[class*=DatePicker] button[aria-label*=ext], [class*=DatePicker__next]")`);
      await sleep(600);
    }
    await p.clickEl(`[...document.querySelectorAll("button.DatePicker__day")].find(b=>b.innerText.trim()=="${d}"&&!b.disabled)`);
    await sleep(800);
  }
  const cur = await ev(`document.querySelector("[aria-label='Select date']").innerText.trim()`);
  if (cur !== want) throw new Error(`date stuck at ${cur}, wanted ${want}`);
}

async function setTime(hhmm) {
  const [h, m] = hhmm.split(":");
  for (let tries = 0; tries < 3; tries++) {
    if ((await ev(`document.querySelector("[aria-label='Select time']").innerText.trim()`)) === hhmm) return;
    const open = await ev(`!!document.querySelector(".TimePicker__column")`);
    if (!open) { await p.clickEl(`document.querySelector("[aria-label='Select time']")`); await sleep(800); }
    await p.clickEl(`[...[...document.querySelectorAll(".TimePicker__column")][0].children].find(e=>e.innerText.trim()=="${h}")`);
    await sleep(500);
    if (!(await ev(`!!document.querySelector(".TimePicker__column")`))) { await p.clickEl(`document.querySelector("[aria-label='Select time']")`); await sleep(800); }
    await p.clickEl(`[...[...document.querySelectorAll(".TimePicker__column")][1].children].find(e=>e.innerText.trim()=="${m}")`);
    await sleep(500);
  }
  const cur = await ev(`document.querySelector("[aria-label='Select time']").innerText.trim()`);
  if (cur !== hhmm) throw new Error(`time stuck at ${cur}, wanted ${hhmm}`);
  await p.key("Escape", "Escape", 27);
}

async function disclose() {
  const on = await ev(`${switchFor("Disclose post content")}?.getAttribute("aria-checked") ?? String(${switchFor("Disclose post content")}?.checked)`);
  if (on !== "true") { await p.clickEl(switchFor("Disclose post content")); await sleep(1200); }
  const brand = `[...document.querySelectorAll("input[type=checkbox]")].find(s=>{let c=s;for(let i=0;i<4&&c.innerText.length<3;i++)c=c.parentElement;return c.innerText.trim().startsWith("Your brand")})`;
  if (!(await ev(`${brand}?.checked`))) { await p.clickEl(brand); await sleep(800); }
  // A confirm dialog can appear the first time.
  const ok = await ev(`!!(${byText("button", "Got it")} || ${byText("button", "Confirm")})`);
  if (ok) { await p.clickEl(`${byText("button", "Got it")} || ${byText("button", "Confirm")}`); await sleep(600); }
  return ev(`!!${brand}?.checked`);
}

// First-run popups: "New editing features" (Got it) and "Turn on automatic content checks?" (Cancel,
// so no account setting changes).
async function dismissPopups() {
  // Each popup's button is looked up inside the smallest element holding that popup's own text.
  const inBox = (text, button) => `(()=>{const box=[...document.querySelectorAll("div")].filter(d=>d.innerText?.includes(${JSON.stringify(text)})&&[...d.querySelectorAll("button")].some(b=>b.innerText.trim()==${JSON.stringify(button)})).sort((x,y)=>x.innerText.length-y.innerText.length)[0];return box&&[...box.querySelectorAll("button")].find(b=>b.innerText.trim()==${JSON.stringify(button)})})()`;
  const popups = [["Discard this post?", "Not now"], ["Turn on automatic content checks?", "Cancel"], ["New editing features added", "Got it"]];
  for (let i = 0; i < 4; i++) {
    let hit = false;
    for (const [text, button] of popups) {
      if (await ev(`!!${inBox(text, button)}`)) { await p.clickEl(inBox(text, button)); hit = true; await sleep(700); }
    }
    if (!hit) return;
  }
}

async function one(slot) {
  step = "open";
  await connect("https://www.tiktok.com/tiktokstudio/upload?from=webapp");
  await waitFor(`!!document.querySelector("input[type=file]")`, 30000, "upload page");
  if (slot.kind === "photo") {
    await p.clickEl(`${byText("button,[role=tab],div", "Photos")}`);
    await waitFor(`!!document.querySelector("input[type=file][accept*=image]")`, 10000, "photos tab");
    await p.files("input[type=file][accept*=image]", slot.files);
  } else {
    await p.files("input[type=file][accept*=video]", slot.files);
  }
  await waitFor(`!!document.querySelector(".public-DraftEditor-content")`, 90000, "editor");
  await sleep(1500);
  await dismissPopups();
  if (slot.kind === "video") {
    await waitFor(`/Uploaded|uploaded/.test(document.body.innerText) && !/Uploading/.test(document.body.innerText)`, 240000, "video upload");
  } else {
    await waitFor(`/${slot.files.length} photos? uploaded/.test(document.body.innerText)`, 60000, "photos uploaded");
    await p.clickEl(`document.querySelector("input[placeholder='Add a catchy title']")`);
    await selectAllAndDelete();
    await p.type(slot.title);
  }
  await dismissPopups();
  step = "caption";
  await fillCaption(slot.caption);
  if (await ev(`!!${leaf("Show more")}`)) { await p.clickEl(leaf("Show more")); await sleep(600); }
  await p.clickEl(`[...document.querySelectorAll("input[name=postSchedule]")].find(i=>i.value=="schedule")`);
  await sleep(1200);
  if (await ev(`!!${byText("button", "Allow")}`)) { await p.clickEl(byText("button", "Allow")); await sleep(1200); }
  step = "date";
  await setDate(slot.date);
  step = "time";
  await setTime(slot.time);
  step = "disclose";
  const brand = slot.disclose ? await disclose() : true;

  // Verify before scheduling.
  const v = await ev(`(()=>({
    title: document.querySelector("input[placeholder='Add a catchy title']")?.value ?? null,
    caption: document.querySelector(".public-DraftEditor-content")?.innerText ?? "",
    date: document.querySelector("[aria-label='Select date']")?.innerText.trim(),
    time: document.querySelector("[aria-label='Select time']")?.innerText.trim(),
    scheduled: [...document.querySelectorAll("input[name=postSchedule]")].find(i=>i.value=="schedule")?.closest("label")?.querySelector("[class*=checked-true]") != null,
    button: [...document.querySelectorAll("button")].map(b=>b.innerText.trim()).find(t=>t=="Schedule"||t=="Post"),
  }))()`);
  const norm = s => s.replace(/\s+/g, " ").trim();
  const problems = [];
  if (slot.kind === "photo" && v.title !== slot.title) problems.push(`title "${v.title}"`);
  if (norm(v.caption) !== norm(slot.caption)) problems.push(`caption "${norm(v.caption).slice(0, 120)}..." vs "${norm(slot.caption).slice(0, 120)}..."`);
  const [y, mo, d] = slot.date.split("-").map(Number);
  if (v.date !== `${MONTHS[mo - 1]} ${d}, ${y}`) problems.push(`date ${v.date}`);
  if (v.time !== slot.time) problems.push(`time ${v.time}`);
  if (v.button !== "Schedule") problems.push(`button ${v.button}`);
  if (!brand) problems.push("brand disclosure");
  await p.shot(new URL(`./shots/${slot.date}-${slot.time.replace(":", "")}-${slot.id}.jpg`, import.meta.url).pathname);
  if (problems.length) throw new Error("verify failed: " + problems.join("; "));
  if (dry) return "dry";
  await p.clickEl(byText("button", "Schedule"));
  await waitFor(`location.pathname.includes("/content") || /scheduled|Scheduled/.test(document.body.innerText.slice(0,3000))`, 120000, "schedule confirmation");
  return "scheduled";
}

fs.mkdirSync(new URL("./shots/", import.meta.url), { recursive: true });
for (const slot of queue) {
  if (only && slot.date !== only) continue;
  if (onlyId && slot.id !== onlyId) continue;
  if (done.some(x => x.date === slot.date && x.time === slot.time && x.status === "scheduled")) continue;
  const t0 = Date.now();
  try {
    const status = await one(slot);
    console.log(`${slot.date} ${slot.time} ${slot.id} ${status} (${Math.round((Date.now() - t0) / 1000)}s)`);
    if (status === "scheduled")
      fs.appendFileSync(log, JSON.stringify({ date: slot.date, time: slot.time, id: slot.id, mode: slot.mode, status, at: new Date().toISOString() }) + "\n");
  } catch (e) {
    console.log(`${slot.date} ${slot.time} ${slot.id} FAILED at ${step}: ${e.message.split("\n")[0]}`);
    await p?.shot(new URL(`./shots/FAIL-${slot.date}-${slot.id}.jpg`, import.meta.url).pathname).catch(() => {});
  }
  await sleep(4000);
}
if (p) p.close();
await freshTab("https://www.tiktok.com/tiktokstudio/content");
