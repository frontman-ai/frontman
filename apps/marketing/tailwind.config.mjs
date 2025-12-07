/** @type {import('tailwindcss').Config} */
import defaultTheme from "tailwindcss/defaultTheme";
export default {
  content: ["./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}"],
  darkMode: ["selector"],
  safelist: [
    {
      pattern: /col-span-(\d+)/,
      variants: ["lg"],
    },
    // Height
    {
      pattern: /h-(0|2|3|4|6|8|12|16|24|32)/,
      variants: ["lg"],
    },
    // Text sizes for all screen sizes
    {
      pattern: /text-(xs|sm|base|lg|xl|2xl|3xl|4xl|5xl|6xl|7xl|8xl|9xl)/,
      variants: ["lg"],
    },
    // Font weights
    {
      pattern:
        /font-(thin|extralight|light|normal|medium|semibold|bold|extrabold|black)/,
    },
    // Alignments
    {
      pattern: /text-(left|center|right)/,
    },
  ],
  theme: {
    extend: {
      colors: {
        transparent: "transparent",
        primary: {
          50: "#fdf2f8",
          100: "#fce7f3",
          200: "#fbcfe8",
          300: "#f9a8d4",
          400: "#f472b6",
          500: "#E2187D",
          600: "#db2777",
          700: "#be185d",
          800: "#9d174d",
          900: "#831843",
          950: "#500724",
        },
        neutral: {
          50: "#f8fafc",
          100: "#f1f5f9",
          200: "#e2e8f0",
          300: "#cbd5e1",
          400: "#94a3b8",
          500: "#64748b",
          600: "#475569",
          700: "#334155",
          800: "#1e293b",
          900: "#0f172a",
          950: "#020617",
        },
      },
      cursor: {
        fancy: "url(https://www.svgrepo.com/show/269/color-picker.svg)",
      },
      fontFamily: {
        sans: ["Inter Variable", ...defaultTheme.fontFamily.sans],
        headings: ["Outfit Variable", ...defaultTheme.fontFamily.sans],
      },
      keyframes: {
        dropdown: {
          "0%": { transform: "translateY(-1rem)", opacity: 0 },
          "100%": { transform: "translateY(0)", opacity: 1 },
        },
        fadeInShadowLight: {
          "100%": {
            boxShadow:
              "0 20px 25px -5px rgba(15, 23, 42, .025), 0 8px 10px -6px rgba(15, 23, 42, .025);",
          },
        },
        fadeInShadowDark: {
          "100%": {
            boxShadow:
              "0 20px 25px -5px rgba(2, 6, 23, .25), 0 8px 10px -6px rgba(2, 6, 23, .25);",
          },
        },
        fadeUp: {
          "0%": { transform: "translateY(1rem)", opacity: 0 },
          "100%": { transform: "translateY(0)", opacity: 1 },
        },
      },
      animation: {
        dropdown: "dropdown 300ms ease-in-out forwards",
        fadeInShadowLight: "fadeInShadowLight 500ms ease-in-out forwards",
        fadeInShadowDark: "fadeInShadowDark 500ms ease-in-out forwards",
        fadeUp: "fadeUp 500ms ease-in-out forwards",
      },
    },
  },
  variants: {
    animation: ["responsive"],
  },
  plugins: [
    require("@tailwindcss/typography"),
    require("tailwindcss/plugin")(function ({ addVariant }) {
      addVariant("dark-me", ".dark_&");
    }),
  ],
};
