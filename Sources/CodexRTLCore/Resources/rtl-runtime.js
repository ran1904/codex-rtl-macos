(function startLocalCodexRtl() {
  const STYLE_ID = 'local-codex-rtl-style';
  const ROOT = '[data-local-codex-rtl-root="true"]';
  const OWN = '[data-local-codex-rtl-control="true"]';
  const MESSAGE = '[data-message-author-role], article, [data-testid*="message" i]';
  const RESPONSE = '[data-response-annotation-target]';
  const TURN = '[data-turn-key]';
  const USER_MESSAGE = '[data-user-message-bubble="true"], [data-message-author-role="user"]';
  const OUTPUT_DIRECTION_THRESHOLD = 12;
  const RICH_TEXT = 'p, li, blockquote, h1, h2, h3, h4, h5, h6, td, th';
  const UI_TEXT = 'span, label, button, summary';
  const PROSE = `${RICH_TEXT}, ${UI_TEXT}`;
  const INPUT = 'textarea, input[type="text"], [contenteditable="true"], [role="textbox"]';
  const CODE = 'pre, code, kbd, samp, var, [data-markdown-copy="inline-code"], [data-testid*="terminal" i], [data-testid*="code" i], [class*="terminal" i], [class*="monaco" i], [class*="codemirror" i], [class*="shiki" i]';
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
  function hasDirectText(element) {
    return Array.from(element.childNodes || []).some(
      (node) => node.nodeType === Node.TEXT_NODE && node.textContent?.trim()
    );
  }
  function isInlineRichText(element) {
    return Boolean(element.matches?.(UI_TEXT) && element.parentElement?.closest?.(RICH_TEXT));
  }
  function responseFor(element) { return element.closest?.(RESPONSE) || null; }
  function responseTextFor(element) {
    const text = textFor(element).trim();
    const heading = element.querySelector?.(':scope > h4')?.innerText?.trim();
    return heading && text.startsWith(heading) ? text.slice(heading.length).trim() : text;
  }
  function promptDirectionFor(element) {
    const prompt = element.closest?.(TURN)?.querySelector?.(USER_MESSAGE);
    return prompt ? classify(textFor(prompt)) : null;
  }
  function strongCharacterCount(text) {
    return (String(text || '').match(/[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFFA-Za-z]/g) || []).length;
  }

  function markCodeElement(element) {
    if (element.dataset.localCodexRtlManaged === 'true') {
      delete element.dataset.localCodexRtlProse;
      delete element.dataset.localCodexRtlManaged;
      element.removeAttribute('lang');
    }
    element.dataset.localCodexRtlCode = 'true';
    element.dir = 'ltr';
  }

  function markCode(root) {
    if (root.matches?.(CODE)) markCodeElement(root);
    root.querySelectorAll?.(CODE).forEach(markCodeElement);
  }

  function applyProse(element) {
    if (isOwn(element) || isCode(element)) return;
    if (isInlineRichText(element)) {
      if (element.dataset.localCodexRtlManaged === 'true') {
        delete element.dataset.localCodexRtlProse;
        delete element.dataset.localCodexRtlManaged;
        element.removeAttribute('dir');
        element.removeAttribute('lang');
      }
      return;
    }
    if (element.matches?.(UI_TEXT) && !hasDirectText(element)) return;
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

  function applyResponse(element) {
    if (isOwn(element) || isCode(element)) return;
    const output = responseTextFor(element);
    const promptDirection = promptDirectionFor(element);
    const usePromptHint = promptDirection === 'rtl'
      && strongCharacterCount(output) < OUTPUT_DIRECTION_THRESHOLD;
    if (!output && !usePromptHint) return;
    const mode = usePromptHint ? 'rtl' : classify(output);
    if (mode === 'rtl') {
      element.dataset.localCodexRtlResponse = 'true';
      element.dataset.localCodexRtlHint = usePromptHint ? 'prompt' : 'output';
      element.dir = 'rtl';
      element.lang = 'he';
    } else {
      delete element.dataset.localCodexRtlResponse;
      element.dataset.localCodexRtlHint = 'output';
      if (element.dataset.localCodexRtlManaged === 'true') {
        element.dir = 'auto';
        element.removeAttribute('lang');
      }
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
    const responses = [];
    const containingResponse = responseFor(root);
    if (containingResponse) responses.push(containingResponse);
    if (root.matches?.(RESPONSE)) responses.push(root);
    root.querySelectorAll?.(RESPONSE).forEach((node) => responses.push(node));
    for (const response of new Set(responses)) applyResponse(response);
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
