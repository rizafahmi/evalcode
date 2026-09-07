import { createApp } from 'vue'
import App from './App.vue'

export function mountApp() {
  const mountEl = document.getElementById('app')
  if (mountEl && !mountEl.hasAttribute('data-v-app')) {
    const app = createApp(App)
    app.mount(mountEl)
    return app
  }
  return null
}

if (typeof window !== 'undefined') {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => mountApp())
  } else {
    mountApp()
  }
}
