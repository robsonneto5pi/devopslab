/* =============================================
   DevOps Lab — main.js
   ============================================= */

// ── Active nav highlight on scroll ──
(function () {
  const navLinks = document.querySelectorAll('nav a[href^="#"]');
  const sections = Array.from(navLinks)
    .map(a => document.querySelector(a.getAttribute('href')))
    .filter(Boolean);

  function onScroll() {
    const scrollY = window.scrollY + 120;
    let current = sections[0];
    sections.forEach(sec => {
      if (sec.offsetTop <= scrollY) current = sec;
    });
    navLinks.forEach(a => {
      a.classList.toggle('active', a.getAttribute('href') === '#' + current.id);
    });
  }

  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
})();

// ── Copy-to-clipboard on code blocks ──
(function () {
  document.querySelectorAll('pre').forEach(pre => {
    const btn = document.createElement('button');
    btn.textContent = 'Copiar';
    btn.style.cssText =
      'position:absolute;top:.6rem;right:.6rem;background:#21262d;color:#8b949e;' +
      'border:1px solid #30363d;border-radius:6px;padding:.2rem .6rem;font-size:.75rem;cursor:pointer;';
    pre.style.position = 'relative';
    pre.appendChild(btn);

    btn.addEventListener('click', () => {
      navigator.clipboard.writeText(pre.innerText.replace('Copiar', '').trim());
      btn.textContent = 'Copiado!';
      btn.style.color = '#3fb950';
      setTimeout(() => { btn.textContent = 'Copiar'; btn.style.color = '#8b949e'; }, 2000);
    });
  });
})();
