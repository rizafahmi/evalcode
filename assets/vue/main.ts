import { createApp } from "vue"
import App from "./App.vue"

// Boot the Vue application on the empty #app node rendered by the
// authenticated /app controller page. Vue 3 marks the mounted element with a
// `data-v-app` attribute, which is what the browser check keys off of.
createApp(App).mount("#app")
