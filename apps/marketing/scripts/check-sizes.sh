#!/bin/bash

# Check file sizes for image optimization comparison

PUBLIC_DIR="apps/marketing/public"

echo "📊 File Size Comparison"
echo "======================="
echo ""

# Function to get human-readable size
get_size() {
    if [ -f "$1" ]; then
        ls -lh "$1" | awk '{print $5}'
    else
        echo "N/A"
    fi
}

# GIF vs MP4
echo "🎬 Animation Files:"
echo "-------------------"
echo "select-element.gif: $(get_size "$PUBLIC_DIR/select-element.gif")"
echo "select-element.mp4: $(get_size "$PUBLIC_DIR/select-element.mp4")"
echo ""
echo "code-change.gif: $(get_size "$PUBLIC_DIR/code-change.gif")"
echo "code-change.mp4: $(get_size "$PUBLIC_DIR/code-change.mp4")"
echo ""

# Calculate savings if both exist
if [ -f "$PUBLIC_DIR/select-element.gif" ] && [ -f "$PUBLIC_DIR/select-element.mp4" ]; then
    gif_size=$(stat -f%z "$PUBLIC_DIR/select-element.gif" 2>/dev/null || stat -c%s "$PUBLIC_DIR/select-element.gif")
    mp4_size=$(stat -f%z "$PUBLIC_DIR/select-element.mp4" 2>/dev/null || stat -c%s "$PUBLIC_DIR/select-element.mp4")
    savings=$((100 - (mp4_size * 100 / gif_size)))
    echo "select-element savings: $savings%"
fi

if [ -f "$PUBLIC_DIR/code-change.gif" ] && [ -f "$PUBLIC_DIR/code-change.mp4" ]; then
    gif_size=$(stat -f%z "$PUBLIC_DIR/code-change.gif" 2>/dev/null || stat -c%s "$PUBLIC_DIR/code-change.gif")
    mp4_size=$(stat -f%z "$PUBLIC_DIR/code-change.mp4" 2>/dev/null || stat -c%s "$PUBLIC_DIR/code-change.mp4")
    savings=$((100 - (mp4_size * 100 / gif_size)))
    echo "code-change savings: $savings%"
fi
echo ""

# PNG vs WebP (if WebP exists)
echo "🖼️  Blog Images (sample):"
echo "------------------------"
if [ -d "$PUBLIC_DIR/blog" ]; then
    cd "$PUBLIC_DIR/blog"
    for png in post-01-cover.png post-02-cover.png; do
        if [ -f "$png" ]; then
            echo "$png: $(get_size "$png")"
            webp="${png%.png}.webp"
            if [ -f "$webp" ]; then
                echo "$webp: $(get_size "$webp")"
                png_size=$(stat -f%z "$png" 2>/dev/null || stat -c%s "$png")
                webp_size=$(stat -f%z "$webp" 2>/dev/null || stat -c%s "$webp")
                savings=$((100 - (webp_size * 100 / png_size)))
                echo "  Savings: $savings%"
            fi
            echo ""
        fi
    done
fi

# OG images
echo "📱 OG Images:"
echo "-------------"
echo "og.png: $(get_size "$PUBLIC_DIR/og.png")"
if [ -f "$PUBLIC_DIR/og.webp" ]; then
    echo "og.webp: $(get_size "$PUBLIC_DIR/og.webp")"
fi
echo ""
echo "og-twitter.png: $(get_size "$PUBLIC_DIR/og-twitter.png")"
if [ -f "$PUBLIC_DIR/og-twitter.webp" ]; then
    echo "og-twitter.webp: $(get_size "$PUBLIC_DIR/og-twitter.webp")"
fi
