#!/bin/bash
set -euo pipefail

# Image Optimization Script
# Converts PNG images to WebP and updates references

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKETING_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLIC_DIR="$MARKETING_DIR/public"
CONTENT_DIR="$MARKETING_DIR/src/content"
CONFIG_DIR="$MARKETING_DIR/src/config"
COMPONENTS_DIR="$MARKETING_DIR/src/components"

echo "🖼️  Frontman Marketing - Image Optimization"
echo "==========================================="
echo ""
echo "Working directory: $MARKETING_DIR"
echo ""

# Check dependencies
if ! command -v cwebp &> /dev/null; then
    echo "❌ Error: cwebp not found"
    echo "Install it with: brew install webp"
    exit 1
fi

echo "✅ Dependencies installed"
echo ""

# Function to convert image to WebP
convert_to_webp() {
    local input="$1"
    local quality="${2:-80}"
    local output="${input%.png}.webp"
    
    if [ -f "$output" ]; then
        echo "⏭️  Skipping $input (WebP already exists)"
        return 0
    fi
    
    echo "🔄 Converting $(basename "$input") to WebP (quality=$quality)..."
    cwebp -q "$quality" "$input" -o "$output" 2>&1 | grep -v "^Saving file"
    
    local original_size=$(stat -f%z "$input" 2>/dev/null || stat -c%s "$input")
    local webp_size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output")
    local savings=$((100 - (webp_size * 100 / original_size)))
    
    echo "✅ Saved $savings% ($(numfmt --to=iec-i --suffix=B $original_size) → $(numfmt --to=iec-i --suffix=B $webp_size))"
}

# Convert blog images
echo "📝 Converting blog images..."
if [ -d "$PUBLIC_DIR/blog" ]; then
    cd "$PUBLIC_DIR/blog"
    for png in *.png; do
        [ -f "$png" ] || continue
        convert_to_webp "$png" 80
    done
else
    echo "⚠️  Blog directory not found: $PUBLIC_DIR/blog"
fi
echo ""

# Convert OG images
echo "📱 Converting OG images..."
cd "$PUBLIC_DIR"
if [ -f "og.png" ]; then
    convert_to_webp "og.png" 85
else
    echo "⚠️  og.png not found"
fi

if [ -f "og-twitter.png" ]; then
    convert_to_webp "og-twitter.png" 85
else
    echo "⚠️  og-twitter.png not found"
fi
echo ""

# Update references in markdown files
echo "🔍 Updating markdown references..."
if [ -d "$CONTENT_DIR/blog" ]; then
    cd "$CONTENT_DIR/blog"
    for md in *.md; do
        [ -f "$md" ] || continue
        if grep -q "\.png" "$md"; then
            echo "  📄 $md"
            sed -i.bak 's/\.png/\.webp/g' "$md"
            rm -f "$md.bak"
        fi
    done
else
    echo "⚠️  Content blog directory not found: $CONTENT_DIR/blog"
fi
echo ""

# Update config references
echo "⚙️  Updating config references..."
if [ -f "$CONFIG_DIR/config.ts" ]; then
    cd "$CONFIG_DIR"
    if grep -q "og.*\.png" config.ts; then
        echo "  📄 config.ts"
        sed -i.bak "s|'/og\.png'|'/og.webp'|g" config.ts
        rm -f config.ts.bak
    fi
else
    echo "⚠️  config.ts not found"
fi
echo ""

# Update component references
echo "🧩 Updating component references..."
SEO_FILE="$COMPONENTS_DIR/blocks/head/partials/Seo.astro"
if [ -f "$SEO_FILE" ]; then
    if grep -q "og.*\.png" "$SEO_FILE"; then
        echo "  📄 Seo.astro"
        sed -i.bak "s|'/og-twitter\.png'|'/og-twitter.webp'|g" "$SEO_FILE"
        rm -f "$SEO_FILE.bak"
    fi
else
    echo "⚠️  Seo.astro not found"
fi
echo ""

# Summary
echo "✨ Optimization complete!"
echo ""
echo "Next steps:"
echo "1. Review the WebP files in public/blog/ and public/"
echo "2. Test the site locally: make dev"
echo "3. Check image loading: open http://localhost:4321"
echo "4. Delete original PNG files if everything looks good:"
echo "   rm public/blog/*.png public/og*.png"
echo ""
echo "Optional: Convert GIF animations to video for more savings"
echo "See IMAGE_OPTIMIZATION.md for details"
