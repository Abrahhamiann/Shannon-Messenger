# Motion foundation

Implemented in `apps/mobile/lib/app/design_system.dart`:

| Token | Duration | Purpose |
|---|---:|---|
| quick | 160 ms | Reserved for small control feedback |
| standard | 240 ms | Floating tab selection |
| entrance | 360 ms | Profile and unavailable-state entrance |

`ShannonReveal` fades and translates content by 8 logical pixels once, using
easeOutCubic. It returns the static child when MediaQuery.disableAnimations is
true. The floating navigation also uses zero-duration changes in that mode.
No ambient looping animation, animated encryption assertion, invented delivery
receipt, Rive runtime or Lottie asset is installed.

`ShannonPanel` and shared dimensions establish reusable components for the next
screen migration. Existing M2 animation remains in place except tab duration and
icon family. Message send/receive, reply, attachment, voice and shared-element
transitions are not implemented; they must follow real feature state, never
fabricated events. Test the complete flow under TalkBack, reduced motion and
large text before treating Phase E as finished.

Reference: https://docs.flutter.dev/ui/animations/overview
