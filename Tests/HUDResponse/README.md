# HUD response checks

Run from the repository root on macOS. These checks compile the production brightness
managers with stub XPC and presentation dependencies. Hardware calls are suspended
explicitly to check immediate presentation, ordered writes, repeated keys, stale
reads, slider replacement, clamping, and recovery from a rejected hardware write.
They do not change actual brightness or user settings.

```sh
mkdir -p /private/tmp/dino-hud-response-check
xcrun swiftc -parse-as-library -module-cache-path /private/tmp/dino-hud-response-check/ModuleCache boringNotch/managers/BrightnessManager.swift Tests/HUDResponse/BrightnessResponseCheck.swift -o /private/tmp/dino-hud-response-check/check
/private/tmp/dino-hud-response-check/check
```
