#!/usr/bin/env node

/**
 * Blog cover image generator using Satori + Sharp.
 *
 * Usage:
 *   node scripts/generate-blog-cover.mjs "Your Blog Title Here" [output-filename]
 *
 * Output lands in public/blog/<output-filename>.png (defaults to slugified title).
 */

import satori from "satori";
import sharp from "sharp";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..");

// ---------------------------------------------------------------------------
// Args
// ---------------------------------------------------------------------------
const title = process.argv[2];
if (!title) {
  console.error("Usage: node scripts/generate-blog-cover.mjs <title> [output-filename]");
  process.exit(1);
}

const slug =
  process.argv[3] ??
  title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");

const outPath = join(ROOT, "public", "blog", `${slug}.png`);

// ---------------------------------------------------------------------------
// Fonts — TTFs for satori (woff2 is not supported)
// ---------------------------------------------------------------------------
const fredokaLight = readFileSync(join(__dirname, "fonts", "Fredoka-Light.ttf"));

// ---------------------------------------------------------------------------
// Logo SVG — read and base64-encode for <img> in satori
// ---------------------------------------------------------------------------
const logoSvg = readFileSync(join(ROOT, "public", "logo.svg"), "utf-8");
const logoDataUri = `data:image/svg+xml;base64,${Buffer.from(logoSvg).toString("base64")}`;

// ---------------------------------------------------------------------------
// Brand colors (from tailwind config)
// ---------------------------------------------------------------------------
const brandAccents = ["#A259FF", "#1ABCFE", "#F24E1E", "#EFCF81", "#94D0CD"];

const colors = {
  bg: "#0f172a", // neutral-900
  surface: "#1e293b", // neutral-800
  text: "#f8fafc", // neutral-50
  muted: "#94a3b8", // neutral-400
};

// ---------------------------------------------------------------------------
// Deterministic seeded RNG from the title — same title = same image
// ---------------------------------------------------------------------------
function seededRng(seed) {
  let hash = createHash("sha256").update(seed).digest();
  let offset = 0;
  return () => {
    if (offset + 4 > hash.length) {
      hash = createHash("sha256").update(hash).digest();
      offset = 0;
    }
    const val = hash.readUInt32BE(offset) / 0xffffffff;
    offset += 4;
    return val;
  };
}

const rand = seededRng(title);

// Pick three distinct accent colors for orbs
function pickDistinct(n) {
  const pool = [...brandAccents];
  const picked = [];
  for (let i = 0; i < n; i++) {
    const idx = Math.floor(rand() * pool.length);
    picked.push(pool.splice(idx, 1)[0]);
  }
  return picked;
}
const [orbColor1, orbColor2, orbColor3] = pickDistinct(3);

// Orb positions — wide spread across the canvas, bolder opacity
const orb1 = {
  top: `${-100 + Math.floor(rand() * 300)}px`,
  left: `${-80 + Math.floor(rand() * 900)}px`,
  size: `${300 + Math.floor(rand() * 250)}px`,
  opacity: (0.25 + rand() * 0.2).toFixed(2),
};
const orb2 = {
  bottom: `${-120 + Math.floor(rand() * 250)}px`,
  right: `${-80 + Math.floor(rand() * 700)}px`,
  size: `${250 + Math.floor(rand() * 300)}px`,
  opacity: (0.2 + rand() * 0.2).toFixed(2),
};
const orb3 = {
  top: `${Math.floor(rand() * 300)}px`,
  left: `${200 + Math.floor(rand() * 700)}px`,
  size: `${150 + Math.floor(rand() * 200)}px`,
  opacity: (0.15 + rand() * 0.15).toFixed(2),
};

// Pick accent bar order — shuffle brand colors deterministically
const barColors = [...brandAccents];
for (let i = barColors.length - 1; i > 0; i--) {
  const j = Math.floor(rand() * (i + 1));
  [barColors[i], barColors[j]] = [barColors[j], barColors[i]];
}

// Grid rotation — slight random angle for variety
const gridAngle = Math.floor(rand() * 30 - 15); // -15 to +15 degrees

