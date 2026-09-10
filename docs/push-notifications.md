# Push notification setup

## Current state

The app requests alert/sound permission, registers its APNs token, shows foreground
banners, and can open notification settings. The paired screen can copy the app token
for a manual Apple console test or trigger a fixed self-test through Val Town. Tokens
are not logged or persisted locally.

The widget extension independently uploads its WidgetKit token to `POST /device/token`.
Delivery evidence and recheck conditions are scoped below.

| Channel | Token | APNs push type | Topic | Payload |
| --- | --- | --- | --- | --- |
| Visible alert | Containing app | `alert` | `plusjade.clark-view` | `aps.alert`, optional `aps.sound` |
| Widget refresh | WidgetKit | `widgets` | `plusjade.clark-view.push-type.widgets` | `aps.content-changed: true` |

Alert permission does not control WidgetKit refreshes, and a visible push does not
itself reload the widget — send both requests when an event needs both effects.
Widget refreshes are opportunistic and preserve the hourly timeline; they read stored
source data and do not ingest new upstream data. The legacy app-background fallback is
a third transport; do not reuse its token storage category to represent
visible-notification opt-in.

**Gotcha:** the widget APNs topic must use the *containing app's* bundle ID
(`plusjade.clark-view.push-type.widgets`), not the extension's — using the extension
bundle ID produces `DeviceTokenNotForTopic`.

**Gotcha:** the widget must be added to the Home Screen before testing; pairing alone
does not register a WidgetKit token. After a reinstall/merge, re-verify the current
install-to-device mapping before picking a token for a test.

## First visible push: Apple console

1. In Xcode, select the `clark_view` target and confirm **Push Notifications** under
   Signing & Capabilities. The app includes `aps-environment`. Enable Push
   Notifications for the App ID in the Apple Developer account and let automatic
   signing refresh the profile if necessary.
2. Build and run on your iPhone. Pair, tap **Enable Notifications**, and allow
   notifications. Confirm **Registered with Apple**.
3. Tap **Copy APNs Token for Testing** and paste it directly into
   [Apple's Push Notifications Console](https://developer.apple.com/notifications/push-notifications-console/).
4. Choose app `plusjade.clark-view`, the **development** environment for an
   Xcode development-signed build, push type **alert**, and priority **10**.
   TestFlight/App Store builds use production. The signed entitlement determines
   the environment; a custom build configuration name does not.
5. Send this payload:

   ```json
   {"aps":{"alert":{"title":"Clark View","body":"Push notifications are connected."},"sound":"default"}}
   ```

6. Verify a banner with the app open, then repeat with it backgrounded/locked. Tap
   the notification to open the app. Focus and the user's notification settings may
   affect presentation. APNs acceptance alone is not proof that an alert appeared;
   use the console's development delivery logs when diagnosing.

This is a real remote notification through APNs, without a server private key. A code
build alone does not verify delivery — device checks do.

## Live server and APNs environments

All builds use the same live Val Town endpoint and val-scoped SQLite database.
Branches isolate code, not the database or Apple delivery environments.
`device_alert_tokens` is keyed by install identifier plus `environment`; it stores an
app token, the last observed permission (`allowed`), and a persistent test cooldown.
`device_push_tokens` is the separate widget/legacy-background registration store.
Each legacy/widget install-kind row retains its environment; a new registration
replaces that row. Alert permission is independent from widget activity.

Development/ad hoc provisioning profiles provide `aps-environment`; the Swift helper
extracts that entitlement from the embedded profile. Missing/malformed entitlements in
an existing profile stop registration. App Store builds without an embedded profile
use production; simulator builds use sandbox. This does not depend on `DEBUG`.

`APNS_KEY_ID` and `APNS_AUTH_KEY` are **production-only** credentials; `APNS_TEAM_ID`
is shared. Xcode development builds need a separate sandbox key:
`APNS_SANDBOX_KEY_ID` and `APNS_SANDBOX_AUTH_KEY`. Both environments register against
the same live server; missing credentials return `MissingCredentials:sandbox` or
`MissingCredentials:production`, with **no cross-environment fallback**.

[Configure environment variables](https://www.val.town/x/plusjade/app-clarkview/environment-variables).
Never place private key contents in source or logs.

## Server registration and self-test

- `POST /device/notifications/register`: `{device,token,environment,allowed}`.
  Environment and Boolean permission are mandatory; malformed tokens are rejected.
- `POST /device/notifications/test`: `{device,token,environment}`. Requires the
  current token, allowed permission, and at least 60 seconds since the last test
  attempt. Sends fixed Clark View text, never caller-provided announcements.
- Success means APNs accepted the request, not that a banner appeared. Errors are
  visible in the app. APNs 410 removes only the exact alert token/environment;
  `BadDeviceToken` is retained for diagnosis because an environment mismatch can
  cause it.
- Permission is the last state observed by the app; Settings changes synchronize
  next time the app runs. iOS itself enforces notification presentation permission.
- Registration follows this prototype's existing public install-ID API model; it is
  not full device authentication. The self-test requires token knowledge, but
  enrollment/auth hardening is still needed before broader consumer rollout.

Run `tools/alert-push-check.ts` in Val Town for signing and mocked transport checks
plus disposable SQLite fixtures (cleaned up automatically); it sends no real APNs
requests. Event reminders are described below; there is no arbitrary announcement endpoint.

## Delivery verification status

Sandbox alert and widget delivery were recorded on 2026-09-08. The later main-branch
update also recorded successful production authentication and alert/widget delivery;
it did not specify the production test date or build. Evidence pointer:
`git show 06994cd:docs/push-notifications.md`, "Device verification — September 8, 2026".
These are recorded device outcomes, not fresh tests performed during this rebase.

Recheck the affected environment after changes to signing, credentials, token
registration, or push delivery. Update this section with the test date,
build/environment, an evidence pointer, and observed alert/widget outcomes;
APNs acceptance alone is insufficient.

## References

- [Notification permission](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [APNs registration](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)
- [Console testing](https://developer.apple.com/documentation/usernotifications/testing-notifications-using-the-push-notification-console)
- [WidgetKit pushes](https://developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications)
- [Create an Apple service key](https://developer.apple.com/help/account/keys/create-a-private-key/)

## Event reminders

Automatic reminders are live. `app-clarkview` queues one notification per upcoming
event per device and sends a visible alert a configurable time beforehand, default
one hour. It uses the alert channel only; a reminder does not refresh the widget.

Delivery is gated by the parent's `REMINDERS_ENABLED` variable. While it is unset the
jobs still run and the queue still drains, recording what each row would have sent
without contacting APNs. See the parent's `docs/event-reminders.md` for the queue
model, the sizing rule and the configuration.
