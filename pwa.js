/* Progressive enhancement for HTTPS hosting (GitHub Pages). Does not replace Supabase connectivity. */
(() => {
  const secureContext = location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1';
  if (!secureContext || !('serviceWorker' in navigator)) return;
  window.addEventListener('load', () => {
    navigator.serviceWorker.register(new URL('./service-worker.js', document.baseURI), { scope: './' })
      .catch(error => console.warn('NeedsList: service worker registration failed:', error));
  }, { once: true });
})();
