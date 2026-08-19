# Colima Bar

Colima Bar is a menu-bar-only macOS app for an existing [Colima](https://github.com/abiosoft/colima) installation. It provides quick VM and Docker container controls without a Dock icon or a replacement runtime.

## Features

- Discover Colima and Docker from Homebrew, MacPorts, or the app process PATH.
- Start, stop, and restart each Colima profile.
- View profile CPU, memory, disk, architecture, and runtime information.
- Group Docker containers by Compose project.
- Start, stop, restart, and remove containers.
- Open container logs and shells in Ghostty without Apple Events permissions.
- Open published web ports in the default browser.
- Open bind mounts in Finder and copy container details.
- Clean stopped containers, unused images, unused volumes, and unused networks with confirmation.
- Launch Colima Bar at macOS login and optionally start Colima when the app launches.
- Run entirely from the menu bar with no Dock icon.

Container controls require a Docker runtime profile and the Docker CLI. VM controls also work for other Colima runtimes.

## Requirements

- macOS 14 or later
- Colima installed and available in `/opt/homebrew/bin`, `/usr/local/bin`, `/opt/local/bin`, or `PATH`
- Docker CLI for Docker container management
- Ghostty in `/Applications` or `~/Applications` for logs and interactive shells
- Swift 6 and Xcode Command Line Tools to build from source

## Build and run

```sh
./script/build_and_run.sh
```

The script builds a SwiftPM executable, stages `dist/ColimaBar.app`, and launches the app bundle. The app appears as a shipping-box icon in the macOS menu bar.

Use `./script/build_and_run.sh --verify` to build, launch, and confirm that the process is running. The Codex project Run action uses the same script.

## Login startup

The first launch requests registration as a macOS login item. You can change this in Colima Bar settings. Keep `Start Colima on Launch` enabled to start the selected Colima profile after login.

For reliable login-item behavior, move `ColimaBar.app` from `dist` to `/Applications`, launch that copy once, and enable `Launch at Login` in the app settings.

## Test

```sh
swift test
```
