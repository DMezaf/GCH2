(function(){
  function initLayoutInteractions(){
    const menuToggle = document.getElementById('menuToggle');
    const mainNav = document.getElementById('mainNav');
    if (menuToggle && mainNav){
      menuToggle.addEventListener('click', () => {
        const open = mainNav.classList.toggle('open');
        menuToggle.setAttribute('aria-expanded', String(open));
      });
    }

    document.querySelectorAll('.dropdown').forEach(dropdown => {
      const btn = dropdown.querySelector('.dropdown-btn');
      if (!btn) return;
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        dropdown.classList.toggle('open');
        btn.setAttribute('aria-expanded', String(dropdown.classList.contains('open')));
      });
    });

    document.addEventListener('click', (e) => {
      document.querySelectorAll('.dropdown.open').forEach(dropdown => {
        if (!dropdown.contains(e.target)){
          dropdown.classList.remove('open');
          const btn = dropdown.querySelector('.dropdown-btn');
          if (btn) btn.setAttribute('aria-expanded', 'false');
        }
      });
    });

    const year = document.getElementById('year');
    if (year){
      year.textContent = String(new Date().getFullYear());
    }
  }

  async function injectPartials(){
    const nodes = document.querySelectorAll('[data-include]');
    for (const node of nodes){
      const url = node.getAttribute('data-include');
      try{
        const res = await fetch(url, {cache: 'no-cache'});
        if (!res.ok) throw new Error('HTTP ' + res.status);
        node.outerHTML = await res.text();
      }catch(err){
        node.outerHTML = '<!-- include failed: ' + url + ' -->';
      }
    }

    const file = (location.pathname.split('/').pop() || '').toLowerCase();
    document.querySelectorAll('nav a').forEach(a => {
      const href = (a.getAttribute('href') || '').toLowerCase();
      if (href === file){
        a.style.background = '#F6F8FB';
        a.style.color = '#0F4C81';
      }
    });

    initLayoutInteractions();
  }

  if (document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', injectPartials);
  } else {
    injectPartials();
  }
})();
