# @frontman/figma-client-api

Figma Node to Tailwind JSON Converter - A modular and testable library for converting Figma design nodes to Tailwind CSS classes.

## Installation

```bash
yarn add @frontman/figma-client-api
```

## Usage

### Basic Usage

```typescript
import { figmaToTailwindJSON, convertNodes } from '@frontman/figma-client-api';

// Convert a single node
const result = await figmaToTailwindJSON(node, { embedVectors: true });

// Convert multiple nodes
const results = await convertNodes(nodes, { embedImages: false });
```

### In Figma Plugin

```typescript
import { figmaToTailwindJSON } from '@frontman/figma-client-api';

// Convert selection
const selection = figma.currentPage.selection;
const results = await Promise.all(
  selection.map(node => figmaToTailwindJSON(node))
);
console.log(JSON.stringify(results, null, 2));
```

### Modular Usage

The library exports individual generators for fine-grained control:

```typescript
import {
  generateTailwindClasses,
  sizeClasses,
  paddingClasses,
  autoLayoutClasses,
  borderRadiusClasses,
  borderClasses,
  shadowClasses,
  blendClasses,
  colorToTailwind,
  fillToTailwind,
} from '@frontman/figma-client-api';

// Use individual generators
const sizes = sizeClasses(node, settings);
const padding = paddingClasses(node, settings);
const layout = autoLayoutClasses(node, settings);

// Or combine them
const allClasses = generateTailwindClasses(node, settings);
```

## Configuration

```typescript
interface ConversionSettings {
  // Embed SVG content for vector nodes
  embedVectors: boolean;        // default: true
  
  // Embed base64 images for image nodes
  embedImages: boolean;         // default: true
  
  // Maximum size for icon detection
  maxIconSize: number;          // default: 64
  
  // Use Tailwind v4 syntax
  useTailwind4: boolean;        // default: false
  
  // Round colors to nearest Tailwind color
  roundTailwindColors: boolean; // default: true
  
  // Round sizes to nearest Tailwind value
  roundTailwindValues: boolean; // default: true
  
  // Base font size for rem calculations
  baseFontSize: number;         // default: 16
  
  // Threshold percentage for value rounding
  thresholdPercent: number;     // default: 15
}
```

## Output Format

```typescript
interface ConvertedNode {
  id: string;
  name: string;
  type: string;
  tailwind: string;
  children?: ConvertedNode[];
  textContent?: string | TextSpan[];
  svg?: string;
  imageBase64?: string;
  warning?: string;
}

interface TextSpan {
  text: string;
  tailwind: string;
}
```

## Architecture

The library is organized into modular files for easy testing and maintenance:

```
src/
├── types.ts          # TypeScript interfaces
├── config.ts         # Tailwind mappings
├── utils.ts          # Utility functions
├── detection.ts      # Node type detection
├── colors.ts         # Color/fill conversion
├── processor.ts      # Main processing logic
├── tailwind/         # Tailwind generators
│   ├── size.ts       # Width, height, min/max
│   ├── layout.ts     # Auto-layout, padding, gap
│   ├── border.ts     # Border and radius
│   ├── effects.ts    # Shadow, blur, opacity
│   ├── position.ts   # Absolute, relative
│   ├── text.ts       # Text styles
│   └── index.ts      # Combined generator
└── index.ts          # Main exports
```

## Testing

```bash
cd libs/figma-client-api
make test        # Run tests
make test-watch  # Watch mode
make lint        # Type check
```

## Development

```bash
make build       # Build TypeScript
make clean       # Clean build artifacts
```

## License

MIT


