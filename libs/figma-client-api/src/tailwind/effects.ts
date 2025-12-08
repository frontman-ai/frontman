/**
 * Effects Tailwind Class Generators
 * Shadows, blur, opacity, blend modes
 */

import type { FigmaNode, Effect, ConversionSettings } from "../types.js";
import { BLUR, BLEND_MODES, ROTATION_VALUES, OPACITY_VALUES } from "../config.js";
import { pxToTailwind, nearestValue, exactValue, numToFixed } from "../utils.js";

/**
 * Generate shadow classes (drop shadow, inner shadow)
 */
export function shadowClasses(node: FigmaNode, settings: ConversionSettings): string[] {
  if (!node.effects || node.effects.length === 0) {
    return [];
  }

  const classes: string[] = [];

  for (const effect of node.effects) {
    if (effect.visible === false) continue;

    if (effect.type === "DROP_SHADOW") {
      const x = effect.offset?.x || 0;
      const y = effect.offset?.y || 0;
      const r = effect.radius || 0;
      const s = effect.spread || 0;
      const color = effect.color;

      // Match Tailwind shadow presets
      if (x === 0 && y === 1 && r === 3 && s === 0) {
        classes.push("shadow");
      } else if (x === 0 && y === 4 && r === 6 && s === -1) {
        classes.push("shadow-md");
      } else if (x === 0 && y === 10 && r === 15 && s === -3) {
        classes.push("shadow-lg");
      } else if (x === 0 && y === 20 && r === 25 && s === -5) {
        classes.push("shadow-xl");
      } else {
        // Custom shadow
        const cr = Math.round((color?.r || 0) * 255);
        const cg = Math.round((color?.g || 0) * 255);
        const cb = Math.round((color?.b || 0) * 255);
        const ca = (color?.a || 0).toFixed(2);
        classes.push(
          `shadow-[${x}px_${y}px_${r}px_${s}px_rgba(${cr},${cg},${cb},${ca})]`
        );
      }
    } else if (effect.type === "INNER_SHADOW") {
      const x = effect.offset?.x || 0;
      const y = effect.offset?.y || 0;
      const r = effect.radius || 0;
      const s = effect.spread || 0;
      const color = effect.color;

      // Match Tailwind inner shadow preset
      if (x === 0 && y === 2 && r === 4 && s === 0) {
        classes.push("shadow-inner");
      } else {
        const cr = Math.round((color?.r || 0) * 255);
        const cg = Math.round((color?.g || 0) * 255);
        const cb = Math.round((color?.b || 0) * 255);
        const ca = (color?.a || 0).toFixed(2);
        classes.push(
          `shadow-[inset_${x}px_${y}px_${r}px_${s}px_rgba(${cr},${cg},${cb},${ca})]`
        );
      }
    } else if (effect.type === "LAYER_BLUR") {
      const radius = (effect.radius || 0) / 2;
      if (radius > 0) {
        const blurValue = pxToTailwind(radius, BLUR, settings);
        // blurValue can be "" for 8px blur (maps to default "blur")
        classes.push(blurValue === "" ? "blur" : `blur-${blurValue}`);
      }
    } else if (effect.type === "BACKGROUND_BLUR") {
      const radius = (effect.radius || 0) / 2;
      if (radius > 0) {
        const blurValue = pxToTailwind(radius, BLUR, settings);
        classes.push(
          blurValue === "" ? "backdrop-blur" : `backdrop-blur-${blurValue}`
        );
      }
    }
  }

  return classes;
}

/**
 * Generate blend mode, opacity, rotation, and visibility classes
 */
export function blendClasses(node: FigmaNode): string[] {
  const classes: string[] = [];

  // Opacity
  if (node.opacity !== undefined && node.opacity < 1) {
    classes.push(`opacity-${nearestValue(node.opacity * 100, OPACITY_VALUES)}`);
  }

  // Blend mode
  if (node.blendMode && BLEND_MODES[node.blendMode]) {
    classes.push(BLEND_MODES[node.blendMode]);
  }

  // Rotation
  if (node.rotation && Math.round(node.rotation) !== 0) {
    const rot = -node.rotation; // Figma uses clockwise, CSS uses counter-clockwise
    const nearest = exactValue(rot, ROTATION_VALUES);

    if (nearest !== null) {
      const sign = nearest < 0 ? "-" : "";
      classes.push(`origin-top-left ${sign}rotate-${Math.abs(nearest)}`);
    } else {
      classes.push(`origin-top-left rotate-[${numToFixed(rot)}deg]`);
    }
  }

  // Visibility
  if (node.visible === false) {
    classes.push("invisible");
  }

  return classes;
}


