(function defineLocalCodexDirection() {
  const rtl = /[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]/g;
  const latin = /[A-Za-z]/g;

  window.__LOCAL_CODEX_RTL_CLASSIFY__ = function classifyDirection(text) {
    const value = String(text || '');
    const rtlCount = (value.match(rtl) || []).length;
    const latinCount = (value.match(latin) || []).length;
    if (rtlCount === 0) return 'ltr';
    return rtlCount >= Math.max(1, latinCount * 0.15) ? 'rtl' : 'ltr';
  };
})();
