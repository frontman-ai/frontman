import {defineConfig} from "astro/config"
import frontman from "@frontman-ai/astro"

export default defineConfig({
  integrations: [
    frontman({
      projectRoot: import.meta.dirname,
      mcp: {
        allowedOrigins: ["https://mcp-client.example"],
        authorize: async headers => {
          const authorization = headers.get("Authorization")
          if (!authorization) return "missing-authentication"
          return authorization === "Bearer astro-compat-token"
            ? "authorized"
            : "insufficient-authorization"
        },
      },
    }),
  ],
  trailingSlash: process.env.ASTRO_TRAILING_SLASH || "ignore",
})
