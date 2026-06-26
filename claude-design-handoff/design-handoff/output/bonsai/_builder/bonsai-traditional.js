// Procedural Traditional bonsai SVG generator.
// One source of truth — all 13 anchors come from this with per-day param sets.
//
// Canvas:  600 × 600, transparent.
// Safe area: 64px (art inside 472×472).
// Pot baseline: y = 460 (identical across every anchor).
// Style: traditional — vertical trunk, slight S-curve, balanced-not-mirrored canopy.

const PALETTE = {
  // Foliage
  leafDeep:   '#2F5E45',   // shadow side, deepest
  leafSage:   '#519E73',   // primary mass (brand.primary)
  leafFresh:  '#7BC68C',   // mid-light (brand.secondary)
  leafLight:  '#A9D4A8',   // top-light highlight
  leafAutumn: '#D8A35E',   // late-stage seasonal interest (warm sand family)
  // Bark
  barkDeep:   '#3E2A1B',
  barkMid:    '#6B4A2E',
  barkLight:  '#A07B52',
  // Pot — deep umber, traditional ceramic
  potDark:    '#3B2A1C',
  potMid:     '#5C402A',
  potRim:     '#2C1F14',
  // Soil
  soilDark:   '#221710',
  soilMid:    '#3A2A1C',
  // Moss / lichen (late stages)
  moss:       '#9DB16E',
  lichen:     '#C7CDA7',
};

// ----- Pot (identical for every anchor) -----
function pot() {
  // Trapezoidal earthen pot, top slightly wider than bottom.
  // Bottom (baseline) at y=460. Top at y=410.
  // Top width 260 (x 170 → 430). Bottom width 232 (x 184 → 416).
  return `
  <g id="pot">
    <defs>
      <linearGradient id="potShade" x1="0" y1="0" x2="1" y2="0">
        <stop offset="0" stop-color="${PALETTE.potMid}"/>
        <stop offset="0.45" stop-color="${PALETTE.potDark}"/>
        <stop offset="1" stop-color="${PALETTE.potDark}"/>
      </linearGradient>
      <linearGradient id="potBody" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${PALETTE.potMid}"/>
        <stop offset="1" stop-color="${PALETTE.potDark}"/>
      </linearGradient>
    </defs>
    <!-- body -->
    <path d="M170 415
             L184 460
             L416 460
             L430 415 Z" fill="url(#potBody)"/>
    <!-- shadow on right -->
    <path d="M300 415
             L416 460
             L430 415 Z" fill="${PALETTE.potDark}" opacity="0.55"/>
    <!-- rim (top ellipse) -->
    <ellipse cx="300" cy="413" rx="130" ry="9" fill="${PALETTE.potRim}"/>
    <ellipse cx="300" cy="411" rx="130" ry="8" fill="${PALETTE.potMid}"/>
    <!-- soil -->
    <ellipse cx="300" cy="412" rx="124" ry="6.5" fill="${PALETTE.soilMid}"/>
    <ellipse cx="300" cy="412.5" rx="122" ry="5.5" fill="${PALETTE.soilDark}"/>
    <!-- soil flecks for texture -->
    <circle cx="240" cy="412" r="1.8" fill="${PALETTE.barkMid}" opacity="0.55"/>
    <circle cx="285" cy="413" r="1.2" fill="${PALETTE.barkLight}" opacity="0.4"/>
    <circle cx="328" cy="412" r="1.6" fill="${PALETTE.barkMid}" opacity="0.5"/>
    <circle cx="358" cy="413" r="1.2" fill="${PALETTE.barkLight}" opacity="0.35"/>
    <circle cx="210" cy="413" r="1.4" fill="${PALETTE.barkLight}" opacity="0.4"/>
  </g>`;
}