// ---------------------------------------------------------------------------
// Layout — 1200x450
// ---------------------------------------------------------------------------
const WIDTH = 1200;
const HEIGHT = 450;

const svg = await satori(
  {
    type: "div",
    props: {
      style: {
        width: "100%",
        height: "100%",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: colors.bg,
        padding: "40px 60px",
        position: "relative",
        overflow: "hidden",
      },
      children: [
        // Decorative gradient orb 1
        {
          type: "div",
          props: {
            style: {
              position: "absolute",
              top: orb1.top,
              left: orb1.left,
              width: orb1.size,
              height: orb1.size,
              borderRadius: "9999px",
              background: `radial-gradient(circle, ${orbColor1}, transparent 70%)`,
              opacity: orb1.opacity,
            },
          },
        },
        // Decorative gradient orb 2
        {
          type: "div",
          props: {
            style: {
              position: "absolute",
              bottom: orb2.bottom,
              right: orb2.right,
              width: orb2.size,
              height: orb2.size,
              borderRadius: "9999px",
              background: `radial-gradient(circle, ${orbColor2}, transparent 70%)`,
              opacity: orb2.opacity,
            },
          },
        },
        // Decorative gradient orb 3
        {
          type: "div",
          props: {
            style: {
              position: "absolute",
              top: orb3.top,
              left: orb3.left,
              width: orb3.size,
              height: orb3.size,
              borderRadius: "9999px",
              background: `radial-gradient(circle, ${orbColor3}, transparent 70%)`,
              opacity: orb3.opacity,
            },
          },
        },
        // Rotated grid overlay
        {
          type: "div",
          props: {
            style: {
              position: "absolute",
              top: "-50%",
              left: "-50%",
              width: "200%",
              height: "200%",
              backgroundImage: `linear-gradient(${colors.surface}40 1px, transparent 1px), linear-gradient(90deg, ${colors.surface}40 1px, transparent 1px)`,
              backgroundSize: "60px 60px",
              transform: `rotate(${gridAngle}deg)`,
            },
          },
        },
        // Logo
        {
          type: "img",
          props: {
            src: logoDataUri,
            width: 80,
            height: 80,
            style: {
              marginBottom: "24px",
            },
          },
        },
        // Title
        {
          type: "div",
          props: {
            style: {
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              maxWidth: "900px",
            },
            children: [
              {
                type: "div",
                props: {
                  style: {
                    fontSize: title.length > 60 ? "34px" : title.length > 40 ? "40px" : "46px",
                    fontWeight: 300,
                    color: colors.text,
                    fontFamily: "Fredoka",
                    textAlign: "center",
                    lineHeight: 1.25,
                    letterSpacing: "-0.01em",
                  },
                  children: title,
                },
              },
            ],
          },
        },
        // Bottom accent bar — horizontal
        {
          type: "div",
          props: {
            style: {
              position: "absolute",
              bottom: "0px",
              left: "0px",
              right: "0px",
              display: "flex",
              flexDirection: "row",
            },
            children: barColors.map((c) => ({
              type: "div",
              props: {
                style: {
                  flex: 1,
                  height: "4px",
                  backgroundColor: c,
                },
              },
            })),
          },
        },
        // "frontman.sh" watermark
        {
          type: "div",
          props: {
            style: {
              position: "absolute",
              bottom: "14px",
              right: "24px",
              fontSize: "13px",
              color: colors.muted,
              fontFamily: "Fredoka",
              fontWeight: 300,
              letterSpacing: "0.05em",
            },
            children: "frontman.sh",
          },
        },
      ],
    },
  },
  {
    width: WIDTH,
    height: HEIGHT,
    fonts: [
      {
        name: "Fredoka",
        data: fredokaLight,
        weight: 300,
        style: "normal",
      },
    ],
  },
);

// ---------------------------------------------------------------------------
// Satori outputs SVG → Sharp converts to PNG
// ---------------------------------------------------------------------------
await sharp(Buffer.from(svg)).png({ quality: 90 }).toFile(outPath);

console.log(`Blog cover generated → ${outPath}`);
