// Tiny CDP client for the Sober TikTok Chrome (jmbp2:9226, reached through `ssh -L 9226`).
//   node cdp.mjs eval '<js>'        node cdp.mjs shot out.jpg     node cdp.mjs nav <url>
//   node cdp.mjs files '<css>' /remote/path ...   node cdp.mjs click x y   node cdp.mjs type 'text'
const PORT = process.env.CDP_PORT || 9226;

// Open a new tab at url and close every other page, so each job starts clean (a draft left on the
// upload page holds a "Leave site?" dialog that can freeze the renderer).
export async function freshTab(url) {
  const v = await (await fetch(`http://127.0.0.1:${PORT}/json/version`)).json();
  const ws = new WebSocket(v.webSocketDebuggerUrl);
  await new Promise(r => (ws.onopen = r));
  let id = 0;
  const pend = new Map();
  ws.onmessage = m => { const d = JSON.parse(m.data); if (d.id && pend.has(d.id)) { pend.get(d.id)(d); pend.delete(d.id); } };
  const send = (method, params = {}) => new Promise(res => { const n = ++id; pend.set(n, res); ws.send(JSON.stringify({ id: n, method, params })); });
  const { result } = await send("Target.getTargets");
  const created = await send("Target.createTarget", { url });
  for (const t of result.targetInfos.filter(t => t.type === "page")) await send("Target.closeTarget", { targetId: t.targetId });
  ws.close();
  return created.result.targetId;
}

export async function page() {
  let t;
  for (let i = 0; i < 40 && !t; i++) {
    const tabs = (await (await fetch(`http://127.0.0.1:${PORT}/json`)).json()).filter(p => p.type === "page" && p.webSocketDebuggerUrl);
    t = tabs.find(p => p.url.includes("tiktok")) || (i > 20 && tabs[0]);
    if (!t) await new Promise(r => setTimeout(r, 500));
  }
  if (!t) throw new Error("no debuggable page");
  const ws = new WebSocket(t.webSocketDebuggerUrl);
  await new Promise(r => (ws.onopen = r));
  let id = 0;
  const pending = new Map();
  ws.onmessage = m => {
    const d = JSON.parse(m.data);
    if (d.id && pending.has(d.id)) { pending.get(d.id)(d); pending.delete(d.id); }
    // Accept "Leave site?" and any other JS dialog so it never blocks the page.
    if (d.method === "Page.javascriptDialogOpening") ws.send(JSON.stringify({ id: 0, method: "Page.handleJavaScriptDialog", params: { accept: true } }));
  };
  const send = (method, params = {}, ms = 60000) => new Promise((res, rej) => {
    const n = ++id;
    const timer = setTimeout(() => { pending.delete(n); rej(new Error(`${method}: no reply in ${ms / 1000}s (page frozen?)`)); }, ms);
    pending.set(n, d => { clearTimeout(timer); d.error ? rej(new Error(`${method}: ${d.error.message}`)) : res(d.result); });
    ws.send(JSON.stringify({ id: n, method, params }));
  });
  ws.send(JSON.stringify({ id: 0, method: "Page.enable" }));
  const evaluate = async expr => {
    const r = await send("Runtime.evaluate", { expression: expr, awaitPromise: true, returnByValue: true });
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
    return r.result.value;
  };
  const click = async (x, y) => {
    for (const type of ["mouseMoved", "mousePressed", "mouseReleased"])
      await send("Input.dispatchMouseEvent", { type, x, y, button: "left", clickCount: 1 });
  };
  // Real mouse click on the element an expression returns (scrolled into view first).
  const clickEl = async expr => {
    const r = await evaluate(`(()=>{const e=(${expr});if(!e)return null;e.scrollIntoView({block:"center"});const b=e.getBoundingClientRect();return [b.x+b.width/2,b.y+b.height/2]})()`);
    if (!r) throw new Error(`nothing to click: ${expr}`);
    await click(r[0], r[1]);
  };
  const type = text => send("Input.insertText", { text });
  const key = async (k, code = k, vk = 0) => {
    await send("Input.dispatchKeyEvent", { type: "keyDown", key: k, code, windowsVirtualKeyCode: vk });
    await send("Input.dispatchKeyEvent", { type: "keyUp", key: k, code, windowsVirtualKeyCode: vk });
  };
  const files = async (css, paths) => {
    const { root } = await send("DOM.getDocument", { depth: -1, pierce: true });
    const { nodeId } = await send("DOM.querySelector", { nodeId: root.nodeId, selector: css });
    if (!nodeId) throw new Error(`no node for ${css}`);
    await send("DOM.setFileInputFiles", { nodeId, files: paths });
  };
  const shot = async out => {
    const r = await send("Page.captureScreenshot", { format: "jpeg", quality: 70 });
    (await import("fs")).writeFileSync(out, Buffer.from(r.data, "base64"));
  };
  const nav = async url => { await send("Page.navigate", { url }); await new Promise(r => setTimeout(r, 4000)); };
  return { ws, send, evaluate, click, clickEl, type, key, files, shot, nav, close: () => ws.close() };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [cmd, ...a] = process.argv.slice(2);
  const p = await page();
  try {
    if (cmd === "eval") console.log(JSON.stringify(await p.evaluate(a[0]), null, 1));
    if (cmd === "shot") { await p.shot(a[0] || "shot.jpg"); console.log("saved"); }
    if (cmd === "nav") await p.nav(a[0]);
    if (cmd === "files") await p.files(a[0], a.slice(1));
    if (cmd === "click") await p.click(+a[0], +a[1]);
    if (cmd === "type") await p.type(a[0]);
  } finally { p.close(); }
}
