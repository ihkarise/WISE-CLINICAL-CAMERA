/*
 * WISE Clinical Camera — website behaviour.
 *
 * Deliberately small and dependency-free. Three jobs:
 *   1. Mobile navigation toggle.
 *   2. Reveal-on-scroll (skipped entirely under prefers-reduced-motion).
 *   3. Populate download links / version from config/*.json — the single place
 *      a non-developer edits. If the fetch fails, the HTML defaults (which point
 *      at the GitHub releases page) remain, so the page is never left dead.
 */
(function () {
  'use strict';

  // ---- 1. Mobile nav ----
  var toggle = document.querySelector('.nav-toggle');
  var menu = document.getElementById('mobile-menu');
  if (toggle && menu) {
    toggle.addEventListener('click', function () {
      var open = menu.classList.toggle('open');
      toggle.setAttribute('aria-expanded', String(open));
    });
    menu.querySelectorAll('a').forEach(function (a) {
      a.addEventListener('click', function () {
        menu.classList.remove('open');
        toggle.setAttribute('aria-expanded', 'false');
      });
    });
  }

  // ---- 2. Reveal on scroll ----
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var reveals = document.querySelectorAll('.reveal');
  if (reduce || !('IntersectionObserver' in window)) {
    reveals.forEach(function (el) { el.classList.add('in'); });
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
      });
    }, { rootMargin: '0px 0px -10% 0px', threshold: 0.08 });
    reveals.forEach(function (el) { io.observe(el); });
  }

  // ---- year ----
  var yr = document.getElementById('year');
  if (yr) { yr.textContent = String(new Date().getFullYear()); }

  // ---- 3. Config-driven download + links ----
  function setText(id, value) {
    var el = document.getElementById(id);
    if (el && value != null && value !== '') { el.textContent = value; }
  }
  function setHref(id, value) {
    var el = document.getElementById(id);
    if (el && value) { el.setAttribute('href', value); }
  }
  function getJSON(url) {
    return fetch(url, { cache: 'no-cache' }).then(function (r) {
      if (!r.ok) { throw new Error(url + ' ' + r.status); }
      return r.json();
    });
  }

  Promise.all([
    getJSON('config/downloads.json').catch(function () { return null; }),
    getJSON('config/site.json').catch(function () { return null; })
  ]).then(function (res) {
    var dl = res[0];
    var site = res[1];

    if (site) {
      var u = site.urls || {};
      setHref('foot-github', u.repo);
      setHref('foot-docs', u.documentation);
      setHref('foot-support', u.support);
      setHref('foot-privacy', u.privacy);
      setHref('watch-releases', u.releases);
    }

    if (dl) {
      var releases = dl.releasesUrl || (site && site.urls && site.urls.releases);
      setText('meta-version', dl.version);
      setText('meta-channel', dl.channel);
      setText('dl-android-version', dl.version);
      setText('dl-android-channel', dl.channel);
      if (dl.channelNote) { setText('channel-banner-text', dl.channelNote); }

      // Android
      var a = dl.android || {};
      setText('dl-android-min', a.minVersion);
      var androidHref = a.available && a.url ? a.url : releases;
      setHref('dl-android', androidHref);
      setHref('cta-android', androidHref);
      if (a.available && a.url) {
        setText('android-status', 'Latest ' + (dl.channel || '') + ' build ready to install.');
        setText('cta-android-note', (dl.channel || 'Preview') + ' build');
      } else {
        setText('android-status', a.note || 'Preview build coming to the releases page.');
        setText('cta-android-label', 'Get the Android build');
        setText('cta-android-note', 'Preview · via GitHub Releases');
      }

      // iOS
      var i = dl.ios || {};
      setText('dl-ios-min', i.minVersion);
      var iosCta = document.getElementById('cta-ios');
      var iosBtn = document.getElementById('dl-ios');
      if (i.available && i.url) {
        setHref('dl-ios', i.url);
        setHref('cta-ios', i.url);
        setText('dl-ios', i.label || 'Download on the App Store');
        setText('cta-ios-label', i.label || 'Download for iOS');
        setText('ios-status', 'Available now.');
        if (iosBtn) { iosBtn.classList.remove('btn-ghost-dark'); iosBtn.classList.add('btn-on-dark'); iosBtn.removeAttribute('aria-disabled'); iosBtn.removeAttribute('tabindex'); }
        if (iosCta) { iosCta.removeAttribute('aria-disabled'); }
      } else {
        setText('ios-status', i.note || 'No iOS distribution link exists yet.');
        setText('cta-ios-label', 'iOS — Coming soon');
        setText('dl-ios', 'iOS — Coming soon');
        if (iosCta) { iosCta.setAttribute('aria-disabled', 'true'); }
        if (iosBtn) { iosBtn.setAttribute('aria-disabled', 'true'); iosBtn.setAttribute('tabindex', '-1'); }
      }
    }
  });
})();
