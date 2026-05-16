import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'fi.eport.searchassistant',
  appName: 'Search Assistant',
  webDir: 'dist',
  ios: {
    contentInset: 'always',
  },
}

export default config
