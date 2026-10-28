// Renders the 1200×630 share image (public/og/default.png) with the locally installed Chrome, in the site's own fonts
// and with the logo drawn from branding/mark.json. Run `npm run fonts` first. The PNG is committed; re-run
// (`npm run og`) when the brand or the tagline changes.
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { chromium } from 'playwright-core'
import { ball, toneColors, trailPath, MARK } from '../src/lib/brand.ts'

const font = (name) => readFile(new URL(`../src/assets/fonts/${name}`, import.meta.url)).then((b) => b.toString('base64'))
const [regular, display] = await Promise.all([font('vazir-regular.woff2'), font('estedad-black-fa.woff2')])
const out = fileURLToPath(new URL('../public/og/default.png', import.meta.url))

const [ta, ba, tb, bb] = toneColors('reversed')
const a = ball(0)
const b = ball(180)
const mark = `<svg width="300" height="300" viewBox="0 0 100 100">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${MARK.tile.gradientFrom}"/><stop offset="1" stop-color="${MARK.tile.gradientTo}"/></linearGradient></defs>
  <rect width="100" height="100" rx="${MARK.tile.cornerRadius}" fill="url(#g)"/>
  <g transform="translate(50 50) scale(0.9) translate(-50 -50)">
    <path d="${trailPath(0)}" fill="${ta}"/><path d="${trailPath(180)}" fill="${tb}"/>
    <circle cx="${a.cx}" cy="${a.cy}" r="${a.r}" fill="${ba}"/><circle cx="${b.cx}" cy="${b.cy}" r="${b.r}" fill="${bb}"/>
  </g></svg>`

const html = `<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8"><style>
@font-face{font-family:V;src:url(data:font/woff2;base64,${regular}) format('woff2')}
@font-face{font-family:E;src:url(data:font/woff2;base64,${display}) format('woff2');font-weight:900}
*{margin:0;box-sizing:border-box}
html,body{width:1200px;height:630px;overflow:hidden}
.frame{width:1200px;height:630px;overflow:hidden;color:#fff;font-family:V,sans-serif;
  background:radial-gradient(760px 520px at 85% 20%,#1d7a5c,transparent 70%),#0B4C3A;
  display:flex;align-items:center;justify-content:space-between;padding:0 100px;position:relative}
.court{position:absolute;left:-120px;top:-60px;width:520px;height:760px;border:3px solid rgb(255 255 255/.08);transform:rotate(-14deg)}
.court:before{content:'';position:absolute;left:0;right:0;top:50%;border-top:3px solid rgb(255 255 255/.08)}
.court:after{content:'';position:absolute;top:0;bottom:0;left:50%;border-left:3px solid rgb(255 255 255/.08)}
h1{font:900 150px/1.05 E,V;letter-spacing:-.01em}
p{font-size:44px;margin-top:22px;color:#CCE6DD;line-height:1.5}
.url{display:inline-block;margin-top:34px;padding:8px 26px;border-radius:999px;background:#D9EF70;color:#0B4C3A;font-size:32px;font-weight:700;direction:ltr}
.mark{position:relative;filter:drop-shadow(0 30px 40px rgba(0,0,0,.35))}
</style></head><body><div class="frame">
<div class="court"></div>
<div style="position:relative"><h1>رالیتو</h1><p>هم‌بازی هم‌سطح برای تنیس، پدل،<br>بدمینتون و اسکواش</p><span class="url">rallyto.ir</span></div>
<div class="mark">${mark}</div>
</div></body></html>`

const browser = await chromium.launch({ channel: 'chrome', headless: true })
try {
  const page = await browser.newPage({ viewport: { width: 1200, height: 630 }, deviceScaleFactor: 1 })
  await page.setContent(html, { waitUntil: 'load' })
  await page.evaluate(() => document.fonts.ready)
  await page.screenshot({ path: out })
  console.log(`rendered ${out}`)
} finally {
  await browser.close()
}
