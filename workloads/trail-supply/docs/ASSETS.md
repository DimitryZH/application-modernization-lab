# Trail Supply graphical assets

The owner supplied 18 PNG images in two packages (10 and 8). All displayed
photographs, the wordmark and icon were generated specifically for this fictional
demo with ChatGPT image generation. No stock source URL, photographer attribution
or third-party image license is asserted. The upstream Apache-2.0 code/license
and inherited utility-art notices remain separate and preserved.

[asset-inventory.json](../asset-inventory.json) records the original package
filenames, visual mapping, dimensions, original/final sizes, processing and final
SHA-256 values. Local source directories and personal paths are not recorded.

| Selected content | Local destination under frontend static |
|---|---|
| Mountain wordmark / mountain-trail icon | `branding/trail-supply-logo.png`, `branding/trail-supply-icon.png` |
| Mountain sunrise campsite | `images/hero/mountain-campsite.jpg` |
| Hiker overlooking mountains | `images/lifestyle/hiking-mountain-view.jpg` |
| Illuminated tent at dusk | `images/lifestyle/camping-at-dusk.jpg` |
| Campsite equipment arrangement | `images/lifestyle/outdoor-essentials.jpg` |
| Hiker on a misty forest trail | `images/lifestyle/forest-trail.jpg` |
| Nine individual catalog products | `img/products/` with descriptive product slugs |

All 18 assets were inspected visually. No missing or ambiguous assignment was
found. The styled backpack and alpine-lake tent are approved optional promotional
images and were not copied; neither is represented as an alternate catalog view.
Lifestyle props are not individually offered for sale.

## Delivery and quality

- Supplied total: 35,948,616 bytes (18 images).
- Selected source total: 30,803,104 bytes (16 images).
- Delivered selected images: 6,879,411 bytes; favicon derivative: 21,931 bytes.
- Photographs: one JPEG conversion, quality 94, 4:4:4 chroma, progressive encoding;
  original resolution/aspect ratio, no resampling or upscaling. No duplicate
  original/optimized copies are committed.
- Branding PNG files retain their original bytes, resolution and transparency.
  Favicon contains 16/32/48/64/128-pixel derivatives of the supplied icon.
- Obsolete inherited product/promotional rasters were removed from Trail Supply
  only. Original Online Shop assets remain unchanged.

CSS and system fonts are entirely local. The new layouts use native CSS Grid and
Flexbox, so Bootstrap is no longer needed; its CDN CSS/JS and Google Font/Symbol
requests were removed rather than adding a vendor framework. Existing internal
utility icons and the explicit legacy `CYMBAL_BRANDING` favicon override remain
available. The default favicon uses the supplied Trail Supply icon.
