import { Capacitor } from '@capacitor/core'
import { App, type URLOpenListenerEvent } from '@capacitor/app'
import type { Router } from 'vue-router'

// When the iOS app is opened via a tapped Universal Link (or any custom URL),
// Capacitor fires 'appUrlOpen'. We translate the URL into a router navigation
// so the user lands inside the relevant search.
//
// Also handles the cold-start case where the URL was used to launch the app:
// Capacitor's listener fires once the JS side is ready, regardless of whether
// the activity was queued at launch or arrived while running.
export async function wireUniversalLinks(router: Router): Promise<void> {
  if (!Capacitor.isNativePlatform()) return

  await App.addListener('appUrlOpen', (event: URLOpenListenerEvent) => {
    routeFromUrl(router, event.url)
  })
}

function routeFromUrl(router: Router, url: string): void {
  try {
    const parsed = new URL(url)
    // Strip the origin — could be https://searchassistant.eport.fi or a custom
    // scheme like fi.eport.searchassistant://. The router only cares about the path.
    const path = parsed.pathname + parsed.search + parsed.hash
    if (path && path !== '/') {
      void router.replace(path)
    }
  } catch {
    /* malformed URL — ignore */
  }
}