// ----- Soil-stage decorations (moss / roots overlays) -----
function rootsAndMoss(params) {
  const { mossOnTrunk = 0, exposedRoots = 0 } = params;
  let s = '';
  if (exposedRoots > 0) {
    const a = Math.min(1, exposedRoots);
    s += `<g id="roots" opacity="${0.6 + 0.4 * a}">
      <path d="M280 411 Q272 408 266 410 Q272 412 282 412" fill="${PALETTE.barkMid}"/>
      <path d="M295 411 Q288 407 282 409 Q290 412 296 412" fill="${PALETTE.barkDeep}" opacity="0.7"/>
      <path d="M312 411 Q322 408 330 410 Q322 412 312 412" fill="${PALETTE.barkMid}"/>
      <path d="M322 411 Q332 407 338 409 Q332 412 320 412" fill="${PALETTE.barkDeep}" opacity="0.7"/>
    </g>`;
  }
  if (mossOnTrunk > 0) {
    const a = Math.min(1, mossOnTrunk);
    // small moss patches at trunk base climbing up
    const patches = [
      [292, 408, 5, 2],
      [302, 406, 6, 2.4],
      [296, 402, 4, 1.8],
      [307, 397, 3.5, 1.7],
      [294, 394, 3, 1.4],
    ];
    s += `<g id="moss" opacity="${0.55 + 0.45 * a}">`;
    patches.slice(0, Math.ceil(2 + 3 * a)).forEach(([x, y, rx, ry]) => {
      s += `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${PALETTE.moss}"/>`;
    });
    s += `</g>`;
  }
  return s;
}

// ----- Trunk (S-curve, filled path with gradient) -----
// Returns SVG + an array of branch attach points the caller uses for foliage placement.
function trunk(params) {
  const { trunkHeight = 0.6, trunkThickness = 0.5, trunkGnarl = 0, anchorBaseX = 300 } = params;
  // base at (anchorBaseX, 410), tip at (tipX, tipY)
  const baseY = 410;
  // height in px from base upward
  const heightPx = 70 + 230 * trunkHeight;   // 70..300
  const tipY = baseY - heightPx;
  // gentle S-curve in x: base→right, mid→left, tip→right slightly
  const tipX = anchorBaseX + 12;
  const baseW = 8 + 36 * trunkThickness;     // 8..44 px wide at base
  const midW  = baseW * 0.6;
  const tipW  = Math.max(2.4, baseW * 0.25);

  // S-curve control points
  const midY = (baseY + tipY) / 2;
  const midX1 = anchorBaseX - 14;            // first bend (left)
  const midX2 = anchorBaseX + 18;            // second bend (right)

  // Build a closed filled path that approximates trunk silhouette
  // Left edge: base-left → curve up through midX1-leftish → tip-left
  // Right edge: tip-right → curve down through midX2-rightish → base-right
  const bL = anchorBaseX - baseW / 2;
  const bR = anchorBaseX + baseW / 2;
  const m1L = midX1 - midW / 2;
  const m1R = midX1 + midW / 2;
  const m2L = midX2 - midW / 2;
  const m2R = midX2 + midW / 2;
  const tL = tipX - tipW / 2;
  const tR = tipX + tipW / 2;

  // Use quadratic curves through control "knee" points for organic shape
  const path = `
    M ${bL} ${baseY}
    Q ${m1L - 4} ${(baseY + midY) / 2} ${m1L} ${midY}
    Q ${m2L - 2} ${(midY + tipY) / 2} ${tL} ${tipY}
    L ${tR} ${tipY}
    Q ${m2R + 2} ${(midY + tipY) / 2} ${m2R} ${midY}
    Q ${m1R + 4} ${(baseY + midY) / 2} ${bR} ${baseY}
    Z
  `;

  // Gnarl "knuckles" — dark ellipses at the bends, used on aged stages
  let gnarl = '';
  if (trunkGnarl > 0) {
    const a = Math.min(1, trunkGnarl);
    gnarl += `<g id="gnarl" opacity="${0.5 + 0.5 * a}">
      <ellipse cx="${midX1 + midW * 0.15}" cy="${midY + 4}" rx="${midW * 0.55}" ry="3.6" fill="${PALETTE.barkDeep}" opacity="0.55"/>
      <ellipse cx="${midX2 - midW * 0.15}" cy="${(midY + tipY) / 2}" rx="${midW * 0.45}" ry="3" fill="${PALETTE.barkDeep}" opacity="0.5"/>
      <ellipse cx="${(bL + m1L) / 2}" cy="${(baseY + midY) / 2 + 6}" rx="${baseW * 0.35}" ry="3.2" fill="${PALETTE.barkDeep}" opacity="0.45"/>
    </g>`;
  }

  // Branches — short stubs emerging from the bends on older stages.
  // Kept short so foliage masses fully cover them; we want shape, not exposed sticks.
  let branches = '';
  if (trunkThickness > 0.4) {
    // upper-left branch from mid1 — short, anchors into the upper-left foliage
    branches += `<path d="M ${m1L + 2} ${midY + 4}
                          Q ${m1L - 16} ${midY - 6} ${m1L - 36} ${midY - 22}"
                       stroke="${PALETTE.barkMid}" stroke-width="${Math.max(3, baseW * 0.18)}"
                       stroke-linecap="round" fill="none"/>`;
    // upper-right branch
    branches += `<path d="M ${m2R - 2} ${(midY + tipY) / 2 + 4}
                          Q ${m2R + 18} ${(midY + tipY) / 2 - 14} ${m2R + 36} ${(midY + tipY) / 2 - 30}"
                       stroke="${PALETTE.barkMid}" stroke-width="${Math.max(2.6, baseW * 0.14)}"
                       stroke-linecap="round" fill="none"/>`;
  }
  if (trunkThickness > 0.6) {
    // lower-right branch
    branches += `<path d="M ${bR - 2} ${baseY - 36}
                          Q ${bR + 18} ${baseY - 54} ${bR + 42} ${baseY - 72}"
                       stroke="${PALETTE.barkMid}" stroke-width="${Math.max(2.4, baseW * 0.12)}"
                       stroke-linecap="round" fill="none"/>`;
  }

  // Attach points for foliage clusters — placed AT branch endpoints
  // so the cluster blob fully covers the bark stub. (caller can still nudge with dx/dy)
  const attachPoints = {
    crown:      [tipX,           tipY - 8],
    upperLeft:  [m1L - 36,       midY - 22],
    upperRight: [m2R + 36,       (midY + tipY) / 2 - 30],
    midLeft:    [m1L - 12,       midY - 4],
    midRight:   [m2R + 12,       (midY + tipY) / 2 - 6],
    lowerRight: [bR + 42,        baseY - 72],
  };

  const trunkSVG = `
  <defs>
    <linearGradient id="trunkGrad" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0"   stop-color="${PALETTE.barkLight}"/>
      <stop offset="0.45" stop-color="${PALETTE.barkMid}"/>
      <stop offset="1"   stop-color="${PALETTE.barkDeep}"/>
    </linearGradient>
  </defs>
  <g id="branches">${branches}</g>
  <g id="trunk">
    <path d="${path}" fill="url(#trunkGrad)"/>
    ${gnarl}
  </g>`;

  return { svg: trunkSVG, attachPoints };
}

