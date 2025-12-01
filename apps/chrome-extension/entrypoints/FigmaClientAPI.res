// Type definitions for serialized Figma nodes
type rec serializedNode = {
  id: string,
  @as("type") type_: string,
  name: string,
  css: option<Js.Json.t>,
  width: option<float>,
  height: option<float>,
  x: option<float>,
  y: option<float>,
  visible: option<bool>,
  locked: option<bool>,
  children: option<array<serializedNode>>,
}

// Optimized output format with CSS deduplication
type optimizedOutput = {
  @as("_styles") styles: Js.Dict.t<Js.Json.t>, // Shared CSS styles dictionary  
  @as("_tokens") tokens: Js.Dict.t<string>,   // Token values dictionary
  root: Js.Json.t,                             // Root node with references
}

// Figma node type (minimal definition)
type figmaNode

// =============================================================================
// OPTIMIZATION STRATEGY: ULTRA-COMPACT FORMAT
// =============================================================================
// 
// Aggressive compression for 50%+ size reduction:
// 1. Ultra-short class aliases: flex-col→fc, items-center→ic, etc.
// 2. Skip dimensions under 50px (LLM can infer from context)
// 3. Skip position classes (x/y) - layout is implied by structure  
// 4. Numeric type IDs: FRAME=0, TEXT=1, GROUP=2, etc.
// 5. Single-char keys: type→T, name→N, css→C, children→K (kids)
// 6. Limit to 6 most important classes per node
// 7. Combine common patterns: flex+col+items-start → "fcs"
// 8. No groups dict - inline everything with short aliases
//
// Example output:
// { N:"pricing", C:"fc ic", K:[{ T:1, N:"Title", C:"tc b t48" }] }
//
// Legend (prepended to output):
// Types: 0=FRAME 1=TEXT 2=GROUP 3=RECT 4=VEC 5=INST 6=BOOL 7=ELLIPSE
// Classes: fc=flex-col fr=flex-row ic=items-center is=items-start
//          ie=items-end jc=justify-center js=justify-start ss=self-stretch
//          abs=absolute rel=relative tc=text-center b=font-bold
// =============================================================================
// =============================================================================

