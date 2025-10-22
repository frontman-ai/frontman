import { readFileSync } from "node:fs";
import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
import { apiModules } from "./docs/utils";

const rescriptTM = JSON.parse(
  readFileSync("./docs/assets/rescript.tmLanguage.json", "utf-8"),
);

const apiSidebarItems = apiModules.map(({ moduleName, link, items }) => {
  const nestedItems = Object.values(items).map(({ moduleName, link }) => ({
    label: moduleName,
    link,
  }));

  return {
    label: moduleName,
    collapsed: true,
    items: [
      {
        label: `Overview`,
        link,
      },
      ...nestedItems,
    ],
  };
});

export default defineConfig({
  srcDir: "docs",
  publicDir: "docs/public",
  site: "https://rescript-lang.github.io",
  base: "experimental-rescript-webapi",
  integrations: [
    starlight({
      title: "Experimental WebAPI",
      logo: {
        src: "./docs/assets/rescript-logo.svg",
      },
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/rescript-lang/experimental-rescript-webapi",
        },
      ],
      editLink: {
        baseUrl:
          "https://github.com/rescript-lang/experimental-rescript-webapi/edit/main/",
      },
      sidebar: [
        {
          slug: "",
        },
        {
          slug: "design-philosophy",
        },
        {
          label: "Examples",
          link: "examples",
        },
        {
          slug: "project-status",
        },
        {
          label: "Contributing",
          autogenerate: { directory: "contributing" },
        },
        {
          label: "API Documentation",
          collapsed: true,
          items: [
            {
              label: "Overview",
              link: "apidocs",
            },
            ...apiSidebarItems,
          ],
        },
        {
          label: "LLM Documentation",
          link: "./llm.txt",
          badge: {
            text: "New",
            variant: "tip",
          },
        },
      ],
      customCss: ["./docs/styles/fonts.css", "./docs/styles/theme.css"],
      expressiveCode: {
        shiki: {
          langs: [rescriptTM],
        },
      },
    }),
  ],
});
