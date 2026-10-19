# MacDictate v1.5.2

- Status: `public_stable`
- Bundle: `1.5.2` / build `13`
- Distribution: GitHub Releases; static product page uses GitHub Pages (deployment recorded separately).
- Source commit: `b8158a6a73f33e07cf548fa46658511f95c59811`
- Public release: https://github.com/alexfisenkov/MacDictate/releases/tag/v1.5.2
- SHA256: `8cd4c00cb2ddaa7fef2f747cee8b28f4d46b6e3b317a8e39206ac04c3752a261`

## Changes

Desktop is free permanently, without activation, license checks or a subscription.
Local Whisper dictation and optional local text correction remain available.
New payment creation returns HTTP 410; old payment history and callbacks remain intact.
Legacy desktop clients receive free active access without changing billing records.

## Verification

The source/menu, diagnostic logger and backend HTTP harnesses passed locally. Update checks use GitHub directly, with no request to the retired server.
The earlier local build was installed and synthetic speech was transcribed correctly.
Build13 signed/notarized/stapled, Gatekeeper and mounted-install checks: PASS. GitHub reports identical digests for the versioned DMG and stable alias; public-byte read-back PASS. GitHub Pages14-file HTTPS read-back PASS.
Older app binaries retain their old trial badge and offline grace behavior; install this free version to remove those checks permanently. The compatibility endpoint does not falsely mark a purchase as paid.

Live microphone/hotkey/paste UI was not verified: native UI automation times out.

## Rollback

Local owner rollback preserves the earlier FREE build12 independently. v1.5.1 remains historical; it retains old licensing and is not the recommended free-app rollback. New public fixes must preserve free access and be signed/notarized again. Do not enable new payments as part of rollback.

## Verification limits

Live microphone/hotkey/paste remains NOT_RUN (native UI timeout); installed automatic-backend WhisperRunner synthetic speech passed. Optional Qwen3B model rights are separate from free MacDictate/Whisper, as explicitly stated in RU/EN terms. Pages made three automatic deployments during preparation; final run39245114809 succeeded.