// ----- Painterly foliage cluster -----
// Built from organic blob silhouettes (not ellipses) with multiple internal leaf-clumps
// to imitate the cumulus-cluster look of Ghibli background foliage.

// Deterministic hash → [0,1)
function rand01(seed, n) {
  const v = Math.sin(seed * 12.9898 + n * 78.233) * 43758.5453;
  return v - Math.floor(v);
}

// Closed bezier "cloud blob" path string.
//   cx, cy: center; rBase: radius; squashY: vertical squash; noise: 0..1 jitter on radii.
function blobPath(cx, cy, rBase, opts) {
  const { seed = 0, points = 13, squashY = 0.82, noise = 0.28, tiltDeg = 0 } = opts;
  const tilt = (tiltDeg * Math.PI) / 180;
  // 1. Sample radii around the circle
  const pts = [];
  for (let i = 0; i < points; i++) {
    const t = (i / points) * Math.PI * 2;
    const r = rBase * (1 + (rand01(seed, i + 1) - 0.5) * 2 * noise);
    const x = Math.cos(t + tilt) * r;
    const y = Math.sin(t + tilt) * r * squashY;
    pts.push([cx + x, cy + y]);
  }
  // 2. Smooth via quadratic Q segments, using each vertex as control point and midpoint as endpoint
  const start = [(pts[points - 1][0] + pts[0][0]) / 2, (pts[points - 1][1] + pts[0][1]) / 2];
  let d = `M ${start[0].toFixed(2)} ${start[1].toFixed(2)} `;
  for (let i = 0; i < points; i++) {
    const a = pts[i];
    const b = pts[(i + 1) % points];
    const mx = (a[0] + b[0]) / 2;
    const my = (a[1] + b[1]) / 2;
    d += `Q ${a[0].toFixed(2)} ${a[1].toFixed(2)} ${mx.toFixed(2)} ${my.toFixed(2)} `;
  }
  d += 'Z';
  return d;
}