// Traverse and serialize with maximum compression
let traverseAndSerialize: figmaNode => promise<Js.Json.t> = %raw(`
  async function traverseAndSerialize(rootNode) {
    // Track css array frequencies for deduplication
    const cssArrayCounts = new Map();  // JSON string -> count
    const cssArrayToGroup = new Map(); // JSON string -> group id
    const groups = {};
    let groupCounter = 0;
    const GROUP_THRESHOLD = 2; // Min uses to create a group
    
    const isEmptyObject = (obj) => {
      return obj !== null && 
             typeof obj === 'object' && 
             !Array.isArray(obj) && 
             Object.keys(obj).length === 0;
    };
    
    const isEmpty = (value) => {
      return value === null ||
             value === undefined ||
             value === '' ||
             value === 0 ||
             isEmptyObject(value) ||
             (Array.isArray(value) && value.length === 0);
    };
    
    // CSS properties that are almost always default - ALWAYS strip
    const STRIP_DEFAULTS = {
      'font-style': 'normal',
      'font-stretch': 'normal', 
      'text-decoration': 'none',
      'text-transform': 'none',
      'white-space': 'normal',
      'word-break': 'normal',
      'overflow-wrap': 'normal',
      'text-indent': '0',
    };
    
    // Type-specific defaults to strip
    const TYPE_DEFAULTS = {
      FRAME: { 'display': 'flex', 'box-sizing': 'border-box' },
      GROUP: { 'display': 'flex' },
      TEXT: { 'display': 'block' },
      RECTANGLE: { 'display': 'block' },
      ELLIPSE: { 'display': 'block' },
      VECTOR: { 'display': 'block' },
    };
    
    // =========================================================================
    // VALUE OPTIMIZATION FUNCTIONS
    // =========================================================================
    
    // Named colors that are shorter than hex
    const HEX_TO_NAME = {
      '#000000': 'black',
      '#ffffff': 'white',
      '#ff0000': 'red',
      '#00ff00': 'lime',
      '#0000ff': 'blue',
      '#ffff00': 'yellow',
      '#00ffff': 'cyan',
      '#ff00ff': 'magenta',
      '#808080': 'gray',
      '#c0c0c0': 'silver',
      '#800000': 'maroon',
      '#808000': 'olive',
      '#008000': 'green',
      '#800080': 'purple',
      '#008080': 'teal',
      '#000080': 'navy',
      '#ffa500': 'orange',
      '#ffc0cb': 'pink',
    };
    
    // Convert RGBA to hex with alpha (shorter format)
    const rgbaToHex = (r, g, b, a) => {
      const toHex = (n) => Math.round(n).toString(16).padStart(2, '0');
      const alpha = Math.round(a * 255);
      
      // Check if we can use short hex (#RGB or #RGBA)
      const rh = toHex(r), gh = toHex(g), bh = toHex(b), ah = toHex(alpha);
      const canShorten = rh[0] === rh[1] && gh[0] === gh[1] && bh[0] === bh[1] && ah[0] === ah[1];
      
      if (a === 1) {
        const hex = '#' + (canShorten ? rh[0] + gh[0] + bh[0] : rh + gh + bh);
        return HEX_TO_NAME[hex.toLowerCase()] || hex;
      }
      
      if (canShorten) {
        return '#' + rh[0] + gh[0] + bh[0] + ah[0];
      }
      return '#' + rh + gh + bh + ah;
    };
    
    // Optimize color values
    const optimizeColor = (value) => {
      // rgba(r, g, b, a) -> hex with alpha
      const rgbaMatch = value.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+))?\s*\)/i);
      if (rgbaMatch) {
        const [, r, g, b, a = '1'] = rgbaMatch;
        return rgbaToHex(parseInt(r), parseInt(g), parseInt(b), parseFloat(a));
      }
      
      // Optimize existing hex colors
      const hexMatch = value.match(/^#([0-9a-f]{6})$/i);
      if (hexMatch) {
        const hex = '#' + hexMatch[1].toLowerCase();
        // Try to shorten #RRGGBB to #RGB
        const h = hexMatch[1].toLowerCase();
        if (h[0] === h[1] && h[2] === h[3] && h[4] === h[5]) {
          const short = '#' + h[0] + h[2] + h[4];
          return HEX_TO_NAME[hex] || short;
        }
        return HEX_TO_NAME[hex] || hex;
      }
      
      return value;
    };
    
    // Optimize numeric values: round to 1 decimal, strip trailing zeros
    const optimizeNumber = (value) => {
      return value.replace(/(\d+\.\d{2,})/g, (match) => {
        const rounded = Math.round(parseFloat(match) * 10) / 10;
        return rounded.toString();
      });
    };
    
    // Strip comments like "/* 30px */" from values
    const stripComments = (value) => {
      return value.replace(/\s*\/\*[^*]*\*\/\s*/g, '').trim();
    };
    
    // Optimize px values: 0px -> 0, and optionally strip px for small values
    const optimizePx = (value) => {
      return value
        .replace(/\b0px\b/g, '0')                    // 0px -> 0
        .replace(/\b0\.0+px\b/g, '0');               // 0.0px -> 0
    };
    
    // Strip CSS variables - keep only the fallback value
    // var(--text-headers, #342D6D) -> #342D6D
    const stripCssVars = (value) => {
      return value.replace(/var\([^,]+,\s*([^)]+)\)/g, '$1');
    };
    
    // Common font families to short codes
    const FONT_ALIASES = {
      'Inter': 'I',
      'Roboto': 'R', 
      'Arial': 'A',
      'Helvetica': 'H',
      'SF Pro Text': 'SF',
      'SF Pro Display': 'SFD',
      'Open Sans': 'OS',
      'Lato': 'L',
      'Montserrat': 'M',
      'Poppins': 'P',
      'Public Sans': 'PS',
      'Comfortaa': 'Co',
    };
    
    // Shorten font family
    const shortenFont = (value) => {
      for (const [full, short] of Object.entries(FONT_ALIASES)) {
        if (value.includes(full)) {
          return value.replace(full, short);
        }
      }
      return value;
    };
    
    // Master optimization function for CSS values
    const optimizeValue = (value) => {
      let v = String(value);
      
      // Strip comments first
      v = stripComments(v);
      
      // Strip CSS variables - use fallback only
      v = stripCssVars(v);
      
      // Optimize numbers
      v = optimizeNumber(v);
      
      // Optimize px values
      v = optimizePx(v);
      
      // Optimize colors
      if (/^(rgba?\(|#[0-9a-f]{3,8}$)/i.test(v)) {
        v = optimizeColor(v);
      }
      
      // Shorten font families
      v = shortenFont(v);
      
      return v;
    };
    
    // =========================================================================
    // ULTRA-SHORT CLASS ALIASES (50%+ compression)
    // =========================================================================
    const SHORT_ALIASES = {
      // Layout
      'flex-col': 'fc', 'flex-row': 'fr',
      'items-center': 'ic', 'items-start': 'is', 'items-end': 'ie', 'items-stretch': 'ix', 'items-baseline': 'ib',
      'justify-center': 'jc', 'justify-start': 'js', 'justify-end': 'je', 'justify-between': 'jb', 'justify-around': 'ja',
      'self-stretch': 'ss', 'self-center': 'sc', 'self-start': 'sst', 'self-end': 'se',
      'flex-1': 'f1', 'flex-none': 'f0', 'flex-auto': 'fa',
      'shrink-0': 'sh0', 'shrink': 'sh', 'grow-0': 'gr0', 'grow': 'gr',
      // Position
      'absolute': 'abs', 'relative': 'rel', 'fixed': 'fix', 'sticky': 'stk',
      // Text
      'text-center': 'tc', 'text-left': 'tl', 'text-right': 'tr',
      'font-thin': 'w1', 'font-light': 'w3', 'font-normal': 'w4', 
      'font-medium': 'w5', 'font-semibold': 'w6', 'font-bold': 'w7', 'font-black': 'w9',
      // Overflow
      'overflow-hidden': 'oh', 'overflow-auto': 'oa', 'overflow-scroll': 'os',
    };
    
    // Type IDs for compression
    const TYPE_IDS = {
      'FRAME': '', // Default, omit entirely
      'TEXT': 'T',
      'GROUP': 'G', 
      'RECTANGLE': 'R',
      'VECTOR': 'V',
      'INSTANCE': 'I',
      'BOOLEAN_OPERATION': 'B',
      'ELLIPSE': 'E',
      'LINE': 'L',
      'POLYGON': 'P',
      'STAR': 'S',
      'COMPONENT': 'C',
    };
    
    // Priority order for classes (most important first)
    const CLASS_PRIORITY = [
      'flex-col', 'flex-row', 'items-', 'justify-', 'self-',  // Layout
      'absolute', 'relative', 'fixed',                         // Position  
      'bg-', 'text-[#', 'text-[var',                          // Colors
      'font-', 'text-[', 'leading-', 'tracking-',             // Typography
      'rounded-', 'border-', 'shadow-',                       // Effects
      'w-[', 'h-[', 'gap-', 'p-', 'pt-', 'pb-', 'pl-', 'pr-', // Dimensions
    ];
    
    const MAX_CLASSES = 5; // Limit classes per node (be aggressive)
    const SKIP_SMALL_DIMENSIONS = true; // Skip w/h under threshold
    const SKIP_POSITIONS = true; // Skip left/top (implied by tree structure)
    
    // Classes to skip entirely (low information value)
    const SKIP_CLASSES = new Set([
      'leading-', 'tracking-', 'opacity-', 'transform-', 'filter-',
      'aspect-', 'z-', 'inset-', 'overflow-', 'font-[I]'  // Skip default Inter font
    ]);
    
    // =========================================================================
    
    // Generate Tailwind-style class name
    const generateTailwindClass = (prop, value) => {
      const v = optimizeValue(String(value));
      
      // Flex direction
      if (prop === 'flex-direction') {
        if (v === 'column') return 'flex-col';
        if (v === 'row') return 'flex-row';
        if (v === 'column-reverse') return 'flex-col-reverse';
        if (v === 'row-reverse') return 'flex-row-reverse';
      }
      
      // Align items
      if (prop === 'align-items') {
        if (v === 'center') return 'items-center';
        if (v === 'flex-start') return 'items-start';
        if (v === 'flex-end') return 'items-end';
        if (v === 'stretch') return 'items-stretch';
        if (v === 'baseline') return 'items-baseline';
      }
      
      // Justify content
      if (prop === 'justify-content') {
        if (v === 'center') return 'justify-center';
        if (v === 'flex-start') return 'justify-start';
        if (v === 'flex-end') return 'justify-end';
        if (v === 'space-between') return 'justify-between';
        if (v === 'space-around') return 'justify-around';
        if (v === 'space-evenly') return 'justify-evenly';
      }
      
      // Align self
      if (prop === 'align-self') {
        if (v === 'stretch') return 'self-stretch';
        if (v === 'center') return 'self-center';
        if (v === 'flex-start') return 'self-start';
        if (v === 'flex-end') return 'self-end';
        if (v === 'auto') return 'self-auto';
      }
      
      // Position
      if (prop === 'position') {
        if (v === 'absolute') return 'absolute';
        if (v === 'relative') return 'relative';
        if (v === 'fixed') return 'fixed';
        if (v === 'sticky') return 'sticky';
        if (v === 'static') return 'static';
      }
      
      // Text align
      if (prop === 'text-align') {
        if (v === 'center') return 'text-center';
        if (v === 'left') return 'text-left';
        if (v === 'right') return 'text-right';
        if (v === 'justify') return 'text-justify';
      }
      
      // Overflow
      if (prop === 'overflow') {
        if (v === 'hidden') return 'overflow-hidden';
        if (v === 'auto') return 'overflow-auto';
        if (v === 'scroll') return 'overflow-scroll';
        if (v === 'visible') return 'overflow-visible';
      }
      
      // Flex shrink/grow
      if (prop === 'flex-shrink') {
        if (v === '0') return 'shrink-0';
        if (v === '1') return 'shrink';
      }
      if (prop === 'flex-grow') {
        if (v === '0') return 'grow-0';
        if (v === '1') return 'grow';
      }
      
      // Flex shorthand
      if (prop === 'flex') {
        if (v === '1 0 0' || v === '1 0 0%') return 'flex-1';
        if (v === 'none') return 'flex-none';
        if (v === 'auto') return 'flex-auto';
        return 'flex-[' + v.replace(/\s+/g, '_') + ']';
      }
      
      // Font weight - map to Tailwind weights
      if (prop === 'font-weight') {
        const weights = {
          '100': 'font-thin',
          '200': 'font-extralight', 
          '300': 'font-light',
          '400': 'font-normal',
          '500': 'font-medium',
          '600': 'font-semibold',
          '700': 'font-bold',
          '800': 'font-extrabold',
          '900': 'font-black',
        };
        return weights[v] || 'font-[' + v + ']';
      }
      
      // Use arbitrary value syntax for everything else
      const prefixMap = {
        'width': 'w',
        'height': 'h',
        'min-width': 'min-w',
        'max-width': 'max-w',
        'min-height': 'min-h',
        'max-height': 'max-h',
        'padding': 'p',
        'padding-top': 'pt',
        'padding-right': 'pr',
        'padding-bottom': 'pb',
        'padding-left': 'pl',
        'margin': 'm',
        'margin-top': 'mt',
        'margin-right': 'mr',
        'margin-bottom': 'mb',
        'margin-left': 'ml',
        'gap': 'gap',
        'top': 'top',
        'right': 'right',
        'bottom': 'bottom',
        'left': 'left',
        'font-size': 'text',
        'font-family': 'font',
        'color': 'text',
        'background': 'bg',
        'background-color': 'bg',
        'border-radius': 'rounded',
        'border-color': 'border',
        'border-width': 'border',
        'border': 'border',
        'line-height': 'leading',
        'letter-spacing': 'tracking',
        'opacity': 'opacity',
        'z-index': 'z',
        'box-shadow': 'shadow',
        'aspect-ratio': 'aspect',
        'inset': 'inset',
      };
      
      const prefix = prefixMap[prop];
      if (prefix) {
        // Strip px suffix for dimensions (just use numbers)
        let cleanVal = v.replace(/(\d+)px/g, '$1');
        
        // For simple color values without spaces, use directly
        if (/^#[0-9a-f]{3,8}$/i.test(cleanVal) || /^[a-z]+$/i.test(cleanVal)) {
          return prefix + '-[' + cleanVal + ']';
        }
        
        // Clean up value for Tailwind arbitrary syntax
        cleanVal = cleanVal
          .replace(/\s+/g, '_')           // Spaces to underscores
          .replace(/,(?!_)/g, ',_');       // Add underscore after commas
        return prefix + '-[' + cleanVal + ']';
      }
      
      // Fallback: property name with value
      const cleanProp = prop.replace(/-/g, '');
      let cleanVal = v;
      if (/^#[0-9a-f]{3,8}$/i.test(v) || /^[a-z]+$/i.test(v)) {
        // Simple value, use directly
      } else {
        cleanVal = v.replace(/\s+/g, '_').replace(/[^a-zA-Z0-9_\-#%.()]/g, '');
      }
      return cleanProp + '-[' + cleanVal + ']';
    };
    
    // Apply ultra-short aliases to a class name
    const shorten = (cls) => SHORT_ALIASES[cls] || cls;
    
    // Get priority score for a class (lower = more important)
    const getPriority = (cls) => {
      for (let i = 0; i < CLASS_PRIORITY.length; i++) {
        if (cls.startsWith(CLASS_PRIORITY[i]) || cls === CLASS_PRIORITY[i].slice(0, -1)) {
          return i;
        }
      }
      return CLASS_PRIORITY.length; // Low priority for unmatched
    };
    
    // Check if class should be skipped (low info value)
    const shouldSkipClass = (cls) => {
      for (const prefix of SKIP_CLASSES) {
        if (cls.startsWith(prefix)) return true;
      }
      return false;
    };
    
    // Convert CSS object + dimensions to optimized space-separated class string
    const toClasses = (css, nodeType, width, height, x, y) => {
      const typeDefaults = TYPE_DEFAULTS[nodeType] || {};
      let classNames = [];
      
      // Process CSS properties
      if (css && typeof css === 'object') {
        for (const [prop, value] of Object.entries(css)) {
          if (STRIP_DEFAULTS[prop] === value) continue;
          if (typeDefaults[prop] === value) continue;
          if (isEmpty(value)) continue;
          
          const cls = generateTailwindClass(prop, value);
          
          // Skip low-value classes
          if (shouldSkipClass(cls)) continue;
          
          classNames.push(cls);
        }
      }
      
      // Add dimension classes if not already in CSS (skip small dimensions)
      const hasCssWidth = css && css.width;
      const hasCssHeight = css && css.height;
      const MIN_DIM = SKIP_SMALL_DIMENSIONS ? 200 : 0; // Skip dimensions under 200px
      
      if (!hasCssWidth && width !== undefined && width > MIN_DIM) {
        const w = Math.round(width);
        classNames.push('w-[' + w + ']');
      }
      if (!hasCssHeight && height !== undefined && height > MIN_DIM) {
        const h = Math.round(height);
        classNames.push('h-[' + h + ']');
      }
      
      // Skip position classes entirely (structure implies position)
      
      // Sort by priority (most important first)
      classNames.sort((a, b) => getPriority(a) - getPriority(b));
      
      // Limit to MAX_CLASSES
      if (classNames.length > MAX_CLASSES) {
        classNames = classNames.slice(0, MAX_CLASSES);
      }
      
      // Apply short aliases and join with spaces (not array)
      const shortened = classNames.map(shorten);
      return shortened.length > 0 ? shortened.join(' ') : null;
    };
    
    // Check if name is auto-generated (should skip)
    const isAutoGeneratedName = (name) => {
      if (!name) return true;
      // Match patterns like "Frame 2087327527", "Group 123", "Rectangle 456"
      return /^(Frame|Group|Rectangle|Ellipse|Vector|Line|Polygon|Star|Component|Instance)\s+\d+$/.test(name);
    };
    
    // Serialize node with ultra-compact format
    const serializeNode = async (node) => {
      const serialized = {};
      
      // Type: use short ID, skip if FRAME (most common)
      const typeId = TYPE_IDS[node.type];
      if (typeId !== undefined && typeId !== '') {
        serialized.T = typeId;
      }
      
      // Name: only if meaningful (not auto-generated)
      if (!isAutoGeneratedName(node.name)) {
        serialized.N = node.name;
      }
      
      // Classes: space-separated string of short aliases
      let classes = null;
      try {
        const rawCss = await node.getCSSAsync();
        classes = toClasses(rawCss, node.type, node.width, node.height, node.x, node.y);
      } catch (e) {
        classes = toClasses(null, node.type, node.width, node.height, node.x, node.y);
      }
      
      if (classes) {
        serialized.C = classes;  // Already a space-separated string
      }
      
      // Hidden flag
      if (node.visible === false) serialized.H = 1;
      
      // Kids (children)
      if ("children" in node && node.type !== "INSTANCE") {
        const kids = [];
        for (const child of node.children) {
          const serializedChild = await serializeNode(child);
          if (serializedChild && !isEmptyObject(serializedChild)) {
            kids.push(serializedChild);
          }
        }
        if (kids.length > 0) {
          serialized.K = kids;
        }
      }
      
      return serialized;
    };
    
    // Serialize tree
    const root = await serializeNode(rootNode);
    
    // Build ultra-compact output with legend
    // Legend helps LLM understand the short codes
    const legend = 'T:T=TEXT,G=GROUP,R=RECT,V=VEC,B=BOOL,E=ELLIPSE|' +
                   'L:fc=flex-col,ic=items-center,is=items-start,jc=justify-center,jb=justify-between,ss=self-stretch|' +
                   'P:abs=absolute,rel=relative|' +
                   'F:w4=400,w5=500,w6=600,w7=700,I=Inter,R=Roboto|' +
                   'K:T=type,N=name,C=css,K=kids';
    
    return {
      _: legend,  // Legend/key for decoding
      $: root     // Root node ($ is short for "root")
    };
  }
`)

