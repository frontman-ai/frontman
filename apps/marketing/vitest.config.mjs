import { defineConfig } from "vitest/config";
import webmcpValidators from "./src/integrations/webmcp-validators.mjs";

export default defineConfig({
  plugins: [webmcpValidators],
});
