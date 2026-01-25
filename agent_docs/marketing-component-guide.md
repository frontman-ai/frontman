# Marketing Site Component Construction Guide

**Version:** 1.0
**Last Updated:** January 2026
**Scope:** apps/marketing component development patterns and conventions

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Component Structure](#component-structure)
3. [File Organization](#file-organization)
4. [Component Patterns](#component-patterns)
5. [Styling System](#styling-system)
6. [Props & TypeScript](#props--typescript)
7. [Layout System](#layout-system)
8. [Asset Management](#asset-management)
9. [Responsive Design](#responsive-design)
10. [Code Examples](#code-examples)
11. [Common Pitfalls](#common-pitfalls)

---

## Architecture Overview

### Tech Stack
- **Framework:** Astro (Server-side rendering with islands architecture)
- **Styling:** Tailwind CSS v3 + Scoped CSS
- **TypeScript:** For type-safe props
- **Fonts:** Inter Variable (body), Outfit Variable (headings)
- **Icons:** Astro Icon component

### Component Hierarchy
```
components/
├── blocks/           # Page-level sections (hero, features, CTA, etc.)
│   ├── [category]/  # Organized by purpose
│   └── partials/    # Block-specific sub-components
├── ui/              # Reusable UI primitives
│   ├── cards/
│   ├── forms/
│   └── [component].astro
├── scripts/         # Client-side scripts
└── layouts/         # Page layouts
```

### Core Principles
1. **Composition over Configuration** - Build complex components from simple primitives
2. **Mobile-First Responsive** - Default to mobile, enhance with `lg:` breakpoints
3. **Type Safety** - Always define TypeScript props
4. **Semantic HTML** - Use proper HTML5 elements
5. **Accessibility** - Follow WCAG guidelines
6. **Performance** - Optimize images, lazy load when appropriate

---

## Component Structure

### Anatomy of a Component

Every Astro component follows this exact structure:

```astro
---
// 1. DOCUMENTATION BLOCK
// Component Name
// ------------
// Description: Brief description of what this component does
// Properties:
// - PropName: Description of prop (type, purpose)
// Reference: [optional link to design system or docs]

// 2. IMPORTS
// Components (grouped by type)
import Layout from '../path/Layout.astro'
import UI from '../path/UI.astro'

// 3. TYPE DEFINITIONS
type Props = {
	propName: string
	optionalProp?: boolean
	// ... all props with types
}

// 4. PROPS DESTRUCTURING
const {
	propName,
	optionalProp = defaultValue
} = Astro.props

// 5. DATA/LOGIC (if needed)
const computedValue = /* ... */
---

<!-- 6. TEMPLATE -->
<element class="component-class">
	<!-- Use semantic HTML -->
	<slot />
</element>

<!-- 7. STYLES -->
<style>
	/* Scoped styles using Tailwind @apply or custom CSS */
	.component-class {
		@apply /* Tailwind utilities */;
	}
</style>
```

### Required Documentation Block

**ALWAYS start with a documentation block:**

```typescript
// Component Name
// ------------
// Description: [What it does, when to use it]
// Properties:
// - prop1: description (type)
// - prop2: description (type)
// Reference: [optional]
```

This is **mandatory** - never skip it.

---

## File Organization

### Naming Conventions

1. **Component Files:** PascalCase.astro
   - ✅ `FeatureCard.astro`
   - ✅ `HomeCTA.astro`
   - ❌ `feature-card.astro`
   - ❌ `home_cta.astro`

2. **Asset Files:** kebab-case with descriptive names
   - ✅ `hero-background.webp`
   - ✅ `feature-01.svg`
   - ❌ `img1.png`
   - ❌ `HeroBackground.webp`

3. **Class Names:** kebab-case with BEM-like structure
   - ✅ `hero-section__title`
   - ✅ `feature-card--highlighted`
   - ❌ `heroSectionTitle`
   - ❌ `Hero_section_title`

### Directory Structure for New Blocks

When creating a new block component:

```
components/blocks/[category]/
├── ComponentName.astro          # Main component
└── partials/                    # If needed
    ├── SubComponent.astro
    └── AnotherPart.astro
```

**Example:** Creating an "Install Steps" block

```
components/blocks/features/
└── InstallSteps.astro
```

Or if it needs sub-components:

```
components/blocks/install/
├── InstallSteps.astro
└── partials/
    └── StepCard.astro
```

---

## Component Patterns

### Block Components (Page Sections)

Block components represent major page sections. They:
- Always wrap content in `<Section>` component
- Use `<Row>` and `<Col>` for layout
- Import assets at the top
- Define content data structures when needed

**Pattern:**

```astro
---
// Imports
import Section from '../../ui/Section.astro'
import Row from '../../ui/Row.astro'
import Col from '../../ui/Col.astro'
import Card from '../../ui/cards/BasicCard.astro'

// Content
import image from '../../../assets/my-image.svg'

type DataItem = {
	title: string
	description: string
	image: any
}

const items: DataItem[] = [
	{
		title: 'Item 1',
		description: 'Description',
		image: image
	}
]
---

<Section id="unique-id">
	<Row>
		<Col span="12">
			<h2>Section Title</h2>
		</Col>
	</Row>
	<Row>
		{items.map((item) => (
			<Col span="4">
				<Card
					title={item.title}
					subtitle={item.description}
					image={item.image}
				/>
			</Col>
		))}
	</Row>
</Section>
```

### UI Components (Primitives)

UI components are reusable primitives. They:
- Accept flexible props
- Support `classes` prop for extension
- Use `class:list` for conditional classes
- Provide `<slot />` for content injection

**Pattern:**

```astro
---
type Props = {
	variant?: 'primary' | 'secondary'
	size?: 'sm' | 'md' | 'lg'
	classes?: string
}

const {
	variant = 'primary',
	size = 'md',
	classes
} = Astro.props
---

<div
	class:list={[
		'base-class',
		{ ['variant--' + `${variant}`]: variant },
		{ ['size--' + `${size}`]: size },
		{ [`${classes}`]: classes }
	]}
>
	<slot />
</div>

<style>
	.base-class {
		@apply /* base styles */;
	}
	.variant--primary {
		@apply /* primary variant */;
	}
	/* ... more variants */
</style>
```

---

## Styling System

### Tailwind Configuration

**Brand Colors** (from tailwind.config.mjs):

**PRIMARY - Orange (Main Brand Color):**
- `primary-500`: #F24E1E (hero orange - main CTA color)
- `primary-*`: Orange tints from 50-950
- Use for: Primary buttons, links, highlights, main CTAs

**SUPPORTING - Accent Colors:**
- `accent-purple`: #7C3AED (testimonial cards, developer role)
- `accent-cyan`: #06B6D4 (testimonial cards, tech lead role)
- `accent-amber`: #D97706 (testimonial cards, engineer role)
- Use for: Card borders, role distinction, visual variety

**SUPPORTING - Background Colors:**
- `bg-cream`: #FFF4CC (cream yellow for step cards)
- `bg-lightblue`: #C4E0FF (light blue for step cards)
- `bg-lavender`: #E8D5FF (lavender for section backgrounds)
- `bg-peach`: #FFE4D6 (peach for step cards)
- Use for: Section backgrounds, card backgrounds, friendly variety

**NEUTRAL - Gray Scale:**
- `neutral-*`: Grays from 50-950 (#64748b at 500)
- Use for: Text, borders, backgrounds

**Typography:**
- Body font: `Inter Variable` (sans)
- Heading font: `Outfit Variable` (font-headings)

**Color Usage Rules:**
1. **Orange is primary** - All main CTAs and buttons use primary-500 (#F24E1E)
2. **Supporting colors add variety** - Use accent and bg colors for visual interest
3. **Keep it friendly** - Soft pastels create approachable, non-corporate feel

### Style Priority

Use styles in this order of preference:

1. **Tailwind Utilities** (inline classes)
   ```astro
   <div class="flex items-center gap-4 p-6 rounded-lg">
   ```

2. **Scoped @apply** (in `<style>` blocks)
   ```css
   .component {
   	@apply flex items-center gap-4 p-6 rounded-lg;
   }
   ```

3. **Custom CSS** (only when Tailwind can't handle it)
   ```css
   .component {
   	background: linear-gradient(45deg, #fff, #f0f0f0);
   }
   ```

### Class List Pattern

**Always use `class:list` for conditional classes:**

```astro
<div
	class:list={[
		'base-class',                              // Always applied
		{ 'conditional-class': condition },        // Conditional
		{ ['dynamic--' + `${variant}`]: variant }, // Dynamic
		{ [`${classes}`]: classes }                // Props extension
	]}
>
```

**Never concatenate strings:**
```astro
<!-- ❌ BAD -->
<div class={`base-class ${condition ? 'active' : ''} ${classes}`}>

<!-- ✅ GOOD -->
<div class:list={['base-class', { 'active': condition }, { [`${classes}`]: classes }]}>
```

### Responsive Patterns

**Mobile-first approach:**

```css
.element {
	/* Mobile styles (default) */
	@apply text-sm p-4;

	/* Desktop styles (lg: breakpoint = 1024px+) */
	@apply lg:text-base lg:p-6;
}
```

**Common breakpoint patterns:**

```astro
<!-- Stacking on mobile, side-by-side on desktop -->
<div class="flex flex-col lg:flex-row gap-4">

<!-- Hide on mobile, show on desktop -->
<div class="hidden lg:block">

<!-- Different spans by breakpoint -->
<Col spanMobile="12" span="6">

<!-- Different text sizes -->
<h1 class="text-3xl lg:text-6xl">
```

---

## Props & TypeScript

### Type Definition Rules

1. **Always define `type Props`** - never `interface Props`
2. **Always destructure props** with defaults
3. **Document each prop** in the comment block
4. **Use union types** for variants
5. **Make everything optional** except required props

**Pattern:**

```typescript
type Props = {
	// Required props (no ?)
	title: string

	// Optional props (with ?)
	subtitle?: string

	// Union types for variants
	size?: 'sm' | 'md' | 'lg'

	// Complex types
	items?: Array<{
		label: string
		value: string
	}>

	// Images (from Astro.assets)
	image?: any
	imageWidth?: number
	imageHeight?: number

	// Flexibility
	classes?: string
	link?: string
}

// Destructure with defaults
const {
	title,                    // Required, no default
	subtitle,                 // Optional, no default
	size = 'md',             // Optional with default
	items = [],              // Optional with default
	image,
	imageWidth,
	imageHeight,
	classes,
	link
} = Astro.props
```

### Common Prop Patterns

**Layout Props:**
```typescript
type LayoutProps = {
	id?: string              // For anchor links
	padding?: 'both' | 'top' | 'bottom' | 'none'
	mode?: 'dark' | 'light'
	bg?: BgProps             // Background image
	classes?: string
}
```

**Content Props:**
```typescript
type ContentProps = {
	title?: string
	subtitle?: string
	text?: string
	image?: any
	imagePosition?: 'left' | 'right'
	link?: string
}
```

**Style Props:**
```typescript
type StyleProps = {
	variant?: 'primary' | 'secondary' | 'neutral'
	size?: 'sm' | 'md' | 'lg'
	elevated?: boolean
	classes?: string
}
```

---

## Layout System

### Grid System

The project uses a **12-column grid system**:

- `<Row>`: Creates grid container
- `<Col>`: Creates grid item with span

**Column Spans:**

```astro
<!-- Full width -->
<Col span="12">

<!-- Half width (desktop), full width (mobile) -->
<Col spanMobile="12" span="6">

<!-- Third width -->
<Col span="4">

<!-- Quarter width -->
<Col span="3">

<!-- Two-thirds -->
<Col span="8">
```

**Common Layouts:**

```astro
<!-- Centered content with margins -->
<Row>
	<Col span="1" />  <!-- Spacer -->
	<Col span="10">   <!-- Content -->
		<!-- Your content -->
	</Col>
	<Col span="1" />  <!-- Spacer -->
</Row>

<!-- Two-column layout -->
<Row>
	<Col span="6">
		<!-- Left content -->
	</Col>
	<Col span="6">
		<!-- Right content -->
	</Col>
</Row>

<!-- Three-column layout -->
<Row>
	<Col span="4">Column 1</Col>
	<Col span="4">Column 2</Col>
	<Col span="4">Column 3</Col>
</Row>

<!-- Asymmetric layout -->
<Row>
	<Col span="8">   <!-- Main content -->
		<!-- Primary content -->
	</Col>
	<Col span="4">   <!-- Sidebar -->
		<!-- Secondary content -->
	</Col>
</Row>
```

### Section Component

**Always wrap blocks in `<Section>`:**

```astro
<Section
	id="unique-section-id"
	padding="both"           // 'both' | 'top' | 'bottom' | 'none'
	mode="dark"              // 'dark' | 'light' | undefined
	bg={backgroundImage}     // Optional background
	bgPosition="center"      // 'center' | 'top' | 'bottom'
	fullWidth={false}        // Full width or contained
	classes="custom-class"   // Additional classes
>
	<Row>
		<!-- Content -->
	</Row>
</Section>
```

**Section Padding:**
- `padding="both"`: py-12 lg:py-24 (default)
- `padding="top"`: pt-12 lg:pt-24
- `padding="bottom"`: pb-12 lg:pb-24
- `padding="none"`: No padding

---

## Asset Management

### Asset Location

```
src/assets/
├── avatars/              # User/team avatars
├── cards/                # Card images
├── highlights/           # Feature highlight images
├── logos/                # Logo variations
├── [name].svg            # SVG icons/graphics
├── [name].png            # Raster images
└── [name].webp           # Optimized images (preferred)
```

### Image Import & Usage

**Import pattern:**

```astro
---
import heroImage from '../../../assets/hero-image.webp'
import logoSvg from '../../../assets/logo.svg'
---

<!-- Using Astro Image component (recommended) -->
<Image
	src={heroImage}
	alt="Descriptive alt text"
	width={1200}
	height={800}
	format="webp"
	class="rounded-lg"
/>

<!-- Using img tag (for SVGs) -->
<img
	src={logoSvg.src}
	alt="Company logo"
	width={143}
	height={143}
/>
```

### Image Optimization Rules

1. **Use WebP format** for photos and complex graphics
2. **Use SVG format** for logos, icons, and simple graphics
3. **Always provide `alt` text** for accessibility
4. **Specify dimensions** when known for CLS prevention
5. **Use Astro's `<Image>` component** for automatic optimization

**File naming:**
- Descriptive: ✅ `feature-dashboard-view.webp`
- Sequential: ✅ `highlight-01.svg`, `highlight-02.svg`
- Generic: ❌ `image1.png`, `pic.jpg`

---

## Responsive Design

### Breakpoints

The project uses **one main breakpoint**:
- Mobile: `< 1024px` (default)
- Desktop: `>= 1024px` (lg: prefix)

**Always design mobile-first:**

```css
/* ✅ GOOD: Mobile-first */
.element {
	@apply text-sm;        /* Mobile default */
	@apply lg:text-base;   /* Desktop override */
}

/* ❌ BAD: Desktop-first */
.element {
	@apply text-base;
	@apply sm:text-sm;
}
```

### Common Responsive Patterns

**Typography:**
```astro
<!-- Headings -->
<h1 class="text-4xl lg:text-6xl">
<h2 class="text-3xl lg:text-5xl">
<h3 class="text-2xl lg:text-3xl">

<!-- Body text -->
<p class="text-base lg:text-lg">
```

**Spacing:**
```astro
<!-- Padding -->
<div class="p-4 lg:p-8">
<div class="px-6 lg:px-12">

<!-- Margins -->
<div class="mb-6 lg:mb-12">
<div class="mt-12 lg:mt-24">

<!-- Gap -->
<div class="gap-4 lg:gap-8">
```

**Layout:**
```astro
<!-- Stacking -->
<div class="flex flex-col lg:flex-row">

<!-- Grid columns -->
<div class="grid grid-cols-1 lg:grid-cols-3">

<!-- Visibility -->
<div class="hidden lg:block">        <!-- Desktop only -->
<div class="block lg:hidden">        <!-- Mobile only -->

<!-- Dimensions -->
<div class="w-full lg:w-1/2">
<div class="h-auto lg:h-screen">
```

**Image Handling:**
```astro
<!-- Responsive image with mobile alternative -->
<picture>
	<source srcset={mobileImage.src} media="(max-width: 1024px)" />
	<img src={desktopImage.src} alt="Description" />
</picture>
```

---

## Code Examples

### Example 1: Feature Cards Block

```astro
---
// Feature Cards Section
// ------------
// Description: A grid of feature cards with images, titles, and descriptions
// Properties: None (content is hardcoded in this example)

// Components
import Section from '../../ui/Section.astro'
import Row from '../../ui/Row.astro'
import Col from '../../ui/Col.astro'
import Card from '../../ui/cards/FeatureCard.astro'

// Content
import feature01 from '../../../assets/cards/feature-01.svg'
import feature02 from '../../../assets/cards/feature-02.svg'
import feature03 from '../../../assets/cards/feature-03.svg'

type Feature = {
	title: string
	subtitle: string
	image: any
	link: string
}

const features: Feature[] = [
	{
		title: 'Real-time Collaboration',
		subtitle: 'Work together seamlessly with your team in real-time.',
		image: feature01,
		link: '/features/collaboration'
	},
	{
		title: 'Advanced Analytics',
		subtitle: 'Gain insights with powerful analytics and reporting tools.',
		image: feature02,
		link: '/features/analytics'
	},
	{
		title: 'Secure by Default',
		subtitle: 'Enterprise-grade security built into every feature.',
		image: feature03,
		link: '/features/security'
	}
]
---

<Section id="features" padding="both">
	<Row>
		<Col span="12" align="center">
			<h2>Powerful <strong>Features</strong></h2>
			<p class="text-lg">
				Everything you need to build amazing products
			</p>
		</Col>
	</Row>
	<Row>
		{features.map((feature) => (
			<Col span="4">
				<Card
					title={feature.title}
					subtitle={feature.subtitle}
					image={feature.image}
					link={feature.link}
				/>
			</Col>
		))}
	</Row>
</Section>
```

### Example 2: Hero Section with Custom Styling

```astro
---
// Home Hero Section
// ------------
// Description: Main hero section with title, subtitle, CTA button, and background

// Components
import Button from '../../ui/Button.astro'
import { Image } from 'astro:assets'

// Content
import heroImage from '../../../assets/hero-image.webp'
import backgroundPattern from '../../../assets/pattern.svg'
---

<section id="hero" class="hero" style={`background-image: url(${backgroundPattern.src})`}>
	<div class="hero__container">
		<div class="hero__content">
			<h1 class="hero__title">
				Build Amazing Products <strong>Faster</strong>
			</h1>
			<p class="hero__subtitle">
				The all-in-one platform for modern teams to collaborate,
				build, and ship products that customers love.
			</p>
			<div class="hero__cta">
				<Button size="lg" style="primary" link="/signup">
					Get Started Free
				</Button>
				<Button size="lg" style="secondary" variation="outline" link="/demo">
					Watch Demo
				</Button>
			</div>
		</div>
		<div class="hero__image">
			<Image
				src={heroImage}
				alt="Product dashboard"
				width={800}
				height={600}
				format="webp"
			/>
		</div>
	</div>
</section>

<style>
	.hero {
		@apply relative overflow-hidden bg-gradient-to-br from-primary-50 to-neutral-50;
		min-height: 600px;
	}

	.hero__container {
		@apply container mx-auto px-6 py-12 lg:py-24;
		@apply flex flex-col lg:flex-row items-center gap-12;
	}

	.hero__content {
		@apply flex-1 text-center lg:text-left;
	}

	.hero__title {
		@apply text-4xl lg:text-6xl font-bold mb-6;
		@apply text-neutral-900 dark:text-neutral-50;
	}

	.hero__subtitle {
		@apply text-lg lg:text-xl mb-8 text-neutral-600 dark:text-neutral-400;
		max-width: 600px;
		@apply mx-auto lg:mx-0;
	}

	.hero__cta {
		@apply flex flex-col sm:flex-row gap-4 justify-center lg:justify-start;
	}

	.hero__image {
		@apply flex-1 w-full max-w-2xl;
	}
</style>
```

### Example 3: Reusable UI Component (Card)

```astro
---
// Step Card
// ------------
// Description: A card component for displaying step-by-step instructions
// Properties:
// - stepNumber: The step number (1, 2, 3, etc.)
// - title: The step title
// - description: The step description
// - bgColor: Background color (Tailwind class)
// - classes: Additional classes

// Props
type Props = {
	stepNumber: number
	title: string
	description: string
	bgColor?: string
	classes?: string
}

const {
	stepNumber,
	title,
	description,
	bgColor = 'bg-neutral-50',
	classes
} = Astro.props
---

<div
	class:list={[
		'step-card',
		bgColor,
		{ [`${classes}`]: classes }
	]}
>
	<div class="step-card__number">
		Step {stepNumber}
	</div>
	<h3 class="step-card__title">
		{title}
	</h3>
	<p class="step-card__description">
		{description}
	</p>
	<div class="step-card__content">
		<slot />
	</div>
</div>

<style>
	.step-card {
		@apply rounded-2xl p-8 border-2 border-neutral-900;
		@apply transition-transform duration-300 hover:-translate-y-1;
	}

	.step-card__number {
		@apply text-sm font-semibold text-neutral-500 mb-2;
	}

	.step-card__title {
		@apply text-2xl font-bold text-neutral-900 mb-3;
	}

	.step-card__description {
		@apply text-neutral-600 mb-4;
	}

	.step-card__content {
		@apply mt-4;
	}
</style>
```

---

## Common Pitfalls

### ❌ DON'T

1. **Don't use string concatenation for classes**
   ```astro
   <!-- BAD -->
   <div class={`base ${active ? 'active' : ''}`}>
   ```

2. **Don't skip TypeScript types**
   ```astro
   <!-- BAD -->
   const { title, subtitle } = Astro.props  // No types!
   ```

3. **Don't use generic names**
   ```astro
   <!-- BAD -->
   <div class="container">  <!-- Too generic -->
   <div class="wrapper">    <!-- Too generic -->
   ```

4. **Don't hardcode breakpoint values**
   ```css
   /* BAD */
   @media (min-width: 1024px) {
   ```

5. **Don't nest too deeply**
   ```astro
   <!-- BAD: Too many levels -->
   <Section>
   	<Row>
   		<Col>
   			<div>
   				<div>
   					<div>
   						<div>Content</div>
   					</div>
   				</div>
   			</div>
   		</Col>
   	</Row>
   </Section>
   ```

6. **Don't use inline styles unless absolutely necessary**
   ```astro
   <!-- BAD -->
   <div style="color: red; padding: 20px;">
   ```

7. **Don't skip documentation blocks**
   ```astro
   <!-- BAD -->
   ---
   import Component from './Component.astro'
   const { prop } = Astro.props
   ---
   ```

8. **Don't mix naming conventions**
   ```astro
   <!-- BAD -->
   <div class="heroSection__Title">  <!-- Mixed case -->
   ```

### ✅ DO

1. **Use class:list for dynamic classes**
   ```astro
   <div class:list={['base', { 'active': isActive }]}>
   ```

2. **Always define TypeScript types**
   ```astro
   type Props = {
   	title: string
   	subtitle?: string
   }
   const { title, subtitle } = Astro.props
   ```

3. **Use BEM-like naming with component prefix**
   ```astro
   <div class="step-card__title">
   ```

4. **Use Tailwind breakpoint utilities**
   ```css
   @apply lg:text-xl;
   ```

5. **Keep component structure flat**
   ```astro
   <Section>
   	<Row>
   		<Col span="12">
   			<Card>Content</Card>
   		</Col>
   	</Row>
   </Section>
   ```

6. **Use Tailwind utilities or scoped styles**
   ```astro
   <div class="bg-red-500 p-6">
   <!-- or -->
   <div class="custom-class">
   <style>
   	.custom-class {
   		@apply bg-red-500 p-6;
   	}
   </style>
   ```

7. **Always include documentation**
   ```astro
   ---
   // Component Name
   // ------------
   // Description: What it does
   // Properties:
   // - prop: description
   ---
   ```

8. **Use consistent kebab-case**
   ```astro
   <div class="step-card__title">
   ```

---

## Checklist for New Components

Before committing a new component, verify:

- [ ] Documentation block at the top
- [ ] TypeScript `type Props` defined
- [ ] Props destructured with defaults
- [ ] Semantic HTML elements used
- [ ] Class names follow kebab-case BEM pattern
- [ ] Mobile-first responsive design
- [ ] Uses Section/Row/Col for layout (if block)
- [ ] Images imported and optimized
- [ ] Alt text provided for all images
- [ ] No hardcoded breakpoint values
- [ ] Consistent with existing patterns
- [ ] No inline styles (unless necessary)
- [ ] `class:list` used for conditionals
- [ ] `classes` prop accepted for extension
- [ ] Works in both light and dark mode (if applicable)

---

## Quick Reference

### Import Paths
```typescript
// UI Components
import Section from '../../ui/Section.astro'
import Row from '../../ui/Row.astro'
import Col from '../../ui/Col.astro'
import Button from '../../ui/Button.astro'
import Card from '../../ui/cards/BasicCard.astro'

// Assets (from blocks/)
import image from '../../../assets/my-image.webp'

// Astro built-ins
import { Image } from 'astro:assets'
import { Icon } from 'astro-icon/components'
```

### Common Tailwind Classes
```css
/* Layout */
flex flex-col lg:flex-row items-center justify-center gap-4 lg:gap-8

/* Spacing */
p-6 lg:p-12 mb-6 lg:mb-12 mt-12 lg:mt-24

/* Typography */
text-base lg:text-lg font-bold text-neutral-700 dark:text-neutral-50

/* Colors */
bg-primary-500 text-white border-neutral-200

/* Sizing */
w-full lg:w-1/2 h-auto lg:h-screen

/* Effects */
rounded-lg shadow-lg hover:shadow-xl transition-all duration-300
```

### Grid Quick Reference
```astro
<!-- Full width -->
<Col span="12">

<!-- Half -->
<Col span="6">

<!-- Third -->
<Col span="4">

<!-- Quarter -->
<Col span="3">

<!-- Two-thirds -->
<Col span="8">

<!-- Responsive -->
<Col spanMobile="12" span="6">
```

---

## Version History

- **v1.0** (Jan 2026): Initial documentation

---

**This is a living document. Update it as patterns evolve.**
