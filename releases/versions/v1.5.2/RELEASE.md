# MacDictate v1.5.2

- Status: `local_only`
- Bundle: `1.5.2` / build `13`
- Public website rollout: pending trusted server access; not yet deployed.

## Changes

Desktop is free permanently, without activation, license checks or a subscription.
Local Whisper dictation and optional local text correction remain available.
New payment creation returns HTTP 410; old payment history and callbacks remain intact.
Legacy desktop clients receive free active access without changing billing records.

## Verification

The source/menu, diagnostic logger and backend HTTP harnesses passed locally.
The earlier local build was installed and synthetic speech was transcribed correctly.
Build 13 signing/notarization and public download verification are pending.
Older app binaries retain their old trial badge and offline grace behavior; install this free version to remove those checks permanently. The compatibility endpoint does not falsely mark a purchase as paid.

Live microphone/hotkey/paste UI was not verified: native UI automation times out.

## Rollback

Previous signed installer remains in v1.5.1 release history. Local pre-free application
is retained independently. Do not enable new payments as part of an application rollback.
