import { createApp } from 'vue'
import { createPinia } from 'pinia'
import './style.css'
import App from './App.vue'
import { router } from './router'
import { wireUniversalLinks } from './lib/universalLinks'

createApp(App).use(createPinia()).use(router).mount('#app')

// Listen for iOS Universal Link / Android intent URL opens once the router is up.
void wireUniversalLinks(router)
