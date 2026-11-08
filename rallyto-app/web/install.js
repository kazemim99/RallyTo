// The web app's install prompt, and the end of its loading screen.
// Android (Chrome, Samsung Internet, Edge): the browser lets the page ask, so «نصب» installs it in one tap, and the APK
// is offered beside it. iPhone and iPad: no browser there lets a page install itself, so the prompt shows the two taps
// that do it (Share, then Add to Home Screen). Nothing shows inside the installed app, nor for a week after «✕».
(function () {
  'use strict';

  var DISMISSED_KEY = 'rallyto.install.dismissedAt';
  var WEEK = 7 * 24 * 60 * 60 * 1000;
  var SHOW_AFTER_MS = 2500;

  // The loading screen goes once Flutter has drawn.
  window.addEventListener('flutter-first-frame', function () {
    var boot = document.getElementById('boot');
    if (!boot) return;
    boot.classList.add('done');
    setTimeout(function () { boot.remove(); }, 250);
  });

  var standalone = window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
  if (standalone) return;

  function dismissedRecently() {
    try {
      var at = Number(localStorage.getItem(DISMISSED_KEY));
      return at > 0 && Date.now() - at < WEEK;
    } catch (e) {
      return false;
    }
  }
  if (dismissedRecently()) return;

  var ua = navigator.userAgent;
  // iPadOS reports itself as a Mac; a touch screen tells them apart.
  var ios = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  var android = /Android/.test(ua);

  var $ = function (id) { return document.getElementById(id); };
  var box = $('install');
  var deferred = null;

  function show() {
    if (!box.hidden) return;
    box.hidden = false;
    box.classList.add('entering');
    requestAnimationFrame(function () {
      requestAnimationFrame(function () { box.classList.remove('entering'); });
    });
  }

  function hide(remember) {
    box.hidden = true;
    if (remember) {
      try { localStorage.setItem(DISMISSED_KEY, String(Date.now())); } catch (e) { /* private mode: ask again next time */ }
    }
  }

  $('install-close').addEventListener('click', function () { hide(true); });

  if (ios) {
    $('install-body').textContent = 'با نصب، رالیتو مثل یک اپ از صفحه‌ی اصلی گوشی باز می‌شود.';
    $('install-steps').hidden = false;
    setTimeout(show, SHOW_AFTER_MS);
    return;
  }

  if (android) $('install-apk').hidden = false;

  // Chromium browsers offer the install when the page qualifies; keep the event and ask on the player's tap.
  window.addEventListener('beforeinstallprompt', function (event) {
    event.preventDefault();
    deferred = event;
    $('install-body').textContent = 'یک ضربه و رالیتو مثل یک اپ روی صفحه‌ی اصلی‌ات می‌نشیند.';
    $('install-go').hidden = false;
    setTimeout(show, SHOW_AFTER_MS);
  });

  $('install-go').addEventListener('click', function () {
    if (!deferred) return;
    var prompt = deferred;
    deferred = null;
    prompt.prompt();
    prompt.userChoice.then(function (choice) {
      if (choice.outcome === 'accepted') hide(false);
    });
  });

  window.addEventListener('appinstalled', function () { hide(false); });

  // An Android browser that never offers the install (some in-app browsers) still gets the APK.
  if (android) {
    setTimeout(function () {
      if (deferred || !box.hidden) return;
      $('install-body').textContent = 'نسخه‌ی اندروید رالیتو را مستقیم دانلود و نصب کن.';
      show();
    }, SHOW_AFTER_MS + 4000);
  }
})();
