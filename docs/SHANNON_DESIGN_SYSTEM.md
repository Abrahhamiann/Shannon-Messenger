# Shannon design system

The supplied blue ribbon PNG is used verbatim at
apps/mobile/assets/branding/shannon_ribbon.png and in Android drawable-nodpi.
It is 1254 × 1254, 505421 bytes, with alpha; its geometry is not redrawn.
Flutter uses BoxFit.contain. Android uses an inset foreground in a 108dp adaptive
icon, navy background, and the same emblem for the system splash. The normal
application ID remains dev.shannon.shannon.

Dark tokens: background #061321, deep atmosphere #030C17, surface #0D2037,
foreground #F3F7FF, secondary #9DB1CB, outline #183B5C. Light surfaces remain
white with dark foregrounds. Manrope and NotoSansArmenian remain bundled.
Primary controls use a blue gradient, rounded 52px minimum target and subtle
press feedback. Shared panels, feature rows and entrance motion remain reusable.

Welcome uses deterministic stars/radial atmosphere, the original ribbon,
three privacy features and actual signup/existing-account navigation. Signup is
a scrollable constrained form with required nickname, optional username and
photo, explicit recovery limitation, and a real server operation. Existing
account shows its saved nickname/photo. Chats links to real contact operations.
No E2EE, successful recovery or message-delivery claims are invented.

Generated widget previews cover dark/light phone layouts. UI artwork is inspired
by the reference, not a pixel-identical reproduction: the globe/security artwork
is not supplied as individual assets, and no unrelated generated logo is used.
The reference's recovery-secret screen is not activated because recovery is not
implemented. Full TalkBack, largest-font/orientation matrix and physical launcher
mask review remain manual acceptance gates.

Localization uses Flutter ARB generation with en/hy/ru, persisted language
choice, and English fallback. Current translated scope: onboarding and App Lock
settings; legacy contact/profile/settings strings and native lock cover still
need translation. Language UI states this explicitly. Fonts alone are not counted
as completed localization.
