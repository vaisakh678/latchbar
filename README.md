# Latchbar

A free, open-source menu bar app that locks your Mac apps behind **Touch ID, Apple Watch, or your login password**.

Pick the apps you want to protect. When one of them is opened, Latchbar hides it and asks you to authenticate. Nothing is stored or sent anywhere: authentication goes through macOS's own LocalAuthentication, so Latchbar never sees your password or fingerprint.

## Features

- Lock any app; unlock with Touch ID, a paired Apple Watch, or your password
- Grace period: an unlocked app relocks immediately, after 1–60 minutes away, or only when it quits
- Relocks everything when the Mac sleeps or the screen locks
- Pausing, quitting, and opening Settings all require authentication
- Lives in the menu bar, no Dock icon, launch at login

## What it is (and isn't)

Latchbar stops casual snooping — someone borrowing your already-unlocked Mac. It is **not** a security boundary: anyone at the keyboard can still quit it from Activity Monitor or Terminal, and a locked app's window may flash for a moment before it's hidden. For real protection, lock your Mac.

## Building

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open Latchbar.xcodeproj
```

Debug builds are ad-hoc signed, so "Launch at login" won't stick until you build with a real signing identity.

## Why not the Mac App Store?

A sandboxed app can't hide or reveal other apps, so Latchbar is distributed as a notarized download instead.

## Roadmap

- Cover the app with an overlay instead of hiding it (no window flash)
- Hide locked apps' windows from Mission Control and the app switcher
- Lock folders and files
- Homebrew Cask

## License

MIT
