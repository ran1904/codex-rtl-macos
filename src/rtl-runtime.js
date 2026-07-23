(function startLocalCodexRtl() {
  const STYLE_ID = 'local-codex-rtl-style';
  const ROOT = '[data-local-codex-rtl-root="true"]';
  const OWN = '[data-local-codex-rtl-control="true"]';
  const MESSAGE = '[data-message-author-role], article, [data-testid*="message" i]';
  const PROSE = 'p, li, blockquote, h1, h2, h3, h4, h5, h6, td, th';
  const INPUT = 'textarea, input[type="text"], [contenteditable="true"], [role="textbox"]';
  const CODE = 'pre, code, kbd, samp, var, [data-testid*="terminal" i], [data-testid*="code" i], [class*="terminal" i], [class*="monaco" i], [class*="codemirror" i], [class*="shiki" i]';
  const classify = window.__LOCAL_CODEX_RTL_CLASSIFY__;
  if (typeof classify !== 'function') throw new Error('Missing local direction classifier.');

  function setStyle() {
    let style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = STYLE_ID;
      document.head.append(style);
    }
    style.textContent = window.__LOCAL_CODEX_RTL_CSS__ || '';
    document.documentElement.dataset.localCodexRtlRoot = 'true';
  }

  function isOwn(element) { return Boolean(element.closest?.(OWN)); }
  function isCode(element) { return Boolean(element.closest?.(CODE)); }
  function messageFor(element) { return element.closest?.(MESSAGE) || null; }
  function overrideFor(element) { return messageFor(element)?.dataset.localCodexRtlOverride || 'auto'; }
  function textFor(element) { return element.value || element.innerText || element.textContent || ''; }

  function markCode(root) {
    if (root.matches?.(CODE)) root.dataset.localCodexRtlCode = 'true';
    root.querySelectorAll?.(CODE).forEach((node) => { node.dataset.localCodexRtlCode = 'true'; node.dir = 'ltr'; });
  }

  function applyProse(element) {
    if (isOwn(element) || isCode(element)) return;
    const text = textFor(element).trim();
    if (!text) return;
    const forced = overrideFor(element);
    const mode = forced === 'auto' ? classify(text) : forced;
    if (mode === 'rtl') {
      element.dataset.localCodexRtlProse = 'true';
      element.dir = 'rtl';
      element.lang = 'he';
    } else {
      delete element.dataset.localCodexRtlProse;
      if (element.dataset.localCodexRtlManaged === 'true') element.dir = 'auto';
    }
    element.dataset.localCodexRtlManaged = 'true';
  }

  function applyInput(element) {
    if (isOwn(element) || isCode(element)) return;
    if (classify(textFor(element)) === 'rtl') {
      element.dataset.localCodexRtlInput = 'true';
      element.dir = 'rtl';
      element.lang = 'he';
    } else {
      delete element.dataset.localCodexRtlInput;
      element.dir = 'auto';
    }
  }

  function makeControl(message) {
    if (!message || message.querySelector(`:scope > ${OWN}`)) return;
    if (!message.dataset.localCodexRtlOverride && classify(textFor(message)) !== 'rtl') return;
    const control = document.createElement('span');
    control.dataset.localCodexRtlControl = 'true';
    control.setAttribute('role', 'group');
    control.setAttribute('aria-label', 'Message direction');
    for (const [value, label] of [['auto', 'Auto'], ['rtl', 'RTL'], ['ltr', 'LTR']]) {
      const button = document.createElement('button');
      button.type = 'button';
      button.dataset.localCodexRtlMode = value;
      button.textContent = label;
      button.setAttribute('aria-pressed', String((message.dataset.localCodexRtlOverride || 'auto') === value));
      control.append(button);
    }
    message.append(control);
  }

  function updateControl(message) {
    const current = message.dataset.localCodexRtlOverride || 'auto';
    message.querySelectorAll(`${OWN} button`).forEach((button) => {
      button.setAttribute('aria-pressed', String(button.dataset.localCodexRtlMode === current));
    });
  }

  function scan(root = document.body) {
    if (!(root instanceof HTMLElement)) return;
    markCode(root);
    const messages = [];
    if (root.matches?.(MESSAGE)) messages.push(root);
    root.querySelectorAll?.(MESSAGE).forEach((node) => messages.push(node));
    for (const message of new Set(messages)) makeControl(message);
    if (root.matches?.(PROSE)) applyProse(root);
    root.querySelectorAll?.(PROSE).forEach(applyProse);
    if (root.matches?.(INPUT)) applyInput(root);
    root.querySelectorAll?.(INPUT).forEach(applyInput);
  }

  function handleClick(event) {
    const button = event.target.closest?.(`${OWN} button`);
    if (!button) return;
    const message = button.closest(MESSAGE);
    if (!message) return;
    message.dataset.localCodexRtlOverride = button.dataset.localCodexRtlMode || 'auto';
    updateControl(message);
    scan(message);
  }

  function handleInput(event) {
    if (event.target instanceof HTMLElement) applyInput(event.target);
  }

  if (window.__LOCAL_CODEX_RTL_CLICK_HANDLER__) {
    document.removeEventListener('click', window.__LOCAL_CODEX_RTL_CLICK_HANDLER__, true);
  }
  if (window.__LOCAL_CODEX_RTL_INPUT_HANDLER__) {
    document.removeEventListener('input', window.__LOCAL_CODEX_RTL_INPUT_HANDLER__, true);
  }
  window.__LOCAL_CODEX_RTL_CLICK_HANDLER__ = handleClick;
  window.__LOCAL_CODEX_RTL_INPUT_HANDLER__ = handleInput;
  document.addEventListener('click', handleClick, true);
  document.addEventListener('input', handleInput, true);

  const pendingRoots = new Set();
  let queued = false;

  function queueRoot(root) {
    if (!(root instanceof HTMLElement) || !root.isConnected) return;
    for (const pending of pendingRoots) {
      if (pending.contains(root)) return;
      if (root.contains(pending)) pendingRoots.delete(pending);
    }
    pendingRoots.add(root);
  }

  function flush() {
    queued = false;
    const roots = Array.from(pendingRoots).slice(0, 25);
    roots.forEach((root) => pendingRoots.delete(root));
    roots.forEach((root) => {
      if (root.isConnected) scan(root);
    });
    if (pendingRoots.size) schedule();
  }

  const schedule = (records = []) => {
    records.forEach((record) => {
      const root = record.target instanceof HTMLElement
        ? record.target
        : record.target.parentElement;
      queueRoot(root);
    });
    if (queued) return;
    queued = true;
    requestAnimationFrame(flush);
  };
  window.__LOCAL_CODEX_RTL_OBSERVER__?.disconnect();
  window.__LOCAL_CODEX_RTL_OBSERVER__ = new MutationObserver((records) => schedule(records));
  window.__LOCAL_CODEX_RTL_OBSERVER__.observe(document.body, { childList: true, subtree: true, characterData: true });
  setStyle();
  scan();
  window.__LOCAL_CODEX_RTL_ACTIVE__ = true;
})();
