# camera

`uvctui` — a TUI for the UVC controls of the Apple Thunderbolt Display's
built-in FaceTime HD camera.

    brew install libusb
    make && make install      # -> ~/.local/bin/uvctui

## Why

macOS exposes almost nothing for this camera through AVFoundation:

    autoExpose:             false
    continuousAutoExposure: true
    locked:                 true
    white balance:          no control at all

Manual exposure and the exposure-bias APIs are `API_UNAVAILABLE(macos)`, so
GUI apps built on AVFoundation cannot brighten this camera. CameraController
greys "Manual" out for the same reason. The camera itself is more capable than
that — it reports an AE-mode bitmap of `0x03` (Manual + Auto) and is already
sitting in Manual — so `uvctui` skips AVFoundation and drives the UVC control
requests over libusb directly.

## Notes

- **There is no gain control.** The Processing Unit advertises bmControls
  `0x00157f`, with D9 (Gain) clear. No app will ever expose gain on this
  camera; use `brightness` and `gamma` instead.
- `VDCAssistant` is the exclusive owner of the video interface and runs
  auto-exposure *in software* by writing the exposure-time register. Expect it
  to overwrite `exposure` while an app is streaming. The Processing Unit
  controls (brightness, gamma, contrast, wb) are not touched by that loop and
  do stick.
- Settings live in the camera and reset when it loses power, which includes
  replugging the Thunderbolt cable.