// Alternative: Inline CSS (no deduplication, for comparison/debugging)
let traverseAndSerializeCompact: figmaNode => promise<Js.Json.t> = %raw(`
  async function traverseAndSerializeCompact(rootNode) {
    const isEmptyObject = (obj) => {
      return obj !== null && 
             typeof obj === 'object' && 
             !Array.isArray(obj) && 
             Object.keys(obj).length === 0;
    };
    
    const isEmpty = (value) => {
      return value === null ||
             value === undefined ||
             value === '' ||
             value === 0 ||
             isEmptyObject(value) ||
             (Array.isArray(value) && value.length === 0);
    };
    
    const STRIP_DEFAULTS = {
      'font-style': 'normal',
      'font-stretch': 'normal',
      'text-decoration': 'none',
      'text-transform': 'none',
      'white-space': 'normal',
    };
    
    const TYPE_DEFAULTS = {
      FRAME: { 'display': 'flex' },
      GROUP: { 'display': 'flex' },
    };
    
    const optimizeCss = (css, nodeType) => {
      if (!css || typeof css !== 'object') return null;
      
      const optimized = {};
      const typeDefaults = TYPE_DEFAULTS[nodeType] || {};
      
      for (const [key, value] of Object.entries(css)) {
        if (STRIP_DEFAULTS[key] === value) continue;
        if (typeDefaults[key] === value) continue;
        if (isEmpty(value)) continue;
        optimized[key] = value;
      }
      
      return Object.keys(optimized).length > 0 ? optimized : null;
    };
    
    const traverse = async (node) => {
      const n = {
        i: node.id,
        t: node.type,
        n: node.name,
      };
      
      try {
        const rawCss = await node.getCSSAsync();
        const css = optimizeCss(rawCss, node.type);
        if (css) {
          n.s = css;
        }
      } catch (e) {}
      
      try {
        if (node.width !== undefined && node.width !== 0) n.w = Math.round(node.width * 10) / 10;
        if (node.height !== undefined && node.height !== 0) n.h = Math.round(node.height * 10) / 10;
        if (node.x !== undefined && node.x !== 0) n.x = Math.round(node.x * 10) / 10;
        if (node.y !== undefined && node.y !== 0) n.y = Math.round(node.y * 10) / 10;
        if (node.visible === false) n.v = false;
        if (node.locked === true) n.l = true;
      } catch (e) {}
      
      if ("children" in node && node.type !== "INSTANCE") {
        const children = [];
        for (const child of node.children) {
          const serializedChild = await traverse(child);
          if (serializedChild && !isEmptyObject(serializedChild)) {
            children.push(serializedChild);
          }
        }
        if (children.length > 0) n.c = children;
      }
      
      return n;
    };
    
    return { root: await traverse(rootNode) };
  }
`)

