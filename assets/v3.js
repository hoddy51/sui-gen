/* ============================================================
   SUI-GEN v3 — shared scripts
   全ページ共通。各機能は対象要素が存在するページでのみ動く。
   rAF + IntersectionObserver のみ（外部ライブラリなし）。
   prefers-reduced-motion で静的化。
============================================================ */
(function(){
  'use strict';
  var REDUCED = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---- 1. Header scroll state / すりガラス層 ---- */
  var header = document.getElementById('header');
  var glass = document.getElementById('glass');
  function onScroll(){
    var y = window.scrollY || window.pageYOffset;
    if (header) { header.classList.toggle('is-scrolled', y > 40); }
    /* すりガラス: Hero表示中は blur(0)、通過しはじめたら blur(28px) */
    if (glass) { glass.classList.toggle('is-frosted', y > window.innerHeight * 0.42); }
  }
  window.addEventListener('scroll', onScroll, {passive:true});
  onScroll();

  /* ---- 2. Hero slider（クロスフェード + Ken Burns 7s） ---- */
  var slides = Array.prototype.slice.call(document.querySelectorAll('.hero-slider .slide'));
  var dots = Array.prototype.slice.call(document.querySelectorAll('#pager .dot'));
  var cur = 0, timer = null, booted = false;
  function go(n){
    slides[cur].classList.remove('is-active');
    dots[cur] && dots[cur].classList.remove('is-current');
    cur = (n + slides.length) % slides.length;
    slides[cur].classList.add('is-active');
    dots[cur] && dots[cur].classList.add('is-current');
  }
  function play(){
    if (REDUCED || slides.length < 2) return;
    timer = window.setInterval(function(){ go(cur + 1); }, 7000);
  }
  dots.forEach(function(d){
    d.addEventListener('click', function(){
      if (!booted) { return; }
      if (timer) { window.clearInterval(timer); }
      go(parseInt(d.getAttribute('data-slide'), 10));
      play();
    });
  });
  /* 初回スライドの is-active / is-current はHTML初期値で持たせず、
     描画確定後（ダブルrAF）に付与する。初期スタイルとして適用されると
     transitionが走らず、最初の7秒が「ズーム済み静止画＋満タンのバー」に
     なってしまうため（Ken Burns / プログレスバーを初回から発火させる） */
  window.requestAnimationFrame(function(){
    window.requestAnimationFrame(function(){
      booted = true;
      if (slides[0]) { slides[0].classList.add('is-active'); }
      if (dots[0]) { dots[0].classList.add('is-current'); }
      /* Hero英字コピーの単語ごと立ち上がりをロード時に発火 */
      document.body.classList.add('is-loaded');
      play();
    });
  });

  /* ---- 2b. セクション見出しの文字ごとライズ
          .js-chars のテキストノードを単語(.chw)>文字(.ch)spanに分割（<em>/<br>は保持）。
          観察は既存の .js-inview 機構に相乗り（is-visible で発火）。
          REDUCED時は分割しない＝静的表示 ---- */
  if (!REDUCED) {
    Array.prototype.slice.call(document.querySelectorAll('.js-chars')).forEach(function(root){
      var ci = 0;
      (function walk(node){
        Array.prototype.slice.call(node.childNodes).forEach(function(child){
          if (child.nodeType === 3) {
            var frag = document.createDocumentFragment();
            child.nodeValue.split(/(\s+)/).forEach(function(seg){
              if (!seg) { return; }
              if (/^\s+$/.test(seg)) { frag.appendChild(document.createTextNode(seg)); return; }
              var word = document.createElement('span');
              word.className = 'chw';
              Array.prototype.forEach.call(seg, function(c){
                var s = document.createElement('span');
                s.className = 'ch';
                s.style.setProperty('--ci', String(ci++));
                s.textContent = c;
                word.appendChild(s);
              });
              frag.appendChild(word);
            });
            node.replaceChild(frag, child);
          } else if (child.nodeType === 1 && child.tagName !== 'BR') {
            walk(child);
          }
        });
      })(root);
    });
  }

  /* ---- 3. スクロール出現（IntersectionObserver / data-inview-margin対応） ---- */
  var inviewEls = Array.prototype.slice.call(document.querySelectorAll('.js-inview'));
  if (REDUCED || !('IntersectionObserver' in window)) {
    inviewEls.forEach(function(el){ el.classList.add('is-visible'); });
  } else {
    var groups = {};
    inviewEls.forEach(function(el){
      var m = el.getAttribute('data-inview-margin') || '0px 0px -12% 0px';
      if (!groups[m]) {
        groups[m] = new IntersectionObserver(function(entries, obs){
          entries.forEach(function(e){
            if (e.isIntersecting) { e.target.classList.add('is-visible'); obs.unobserve(e.target); }
          });
        }, {rootMargin: m, threshold: 0.08});
      }
      groups[m].observe(el);
    });
  }

  /* ---- 4. スクロール連動エンジン
          パララックス（data-parallax）/ 装飾円の PCのみ mousemove 微追従（data-mouse）/
          ゴースト文字（#bizGhost）の低速横ドリフト / 合流ライン（#bizLines）のスクロール連動描画。
          すべて rAF + lerp（passiveリスナー） ---- */
  var pEls = Array.prototype.slice.call(document.querySelectorAll('[data-parallax]')).map(function(el){
    return {el: el, sp: parseFloat(el.getAttribute('data-parallax')) || 0,
            mf: parseFloat(el.getAttribute('data-mouse')) || 0, top: 0, h: 1};
  });
  var ghost = document.getElementById('bizGhost');
  var svcSec = document.getElementById('service');
  var flowWrap = document.getElementById('bizFlow');
  var flowSvg = document.getElementById('bizLines');
  var pathA = document.getElementById('flowPathA');
  var pathB = document.getElementById('flowPathB');
  var svcTop = 0, svcH = 1, flowTop = 0, flowH = 1;
  function clamp01(v){ return v < 0 ? 0 : (v > 1 ? 1 : v); }

  /* 合流ライン: Step円の実座標から橙/緑の2パスを構築（pathLength=1 基準でdash描画）。
     REDUCED時も構築だけは行い、CSSの stroke-dashoffset:0 で全線を静的表示する */
  function buildFlow(){
    if (!flowWrap || !flowSvg) { return; }
    var y = window.scrollY || window.pageYOffset;
    var wr = flowWrap.getBoundingClientRect();
    flowTop = wr.top + y; flowH = Math.max(1, wr.height);
    if (svcSec) {
      var sr = svcSec.getBoundingClientRect();
      svcTop = sr.top + y; svcH = Math.max(1, sr.height);
    }
    flowSvg.setAttribute('viewBox', '0 0 ' + Math.max(1, Math.round(wr.width)) + ' ' + Math.max(1, Math.round(wr.height)));
    var icons = flowWrap.querySelectorAll('.biz-step__icon');
    if (icons.length < 3 || !pathA || !pathB) { return; }
    var c = [];
    for (var i = 0; i < 3; i++) {
      var r = icons[i].getBoundingClientRect();
      c.push({x: r.left - wr.left + r.width / 2, y: r.top - wr.top + r.height / 2, r: r.width / 2});
    }
    var bow = Math.min(76, c[0].r * 1.7);
    /* 橙の線: Step1の円の下から左に膨らみつつ Step3 の円の上端へ合流 */
    pathA.setAttribute('d',
      'M' + c[0].x.toFixed(1) + ' ' + (c[0].y + c[0].r + 8).toFixed(1) +
      ' C ' + (c[0].x - bow).toFixed(1) + ' ' + (c[0].y + (c[2].y - c[0].y) * 0.38).toFixed(1) +
      ', ' + (c[2].x - bow).toFixed(1) + ' ' + (c[2].y - (c[2].y - c[0].y) * 0.2).toFixed(1) +
      ', ' + c[2].x.toFixed(1) + ' ' + (c[2].y - c[2].r - 8).toFixed(1));
    /* 緑の線: Step2の円の下から右に膨らみつつ Step3 の円の上端へ合流（混色はStep3円のグラデが受ける） */
    pathB.setAttribute('d',
      'M' + c[1].x.toFixed(1) + ' ' + (c[1].y + c[1].r + 8).toFixed(1) +
      ' C ' + (c[1].x + bow).toFixed(1) + ' ' + (c[1].y + (c[2].y - c[1].y) * 0.45).toFixed(1) +
      ', ' + (c[2].x + bow).toFixed(1) + ' ' + (c[2].y - (c[2].y - c[1].y) * 0.3).toFixed(1) +
      ', ' + c[2].x.toFixed(1) + ' ' + (c[2].y - c[2].r - 8).toFixed(1));
  }
  function measure(){
    var y = window.scrollY || window.pageYOffset;
    pEls.forEach(function(o){
      o.el.style.transform = '';
      var r = o.el.getBoundingClientRect();
      o.top = r.top + y; o.h = r.height;
    });
    buildFlow();
  }
  window.addEventListener('resize', measure);
  window.addEventListener('load', measure);
  if (document.fonts && document.fonts.ready) { document.fonts.ready.then(measure); }
  measure();

  if (!REDUCED) {
    var targetY = window.scrollY, curY = targetY;
    var mTX = 0, mTY = 0, mX = 0, mY = 0;
    var fineMQ = window.matchMedia('(min-width:1025px) and (pointer:fine)');
    var sync = function(){ targetY = window.scrollY || window.pageYOffset; };
    window.addEventListener('scroll', sync, {passive:true});
    window.addEventListener('wheel', sync, {passive:true});
    /* PCのみ: 装飾円の mousemove 微追従（transform数px） */
    window.addEventListener('mousemove', function(e){
      if (!fineMQ.matches) { mTX = 0; mTY = 0; return; }
      mTX = (e.clientX / window.innerWidth) * 2 - 1;
      mTY = (e.clientY / window.innerHeight) * 2 - 1;
    }, {passive:true});
    (function raf(){
      curY += (targetY - curY) * 0.085;
      mX += (mTX - mX) * 0.06;
      mY += (mTY - mY) * 0.06;
      var vh = window.innerHeight;
      pEls.forEach(function(o){
        var off = (curY + vh / 2 - (o.top + o.h / 2)) * o.sp;
        var tx = o.mf ? mX * o.mf : 0;
        var ty = off + (o.mf ? mY * o.mf * 0.6 : 0);
        o.el.style.transform = 'translate3d(' + tx.toFixed(2) + 'px,' + ty.toFixed(2) + 'px,0)';
      });
      /* ゴースト文字: Serviceセクションの進捗で低速横ドリフト */
      if (ghost) {
        var gp = clamp01((curY + vh - svcTop) / (svcH + vh));
        ghost.style.transform = 'translate3d(' + (4 - gp * 22).toFixed(2) + 'vw,0,0)';
      }
      /* 合流ライン: スクロール進捗 → stroke-dashoffset（pathLength=1 基準）。
         緑の線(B)は橙の線(A)よりわずかに遅れて描画され、Step3で合流する */
      if (pathA && pathB) {
        var fp = clamp01((curY + vh * 0.82 - flowTop) / (flowH * 0.95));
        pathA.style.strokeDashoffset = String((1.015 * (1 - fp)).toFixed(4));
        pathB.style.strokeDashoffset = String((1.015 * (1 - clamp01((fp - 0.12) / 0.88))).toFixed(4));
      }
      window.requestAnimationFrame(raf);
    })();
  }

  /* ---- 4b. 数値カウントアップ（.js-count / inview発火）
          HTML初期値=最終値のため、REDUCED・IO非対応・JS無効時はそのまま正しく表示される ---- */
  var countEls = Array.prototype.slice.call(document.querySelectorAll('.js-count'));
  var runCount = function(el){
    var to = parseInt(el.getAttribute('data-count-to'), 10) || 0;
    var from = to >= 1000 ? to - 60 : 0;
    var t0 = null, dur = 1400;
    var stepFn = function(ts){
      if (t0 === null) { t0 = ts; }
      var p = Math.min(1, (ts - t0) / dur);
      var e = 1 - Math.pow(1 - p, 3);
      el.textContent = String(Math.round(from + (to - from) * e));
      if (p < 1) { window.requestAnimationFrame(stepFn); }
    };
    window.requestAnimationFrame(stepFn);
  };
  if (countEls.length && !REDUCED && 'IntersectionObserver' in window) {
    var countObs = new IntersectionObserver(function(entries, obs){
      entries.forEach(function(e){
        if (e.isIntersecting) { obs.unobserve(e.target); runCount(e.target); }
      });
    }, {threshold: 0.5});
    countEls.forEach(function(el){ countObs.observe(el); });
  }

  /* ---- 5. Contact form（fetch → POST /api/contact / JSON） ---- */
  var form = document.querySelector('.contact-form');
  if (form) {
    var statusEl = form.querySelector('.cf-status');
    var submitBtn = form.querySelector('button[type="submit"]');
    var setStatus = function(html, cls){
      if (!statusEl) { return; }
      statusEl.innerHTML = html;
      statusEl.className = 'cf-status' + (cls ? ' ' + cls : '');
    };
    form.addEventListener('submit', function(e){
      e.preventDefault();
      var typeEl = form.querySelector('input[name="inquiry-type"]:checked');
      var val = function(sel){
        var f = form.querySelector(sel);
        return f ? f.value.trim() : '';
      };
      var payload = {
        type: typeEl ? typeEl.value : '',
        name: val('input[name="name"]'),
        org: val('input[name="org"]'),
        email: val('input[name="email"]'),
        message: val('textarea[name="message"]')
      };
      if (!payload.name || !payload.email || !payload.message) {
        setStatus('お名前・メールアドレス・お問い合わせ内容をご入力ください。', 'is-error');
        return;
      }
      if (submitBtn) { submitBtn.disabled = true; }
      setStatus('送信しています…', '');
      fetch('/api/contact', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(payload)
      }).then(function(res){
        if (!res.ok) { throw new Error('HTTP ' + res.status); }
        form.reset();
        setStatus('お問い合わせを受け付けました。担当者より折り返しご連絡いたします。', 'is-success');
      }).catch(function(){
        setStatus('送信に失敗しました。お手数ですが <a href="mailto:contact@sui-gen.jp">contact@sui-gen.jp</a> 宛に直接メールでお問い合わせください。', 'is-error');
      }).then(function(){
        if (submitBtn) { submitBtn.disabled = false; }
      });
    });
  }

  /* ---- 6. Mobile nav ---- */
  var hb = document.querySelector('.hamburger');
  var mn = document.getElementById('mobile-nav');
  if (hb && mn) {
    hb.addEventListener('click', function(){
      var open = hb.getAttribute('aria-expanded') === 'true';
      hb.setAttribute('aria-expanded', String(!open));
      mn.classList.toggle('is-open', !open);
      document.body.classList.toggle('nav-open', !open);
    });
    Array.prototype.slice.call(mn.querySelectorAll('a')).forEach(function(a){
      a.addEventListener('click', function(){
        hb.setAttribute('aria-expanded', 'false');
        mn.classList.remove('is-open');
        document.body.classList.remove('nav-open');
      });
    });
  }
})();
