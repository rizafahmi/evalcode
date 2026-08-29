import { createRouter, createWebHistory } from "vue-router";
import Overview from "./pages/Overview.vue";

export const router = createRouter({
  history: createWebHistory("/app"),
  routes: [{ path: "/", name: "overview", component: Overview }],
});
