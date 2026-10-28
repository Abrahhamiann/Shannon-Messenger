# Bundled assets and provenance

Retrieved 2026-10-25. Assets are local; the app performs no font/icon CDN requests.
Full license notices are bundled and registered with Flutter's LicenseRegistry.
Hashes are in `ASSET_SHA256.json`.

| Asset | Source | License | Location |
|---|---|---|---|
| Manrope variable TTF | https://github.com/google/fonts/tree/main/ofl/manrope | SIL OFL 1.1 | apps/mobile/assets/fonts/Manrope[wght].ttf |
| Noto Sans Armenian variable TTF | https://github.com/google/fonts/tree/main/ofl/notosansarmenian | SIL OFL 1.1 | apps/mobile/assets/fonts/NotoSansArmenian[wdth,wght].ttf |
| Phosphor Regular/Fill fonts and selected glyph mappings | https://pub.dev/packages/phosphor_flutter/versions/2.1.0 | MIT | apps/mobile/assets/icons/; lib/app/icons.dart |

Manrope copyright: The Manrope Project Authors. Noto Sans Armenian copyright:
The Noto Project Authors. Phosphor copyright: Phosphor Icons. Preserve the bundled
OFL and MIT texts when distributing the application. Fonts are bundled as part
of the application, not sold separately. No font outlines were modified.

The Phosphor package's Dart wrapper cannot compile on Flutter 3.47.7 because it
extends the now-final IconData class. Its dependency was removed after verifying
that failure. The MIT font files are bundled directly, with a small static
IconData mapping; the wrapper itself is not used or patched in the pub cache.

The official image_picker 1.2.4 dependency is source code, not artwork. Its
transitive notices are included through Flutter's generated package licenses.
No photo, avatar, third-party illustration, Rive or Lottie file was downloaded.
The profile preview images use synthetic public fixture text and local glyphs.

Evaluated but not imported: Rive Marketplace, LottieFiles, Lordicon and Mobbin.
See UI_UX_REDESIGN.md for sources and the asset-selection rationale.

The selected ribbon emblem was supplied by the user on 2026-10-27 as Glossy Blue Flame Ribbon Emblem.png. It is copied verbatim into Flutter branding and Android resources; no third-party license or authorship claim is inferred.
