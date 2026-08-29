import { describe, expect, test } from "vitest";
import { createApp } from "vue";

import App from "./App.vue";

test("App mounts", () => {
  const el = document.createElement("div");
  const app = createApp(App);
  app.mount(el);
  expect(el.textContent).toContain("Sorak");
  app.unmount();
});
