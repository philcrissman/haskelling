// Lightweight pageview tracking against the self-hosted analytics endpoint.
// Called on initial load and on every in-app (hash) route change. Analytics
// must never break the app, so everything here is best-effort and guarded.

const ENDPOINT = 'https://9fiawrlc8a.execute-api.us-west-2.amazonaws.com/prod/track';
const SITE_ID = 'haskell.ing';

let lastTracked = '';

export function trackPageview(): void {
  if (typeof document === 'undefined' || typeof window === 'undefined') return;
  // 'prerender' is a legacy visibility state (removed from current DOM types).
  if ((document.visibilityState as string) === 'prerender') return;

  // Hash-routed SPA: the meaningful route lives in the hash, so include it.
  const url = window.location.pathname + window.location.hash;
  if (url === lastTracked) return; // de-dupe rapid double fires (e.g. redirect)
  lastTracked = url;

  const data = JSON.stringify({
    url,
    referrer: document.referrer || null,
    siteId: SITE_ID,
  });

  try {
    if (navigator.sendBeacon) {
      navigator.sendBeacon(ENDPOINT, data);
    } else {
      const xhr = new XMLHttpRequest();
      xhr.open('POST', ENDPOINT, true);
      xhr.setRequestHeader('Content-Type', 'text/plain');
      xhr.send(data);
    }
  } catch {
    // swallow — tracking failures should never surface to the user
  }
}