function cluster(cx, cy, size, opts = {}) {
  const {
    tone = 'sage',
    saturation = 1,
    seed = 0,
  } = opts;
  const trios = {
    sage:   [PALETTE.leafDeep, PALETTE.leafSage,  PALETTE.leafFresh, PALETTE.leafLight],
    fresh:  [PALETTE.leafDeep, PALETTE.leafFresh, PALETTE.leafLight, '#C7E5B8'],
    autumn: ['#5C3D1F',        '#B07A3C',         PALETTE.leafAutumn, '#F2D593'],
  };
  const [shadow, mid, midLight, light] = trios[tone] || trios.sage;
  const sat = Math.max(0.4, saturation);

  // Per-cluster deterministic jitter
  const r = (n) => rand01(seed, n);
  const tilt = (r(99) - 0.5) * 20; // small overall rotation

  // 1) Shadow silhouette (slightly offset down-right, bigger)
  const shadowBlob = blobPath(
    size * 0.10, size * 0.14, size * 1.02,
    { seed: seed * 1.1, points: 13, squashY: 0.82, noise: 0.22, tiltDeg: tilt }
  );
  // 2) Main mid mass
  const midBlob = blobPath(
    0, 0, size * 0.92,
    { seed: seed * 1.3 + 7, points: 14, squashY: 0.86, noise: 0.26, tiltDeg: tilt * 0.7 }
  );
  // 3) Internal leaf-clumps — scattered smaller mid-light blobs on top-left
  let clumps = '';
  const clumpCount = 5;
  for (let i = 0; i < clumpCount; i++) {
    const a = (i / clumpCount) * Math.PI * 1.4 - Math.PI * 0.95; // arc on upper-left
    const off = size * (0.32 + r(i * 5 + 2) * 0.22);
    const cxL = Math.cos(a) * off;
    const cyL = Math.sin(a) * off * 0.7 - size * 0.08;
    const rad = size * (0.18 + r(i * 5 + 3) * 0.12);
    const path = blobPath(cxL, cyL, rad, {
      seed: seed * 17 + i * 31, points: 9, squashY: 0.9, noise: 0.32,
    });
    clumps += `<path d="${path}" fill="${midLight}" opacity="${0.7 * sat}"/>`;
  }
  // 4) Highlight catchlights — tiny light leaves on top
  let lights = '';
  const lightCount = 4;
  for (let i = 0; i < lightCount; i++) {
    const a = -Math.PI * 0.75 + (i / lightCount) * Math.PI * 0.7;
    const off = size * (0.45 + r(i * 7 + 9) * 0.18);
    const cxL = Math.cos(a) * off;
    const cyL = Math.sin(a) * off * 0.55 - size * 0.18;
    const rad = size * (0.09 + r(i * 7 + 11) * 0.07);
    const path = blobPath(cxL, cyL, rad, {
      seed: seed * 23 + i * 41, points: 8, squashY: 0.95, noise: 0.28,
    });
    lights += `<path d="${path}" fill="${light}" opacity="${0.82 * sat}"/>`;
  }
  // 5) Edge texture — a couple of dark leaf flecks on the silhouette edge to suggest leaves outside the mass
  let edge = '';
  const edgeCount = 3;
  for (let i = 0; i < edgeCount; i++) {
    const a = Math.PI * (0.15 + i * 0.6);
    const off = size * (0.95 + r(i + 50) * 0.1);
    const cxL = Math.cos(a) * off + size * 0.06;
    const cyL = Math.sin(a) * off * 0.8 + size * 0.06;
    const rad = size * (0.08 + r(i + 51) * 0.05);
    const path = blobPath(cxL, cyL, rad, {
      seed: seed * 29 + i * 13, points: 7, squashY: 0.9, noise: 0.35,
    });
    edge += `<path d="${path}" fill="${shadow}" opacity="${0.55 * sat}"/>`;
  }

  return `
    <g id="cluster-${seed}" transform="translate(${cx.toFixed(2)} ${cy.toFixed(2)})">
      <path d="${shadowBlob}" fill="${shadow}" opacity="${0.78 * sat}"/>
      ${edge}
      <path d="${midBlob}" fill="${mid}" opacity="${0.94 * sat}"/>
      ${clumps}
      ${lights}
    </g>`;
}

