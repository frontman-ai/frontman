import {defineConfig} from "astro/config"
import frontman from "@frontman-ai/astro"

export default defineConfig({
  integrations: [frontman({projectRoot: import.meta.dirname})],
  trailingSlash: process.env.ASTRO_TRAILING_SLASH || "ignore",
})
