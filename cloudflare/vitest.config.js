import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.toml" },
      miniflare: {
        compatibilityDate: "2025-09-06",
      },
    }),
  ],
  test: {
    include: ["tests/**/*.test.js"],
    testTimeout: 30000,
    isolate: false,
  },
});