// ----- Stage renderers -----

// Days 0–10: seed / sprout / seedling (no real tree yet)
function renderEarly(day, params) {
  let s = '';
  const cx = 300;
  const soilY = 410;

  if (day === 0) {
    // seed — clearly visible, slightly nested in soil, warm vs cool palette so it pops on soil
    s += `<ellipse cx="${cx}" cy="${soilY + 1}" rx="22" ry="3.5" fill="${PALETTE.barkDeep}" opacity="0.55"/>`;
    s += `<ellipse cx="${cx + 1}" cy="${soilY - 2}" rx="7" ry="4" fill="${PALETTE.barkMid}"/>`;
    s += `<ellipse cx="${cx - 0.5}" cy="${soilY - 3}" rx="4.5" ry="2.6" fill="${PALETTE.barkLight}" opacity="0.85"/>`;
    s += `<ellipse cx="${cx - 1.5}" cy="${soilY - 3.5}" rx="2" ry="1.2" fill="#E0BD8E" opacity="0.7"/>`;
    return s;
  }

  if (day === 1) {
    // first green tip — readable at thumbnail size: 16px tall, mid-saturated green,
    // with the soil "lifted" slightly around the emergence point.
    s += `<ellipse cx="${cx}" cy="${soilY + 1}" rx="14" ry="2.4" fill="${PALETTE.barkDeep}" opacity="0.5"/>`;
    s += `<path d="M ${cx - 0.5} ${soilY - 1}
                   Q ${cx + 0.5} ${soilY - 9} ${cx + 0.5} ${soilY - 16}"
            stroke="${PALETTE.leafSage}" stroke-width="3.2" fill="none" stroke-linecap="round"/>`;
    // leaf bud at top — a small closed shape
    s += `<ellipse cx="${cx + 0.5}" cy="${soilY - 18}" rx="5" ry="3" fill="${PALETTE.leafFresh}" transform="rotate(-12 ${cx + 0.5} ${soilY - 18})"/>`;
    s += `<ellipse cx="${cx - 0.5}" cy="${soilY - 19}" rx="3" ry="1.8" fill="${PALETTE.leafLight}" transform="rotate(-12 ${cx - 0.5} ${soilY - 19})" opacity="0.8"/>`;
    return s;
  }

  if (day === 3) {
    // sprout — two cotyledons on a stem
    const stemH = 22;
    s += `<path d="M ${cx} ${soilY} Q ${cx + 1} ${soilY - stemH * 0.5} ${cx} ${soilY - stemH}"
            stroke="${PALETTE.leafFresh}" stroke-width="2.2" fill="none" stroke-linecap="round"/>`;
    // left cotyledon
    s += `<ellipse cx="${cx - 9}" cy="${soilY - stemH - 1}" rx="10" ry="5" fill="${PALETTE.leafFresh}" transform="rotate(-22 ${cx - 9} ${soilY - stemH - 1})"/>`;
    s += `<ellipse cx="${cx - 11}" cy="${soilY - stemH - 3}" rx="6" ry="3" fill="${PALETTE.leafLight}" transform="rotate(-22 ${cx - 11} ${soilY - stemH - 3})" opacity="0.8"/>`;
    // right cotyledon
    s += `<ellipse cx="${cx + 9}" cy="${soilY - stemH - 1}" rx="10" ry="5" fill="${PALETTE.leafFresh}" transform="rotate(22 ${cx + 9} ${soilY - stemH - 1})"/>`;
    s += `<ellipse cx="${cx + 11}" cy="${soilY - stemH - 3}" rx="6" ry="3" fill="${PALETTE.leafLight}" transform="rotate(22 ${cx + 11} ${soilY - stemH - 3})" opacity="0.8"/>`;
    return s;
  }

  if (day === 5) {
    // cotyledons + emerging tiny true leaves on a longer stem
    const stemH = 42;
    s += `<path d="M ${cx} ${soilY} Q ${cx + 2} ${soilY - stemH * 0.5} ${cx + 1} ${soilY - stemH}"
            stroke="${PALETTE.leafSage}" stroke-width="2.6" fill="none" stroke-linecap="round"/>`;
    // cotyledons mid-stem (now slightly wilting hue)
    s += `<ellipse cx="${cx - 10}" cy="${soilY - 18}" rx="11" ry="5" fill="${PALETTE.leafSage}" transform="rotate(-30 ${cx - 10} ${soilY - 18})" opacity="0.9"/>`;
    s += `<ellipse cx="${cx + 10}" cy="${soilY - 18}" rx="11" ry="5" fill="${PALETTE.leafSage}" transform="rotate(30 ${cx + 10} ${soilY - 18})" opacity="0.9"/>`;
    // first true leaves at top
    s += `<ellipse cx="${cx - 6}" cy="${soilY - stemH - 2}" rx="7" ry="3.4" fill="${PALETTE.leafFresh}" transform="rotate(-18 ${cx - 6} ${soilY - stemH - 2})"/>`;
    s += `<ellipse cx="${cx + 7}" cy="${soilY - stemH - 1}" rx="7" ry="3.4" fill="${PALETTE.leafFresh}" transform="rotate(18 ${cx + 7} ${soilY - stemH - 1})"/>`;
    s += `<ellipse cx="${cx + 1}" cy="${soilY - stemH - 5}" rx="5" ry="3" fill="${PALETTE.leafLight}"/>`;
    return s;
  }

  if (day === 7) {
    // seedling — slim stem ~80px, 3-4 small leaves, cotyledons gone
    const stemH = 78;
    s += `<path d="M ${cx} ${soilY} Q ${cx - 2} ${soilY - stemH * 0.4} ${cx + 1} ${soilY - stemH * 0.7} Q ${cx + 3} ${soilY - stemH * 0.9} ${cx + 2} ${soilY - stemH}"
            stroke="${PALETTE.barkLight}" stroke-width="3.2" fill="none" stroke-linecap="round"/>`;
    // leaves alternating
    s += `<ellipse cx="${cx - 10}" cy="${soilY - 38}" rx="10" ry="4" fill="${PALETTE.leafSage}" transform="rotate(-22 ${cx - 10} ${soilY - 38})"/>`;
    s += `<ellipse cx="${cx + 11}" cy="${soilY - 54}" rx="10" ry="4" fill="${PALETTE.leafSage}" transform="rotate(22 ${cx + 11} ${soilY - 54})"/>`;
    s += `<ellipse cx="${cx - 9}" cy="${soilY - 68}" rx="9" ry="3.8" fill="${PALETTE.leafFresh}" transform="rotate(-26 ${cx - 9} ${soilY - 68})"/>`;
    // crown tuft
    s += cluster(cx + 2, soilY - stemH - 2, 14, { tone: 'fresh', saturation: 0.9, seed: 7 });
    return s;
  }

  if (day === 10) {
    // seedling+ — slightly thicker stem, two small foliage tufts
    const stemH = 118;
    s += `<path d="M ${cx} ${soilY}
                   Q ${cx - 4} ${soilY - 30} ${cx + 2} ${soilY - 60}
                   Q ${cx + 6} ${soilY - 90} ${cx + 3} ${soilY - stemH}"
            stroke="${PALETTE.barkLight}" stroke-width="4.2" fill="none" stroke-linecap="round"/>`;
    // a couple of side leaves
    s += `<ellipse cx="${cx - 12}" cy="${soilY - 50}" rx="9" ry="3.6" fill="${PALETTE.leafSage}" transform="rotate(-30 ${cx - 12} ${soilY - 50})"/>`;
    s += `<ellipse cx="${cx + 13}" cy="${soilY - 82}" rx="9" ry="3.6" fill="${PALETTE.leafSage}" transform="rotate(28 ${cx + 13} ${soilY - 82})"/>`;
    // small side cluster
    s += cluster(cx - 16, soilY - stemH + 18, 16, { tone: 'sage', saturation: 0.9, seed: 11 });
    // crown
    s += cluster(cx + 6, soilY - stemH - 2, 22, { tone: 'fresh', saturation: 1.0, seed: 12 });
    return s;
  }

  return s;
}