// Serialize a single Figma node (kept for backwards compatibility)
let serializeFigmaNode: figmaNode => promise<serializedNode> = %raw(`
  async function(node) {
    const serialized = {
      id: node.id,
      type: node.type,
      name: node.name
    };
    
    try {
      const css = await node.getCSSAsync();
      if (css && Object.keys(css).length > 0) {
        serialized.css = css;
      }
    } catch (e) {}
    
    try {
      if (node.width !== undefined) serialized.width = node.width;
      if (node.height !== undefined) serialized.height = node.height;
      if (node.x !== undefined) serialized.x = node.x;
      if (node.y !== undefined) serialized.y = node.y;
      if (node.visible !== undefined && !node.visible) serialized.visible = node.visible;
      if (node.locked !== undefined && node.locked) serialized.locked = node.locked;
    } catch (e) {}
    
    return serialized;
  }
`)

// Helper to serialize multiple nodes
let serializeNodes: array<figmaNode> => promise<array<serializedNode>> = %raw(`
  async function(nodes) {
    return Promise.all(nodes.map(node => traverseAndSerialize(node)));
  }
`)

// Helper to serialize multiple nodes with compact format
let serializeNodesCompact: array<figmaNode> => promise<array<Js.Json.t>> = %raw(`
  async function(nodes) {
    return Promise.all(nodes.map(node => traverseAndSerializeCompact(node)));
  }
`)

// Figma API bindings
type figmaApi
type pageNode

@val external figma: figmaApi = "figma"

// Get current page
@get external currentPage: figmaApi => pageNode = "currentPage"

// Get selection from page
@get external selection: pageNode => array<figmaNode> = "selection"

// Custom selection change listener using click events
let onSelectionChange: (figmaApi, unit => unit) => unit = %raw(`
  function(figma, callback) {
    let previousFirstNodeId = null;
    
    const checkSelection = () => {
      try {
        const selection = window.figma?.currentPage?.selection;
        
        // Check if selection exists and is not empty
        if (selection && selection.length > 0) {
          const firstNode = selection[0];
          const currentFirstNodeId = firstNode?.id;
          
          // Fire callback only if the first element has changed
          if (currentFirstNodeId && currentFirstNodeId !== previousFirstNodeId) {
            previousFirstNodeId = currentFirstNodeId;
            callback();
          }
        }
      } catch (e) {
        // Silently ignore errors
      }
    };
    
    // Listen to click events on document with capture phase
    document.addEventListener('click', checkSelection, true);
    
    // Return cleanup function (optional)
    return () => {
      document.removeEventListener('click', checkSelection, true);
    };
  }
`)
