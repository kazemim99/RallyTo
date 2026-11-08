// Renders the images of the guides (public/guides/) with the locally installed Chrome, in the site's own fonts. They are
// drawn, not photographs, so no stock picture or invented player stands in for a real one. Run `npm run fonts` first.
// The PNGs are committed; re-run (`npm run guide-images`) when one of them changes. Sizes are the ones in src/data/guides.ts.
import { mkdir, readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { chromium } from 'playwright-core'

const font = (name) => readFile(new URL(`../src/assets/fonts/${name}`, import.meta.url)).then((b) => b.toString('base64'))
const [regular, display] = await Promise.all([font('vazir-regular.woff2'), font('estedad-black-fa.woff2')])
const guides = new URL('../public/guides/', import.meta.url)

const BASE = `
@font-face{font-family:V;src:url(data:font/woff2;base64,${regular}) format('woff2')}
@font-face{font-family:E;src:url(data:font/woff2;base64,${display}) format('woff2');font-weight:900}
*{margin:0;box-sizing:border-box}
body{font-family:V,sans-serif;overflow:hidden}
.frame{position:relative;overflow:hidden}
`

const card = (title, value, icon) => `<div class="card"><div class="icon">${icon}</div><h2>${title}</h2><p>${value}</p></div>`
const svg = (body) => `<svg viewBox="0 0 24 24" width="52" height="52" fill="none" stroke="#0B4C3A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${body}</svg>`

const levelTimeClub = {
  file: 'find-partner/level-time-club.png',
  width: 1200,
  height: 630,
  html: `<style>${BASE}
.frame{width:1200px;height:630px;color:#fff;padding:64px 72px;background:#0B4C3A}
h1{position:relative;font:900 66px/1.3 E,V}
.lead{position:relative;margin-top:10px;font-size:34px;color:#CCE6DD}
.cards{position:relative;display:grid;grid-template-columns:repeat(3,1fr);gap:24px;margin-top:44px}
.card{padding:28px;border-radius:24px;background:#fff;color:#13211D}
.icon{display:grid;place-items:center;width:84px;height:84px;margin-bottom:16px;border-radius:50%;background:#D9EF70}
.card h2{font:900 44px/1.4 E,V;color:#0B4C3A}
.card p{margin-top:4px;font-size:29px;line-height:1.5;color:#56635F}
</style><div class="frame">
<h1>هم‌بازی هم‌سطح چطور پیدا می‌شود؟</h1>
<p class="lead">سه چیز باید با هم جور شود</p>
<div class="cards">
${card('سطح', 'جایی که واقعاً بازی می‌کنی', svg('<path d="M5 20v-5M12 20V10M19 20V4"/>'))}
${card('ساعت', 'روز و بازه‌ی ساعتی مشخص', svg('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'))}
${card('باشگاه', 'جایی که واقعاً تا آنجا می‌روی', svg('<path d="M12 21s7-6.2 7-11.5A7 7 0 0 0 5 9.5C5 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>'))}
</div></div>`,
}

const row = (label, value) => `<div class="row"><span class="label">${label}</span><span class="value">${value}</span></div>`

const goodMessage = {
  file: 'find-partner/good-message.png',
  width: 1200,
  height: 840,
  html: `<style>${BASE}
.frame{width:1200px;height:840px;padding:48px 64px;background:#F4F2EC;color:#13211D}
.head{display:flex;align-items:center;justify-content:space-between;margin-bottom:28px}
h1{font:900 54px/1.3 E,V;color:#0B4C3A}
.tag{padding:4px 26px;border-radius:999px;background:#13211D;color:#fff;font-size:32px}
.box{border:1.5px solid #E0DCD1;border-radius:28px;background:#fff;padding:12px 40px}
.row{display:flex;align-items:center;gap:32px;height:88px;border-bottom:1.5px solid #E0DCD1}
.row:last-child{border-bottom:0}
.label{flex:none;width:240px;padding:4px 0;border-radius:14px;background:#E7F3EF;color:#0B4C3A;font-size:34px;font-weight:700;text-align:center}
.value{font-size:40px}
</style><div class="frame">
<div class="head"><h1>پیامی که جواب می‌گیرد</h1><span class="tag">نمونه</span></div>
<div class="box">
${row('ورزش و فرمت', 'تنیس انفرادی')}
${row('باشگاه', '[نام باشگاه]')}
${row('زمان', 'شنبه ۱۹ تا ۲۰:۳۰')}
${row('سطح', 'سطحم متوسط؛ دنبال متوسط یا پیشرفته')}
${row('زمین', 'رزرو شده')}
${row('هزینه', 'نصف‌نصف')}
${row('هدف', 'یک ست کامل با امتیاز')}
</div></div>`,
}

// The court keeps padel's real proportions (20×10 m), as the hero's does; players use the same two colours and the same
// dashed place still open.
const open = (x, y) => `<g transform="translate(${x} ${y})"><circle r="34" fill="rgb(0 0 0/.16)" stroke="#fff" stroke-width="5" stroke-dasharray="12 9"/><path d="M-14 0h28M0 -14v28" stroke="#fff" stroke-width="6" stroke-linecap="round"/></g>`
const player = (x, y) => `<circle cx="${x}" cy="${y}" r="32" fill="#fff" stroke="#0B4C3A" stroke-width="6"/>`

const padelFour = {
  file: 'find-partner/padel-four-players.png',
  width: 1200,
  height: 720,
  html: `<style>${BASE}
.frame{width:1200px;height:720px;background:#F4F2EC;color:#13211D;padding:40px 64px}
.legend{display:flex;justify-content:center;gap:64px;margin-top:28px;font-size:38px}
.legend span{display:flex;align-items:center;gap:16px}
.dot{width:40px;height:40px;border-radius:50%;background:#fff;border:5px solid #0B4C3A}
.gap{width:40px;height:40px;border-radius:50%;background:#2F6AAA;border:4px dashed #fff;outline:3px solid #2F6AAA}
</style><div class="frame">
<svg width="1072" height="536" viewBox="0 0 1072 536" style="display:block">
  <rect width="1072" height="536" rx="28" fill="#2F6AAA"/>
  <g fill="none" stroke="#fff" stroke-width="5">
    <rect x="76" y="38" width="920" height="460" fill="rgb(255 255 255/.07)"/>
    <path d="M216 38v460M856 38v460M216 268h640"/>
  </g>
  <path d="M536 22v492" stroke="#fff" stroke-width="9" stroke-linecap="round"/>
  <path d="M68 30h8v476h-8zM996 30h8v476h-8zM68 30h170v8H68zM68 498h170v8H68zM834 30h170v8H834zM834 498h170v8H834z" fill="rgb(255 255 255/.6)"/>
  ${player(790, 150)}${player(790, 386)}${open(282, 150)}${open(282, 386)}
</svg>
<div class="legend"><span><i class="dot"></i>تو و یک دوستت</span><span><i class="gap"></i>دو جای خالی برای پیدا کردن</span></div>
</div>`,
}

// A measurement on a drawing: a line with end ticks and its value on a chip over the middle. Vertical when x1 === x2.
const measure = (x1, y1, x2, y2, label, chip = 150) => {
  const v = x1 === x2
  const ticks = v ? `M${x1 - 12} ${y1}h24M${x2 - 12} ${y2}h24` : `M${x1} ${y1 - 12}v24M${x2} ${y2 - 12}v24`
  const [cx, cy] = [(x1 + x2) / 2, (y1 + y2) / 2]
  return `<g><path d="M${x1} ${y1}L${x2} ${y2}${ticks}" stroke="#13211D" stroke-width="3"/>
<rect x="${cx - chip / 2}" y="${cy - 20}" width="${chip}" height="40" rx="20" fill="#13211D"/>
<text x="${cx}" y="${cy + 10}" text-anchor="middle" fill="#fff" font-size="27" font-weight="700">${label}</text></g>`
}
const DRAWING = `.frame{background:#F4F2EC;color:#13211D}
svg{display:block;font-family:V,sans-serif;direction:rtl}
h1{font:900 46px/1.3 E,V;color:#0B4C3A}`

// The tennis court in its real proportions: 23.77 m long on 800 px (33.66 px a metre), so 10.97 m wide on 369 px, the
// singles sidelines 46 px inside and the service lines 215 px from the net. The space around it is not to scale.
const tennisCourt = {
  file: 'tennis-court/dimensions.png',
  width: 1200,
  height: 630,
  html: `<style>${BASE}${DRAWING}
.frame{width:1200px;height:630px}
h1{position:absolute;top:18px;right:36px}
</style><div class="frame">
<h1>ابعاد زمین تنیس</h1>
<svg width="1200" height="630" viewBox="0 0 1200 630">
  <rect x="70" y="125" width="880" height="449" rx="20" fill="#2F6AAA"/>
  <rect x="110" y="165" width="800" height="369" fill="#3D7FC2"/>
  <g fill="none" stroke="#fff" stroke-width="4">
    <rect x="110" y="165" width="800" height="369"/>
    <path d="M110 211h800M110 488h800M295 211v277M725 211v277M295 349.5h430M110 349.5h12M898 349.5h12"/>
  </g>
  <path d="M510 134v431" stroke="#fff" stroke-width="7" stroke-linecap="round"/>
  <circle cx="510" cy="134" r="7" fill="#13211D"/><circle cx="510" cy="565" r="7" fill="#13211D"/>
  ${measure(110, 600, 910, 600, '۲۳٫۷۷ متر', 160)}
  ${measure(295, 100, 510, 100, '۶٫۴۰ متر', 130)}
  <text x="720" y="108" text-anchor="middle" font-size="26" fill="#13211D">تور: ۹۱٫۴ سانتی‌متر در وسط</text>
  <path d="M975 165v369M963 165h24M963 534h24" stroke="#13211D" stroke-width="3"/>
  <path d="M1010 211v277M998 211h24M998 488h24" stroke="#13211D" stroke-width="3"/>
  <!-- In right-to-left text, «start» is the right edge. -->
  <text x="1170" y="250" text-anchor="start" font-size="27" font-weight="700" fill="#13211D">دونفره</text>
  <text x="1170" y="285" text-anchor="start" font-size="27" fill="#13211D">۱۰٫۹۷ متر</text>
  <text x="1170" y="420" text-anchor="start" font-size="27" font-weight="700" fill="#13211D">یک‌نفره</text>
  <text x="1170" y="455" text-anchor="start" font-size="27" fill="#13211D">۸٫۲۳ متر</text>
</svg></div>`,
}

// The padel court as in padelFour (20×10 m on 920×460 px, 46 px a metre): service lines 6.95 m (320 px) from the net,
// glass at both ends and along the sides next to them, mesh along the rest of the sides.
const padelCourt = {
  file: 'padel/court.png',
  width: 1200,
  height: 720,
  html: `<style>${BASE}${DRAWING}
.frame{width:1200px;height:720px;padding:24px 64px}
.legend{display:flex;justify-content:center;gap:48px;margin-top:6px;font-size:30px}
.legend span{display:flex;align-items:center;gap:14px}
.glass{width:44px;height:14px;border-radius:4px;background:#8FB6DE}
.mesh{width:44px;height:14px;border-radius:4px;background:#2F6AAA repeating-linear-gradient(90deg,#D9EF70 0 10px,transparent 10px 17px) center/100% 5px no-repeat}
</style><div class="frame">
<h1>ابعاد زمین پدل</h1>
<svg width="1072" height="560" viewBox="0 -24 1072 560">
  <rect x="0" y="0" width="1072" height="536" rx="28" fill="#2F6AAA"/>
  <g fill="none" stroke="#fff" stroke-width="5">
    <rect x="76" y="38" width="920" height="460" fill="rgb(255 255 255/.07)"/>
    <path d="M216 38v460M856 38v460M216 268h640"/>
  </g>
  <path d="M536 22v492" stroke="#fff" stroke-width="9" stroke-linecap="round"/>
  <g stroke="#D9EF70" stroke-width="6" stroke-dasharray="14 10" fill="none"><path d="M262 34h548M262 502h548"/></g>
  <path d="M64 30h12v476H64zM996 30h12v476h-12zM64 30h198v10H64zM64 496h198v10H64zM810 30h198v10H810zM810 496h198v10H810z" fill="#8FB6DE"/>
  ${measure(76, -4, 996, -4, '۲۰ متر', 120)}
  ${measure(536, 140, 856, 140, '۶٫۹۵ متر', 130)}
  ${measure(146, 38, 146, 498, '۱۰ متر', 100)}
</svg>
<div class="legend"><span><i class="glass"></i>دیوار شیشه‌ای یا بتنی</span><span><i class="mesh"></i>توری فلزی</span><span>تور: ۸۸ سانتی‌متر در وسط</span></div>
</div>`,
}

const browser = await chromium.launch({ channel: 'chrome', headless: true })
try {
  for (const image of [levelTimeClub, goodMessage, padelFour, tennisCourt, padelCourt]) {
    const out = new URL(image.file, guides)
    await mkdir(new URL('.', out), { recursive: true })
    const page = await browser.newPage({ viewport: { width: image.width, height: image.height }, deviceScaleFactor: 1 })
    await page.setContent(`<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8"></head><body>${image.html}</body></html>`, { waitUntil: 'load' })
    await page.evaluate(() => document.fonts.ready)
    await page.screenshot({ path: fileURLToPath(out) })
    await page.close()
    console.log(`rendered ${image.file}`)
  }
} finally {
  await browser.close()
}