// Days 14+: real tree.
function renderTree(params) {
  const { day, clusters, leafSaturation = 1 } = params;
  const t = trunk(params);
  let s = t.svg;
  // Render clusters back-to-front (deeper/lower first, top/light last)
  const order = [...clusters].sort((a, b) => (a.z || 0) - (b.z || 0));
  s += `<g id="leaves">`;
  for (let i = 0; i < order.length; i++) {
    const c = order[i];
    const [ax, ay] = c.attach
      ? t.attachPoints[c.attach]
      : [c.cx ?? 300, c.cy ?? 250];
    const cx = ax + (c.dx || 0);
    const cy = ay + (c.dy || 0);
    s += cluster(cx, cy, c.size, {
      tone: c.tone || 'sage',
      saturation: leafSaturation * (c.sat ?? 1),
      seed: c.seed ?? i * 13,
    });
  }
  s += `</g>`;
  return s;
}

// ----- Top-level builder -----
function buildSVG(params) {
  const { day } = params;
  const body =
    day <= 10 ? renderEarly(day, params) : renderTree(params);

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 600" width="600" height="600">
  <title>Sober — Traditional bonsai, day ${String(day).padStart(3, '0')}</title>
  <desc>Anchor frame for the Traditional bonsai style. Pot baseline y=460. Generated from the parametric builder.</desc>
  ${pot()}
  ${rootsAndMoss(params)}
  ${body}
</svg>`;
}

// ----- Anchor parameter sets -----
// Each anchor is one row of the schedule with explicit cluster placements for character.

const ANCHORS = {
  0:   { day: 0 },
  1:   { day: 1 },
  3:   { day: 3 },
  5:   { day: 5 },
  7:   { day: 7 },
  10:  { day: 10 },

  14: {
    day: 14,
    trunkHeight: 0.34, trunkThickness: 0.22, trunkGnarl: 0,
    mossOnTrunk: 0, exposedRoots: 0,
    leafSaturation: 0.92,
    clusters: [
      { attach: 'crown',     size: 32, tone: 'fresh', seed: 1 },
      { attach: 'midLeft',   size: 18, tone: 'sage',  seed: 2 },
      { attach: 'midRight',  size: 16, tone: 'fresh', seed: 3 },
    ],
  },

  21: {
    day: 21,
    trunkHeight: 0.42, trunkThickness: 0.32, trunkGnarl: 0.05,
    mossOnTrunk: 0, exposedRoots: 0,
    leafSaturation: 0.95,
    clusters: [
      { attach: 'crown',      size: 40, tone: 'sage',  seed: 11 },
      { attach: 'midLeft',    size: 26, tone: 'fresh', seed: 12 },
      { attach: 'midRight',   size: 24, tone: 'sage',  seed: 13 },
    ],
  },

  30: {
    day: 30,
    trunkHeight: 0.5, trunkThickness: 0.42, trunkGnarl: 0.12,
    mossOnTrunk: 0, exposedRoots: 0.1,
    leafSaturation: 0.98,
    clusters: [
      { attach: 'crown',      size: 50, tone: 'sage',  seed: 21 },
      { attach: 'upperLeft',  size: 36, tone: 'fresh', seed: 22 },
      { attach: 'upperRight', size: 34, tone: 'sage',  seed: 23 },
      { attach: 'midLeft',    size: 26, tone: 'sage',  seed: 24 },
    ],
  },

  60: {
    day: 60,
    trunkHeight: 0.62, trunkThickness: 0.58, trunkGnarl: 0.28,
    mossOnTrunk: 0.05, exposedRoots: 0.25,
    leafSaturation: 1.0,
    clusters: [
      { attach: 'crown',      size: 62, tone: 'sage',  seed: 31 },
      { attach: 'upperLeft',  size: 50, tone: 'fresh', seed: 32 },
      { attach: 'upperRight', size: 46, tone: 'sage',  seed: 33 },
      { attach: 'midLeft',    size: 34, tone: 'sage',  seed: 34 },
      { attach: 'midRight',   size: 32, tone: 'fresh', seed: 35 },
      { attach: 'lowerRight', size: 26, tone: 'sage',  seed: 36 },
    ],
  },

  90: {
    day: 90,
    trunkHeight: 0.7, trunkThickness: 0.66, trunkGnarl: 0.45,
    mossOnTrunk: 0.18, exposedRoots: 0.42,
    leafSaturation: 1.0,
    clusters: [
      { attach: 'crown',      size: 70, tone: 'sage',  seed: 41 },
      { attach: 'upperLeft',  size: 56, tone: 'fresh', seed: 42 },
      { attach: 'upperRight', size: 52, tone: 'sage',  seed: 43 },
      { attach: 'midLeft',    size: 40, tone: 'sage',  seed: 44 },
      { attach: 'midRight',   size: 38, tone: 'fresh', seed: 45 },
      { attach: 'lowerRight', size: 32, tone: 'sage',  seed: 46 },
      { cx: 300, cy: 210,     size: 24, tone: 'fresh', seed: 47 },
    ],
  },

  180: {
    day: 180,
    trunkHeight: 0.78, trunkThickness: 0.78, trunkGnarl: 0.7,
    mossOnTrunk: 0.45, exposedRoots: 0.65,
    leafSaturation: 0.96,
    clusters: [
      { attach: 'crown',      size: 76, tone: 'sage',  seed: 51 },
      { attach: 'upperLeft',  size: 62, tone: 'fresh', seed: 52 },
      { attach: 'upperRight', size: 58, tone: 'sage',  seed: 53 },
      { attach: 'midLeft',    size: 46, tone: 'sage',  seed: 54 },
      { attach: 'midRight',   size: 42, tone: 'sage',  seed: 55 },
      { attach: 'lowerRight', size: 38, tone: 'sage',  seed: 56 },
      { cx: 308, cy: 202,     size: 28, tone: 'fresh', seed: 57 },
      // one subtle seasonal cluster — autumn tucked low, not a main mass
      { cx: 380, cy: 296,     size: 18, tone: 'autumn',seed: 58, sat: 0.8 },
    ],
  },

  365: {
    day: 365,
    trunkHeight: 0.84, trunkThickness: 0.9, trunkGnarl: 1.0,
    mossOnTrunk: 0.85, exposedRoots: 0.9,
    leafSaturation: 1.0,
    clusters: [
      { attach: 'crown',      size: 82, tone: 'sage',  seed: 61 },
      { attach: 'upperLeft',  size: 70, tone: 'fresh', seed: 62 },
      { attach: 'upperRight', size: 66, tone: 'sage',  seed: 63 },
      { attach: 'midLeft',    size: 52, tone: 'sage',  seed: 64 },
      { attach: 'midRight',   size: 48, tone: 'sage',  seed: 65 },
      { attach: 'lowerRight', size: 42, tone: 'sage',  seed: 66 },
      { cx: 314, cy: 196,     size: 32, tone: 'fresh', seed: 67 },
      // two restrained autumn flecks for seasonal interest
      { cx: 232, cy: 262,     size: 20, tone: 'autumn',seed: 68, sat: 0.85 },
      { cx: 390, cy: 232,     size: 16, tone: 'autumn',seed: 69, sat: 0.75 },
    ],
  },
};

if (typeof module !== 'undefined') {
  module.exports = { buildSVG, ANCHORS, PALETTE };
}
