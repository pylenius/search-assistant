import { Capacitor } from '@capacitor/core'
import { App, type URLOpenListenerEvent } from '@capacitor/app'
import type { Router } from 'vue-router'

const TAG = '[universalLinks]'

// When the iOS app is opened via a tapped Universal Link (or any custom URL),
// Capacitor fires 'appUrlOpen'. We translate the URL into a router navigation
// so the user lands inside the relevant search.
//
// Cold-launch caveat: the URL may already have been delivered to the native
// side BEFORE this listener registers. App.getLaunchUrl() returns the URL
// that launched the current app session (or null) so we handle that path too.
export async function wireUniversalLinks(router: Router): Promise<void> {
  if (!Capacitor.isNativePlatform()) {
    console.log(TAG, 'not native, skipping')
    return
  }
  console.log(TAG, 'wiring on platform', Capacitor.getPlatform())

  try {
    const launch = await App.getLaunchUrl()
    console.log(TAG, 'getLaunchUrl:', launch?.url ?? '(none)')
    if (launch?.url) routeFromUrl(router, launch.url)
  } catch (e) {
    console.warn(TAG, 'getLaunchUrl failed', e)
  }

  await App.addListener('appUrlOpen', (event: URLOpenListenerEvent) => {
    console.log(TAG, 'appUrlOpen fired:', event.url)
    routeFromUrl(router, event.url)
  })
  console.log(TAG, 'appUrlOpen listener registered')
}

function routeFromUrl(router: Router, url: string): void {
  try {
    const parsed = new URL(url)
    // Strip the origin — could be https://searchassistant.eport.fi or a custom
    // scheme. The router only cares about the path.
    const path = parsed.pathname + parsed.search + parsed.hash
    console.log(TAG, 'routing to:', path, 'from:', url)
    if (path && path !== '/') {
      void router.replace(path)
    } else {
      console.log(TAG, 'path empty/root, not navigating')
    }
  } catch (e) {
    console.warn(TAG, 'malformed URL', url, e)
  }
}
