# Push notification setup

## Current state

The app supports requesting alert/sound permission, registering its APNs token,
foreground banners, and opening notification settings. The paired screen can
copy the app token for a manual Apple console test or send a fixed test through
Val Town. App tokens and current alert permission synchronize on registration,
return to foreground, and explicit retry. Tokens are not logged or persisted locally.

The existing widget extension independently uploads its WidgetKit token to
`POST /device/token`. On September 8, 2026, all three APNs credentials were
configured in `sports-today`. The server's `tools/apns-credentials-check.ts`
passed identifier-format, private-key import, and P-256 signing checks without
exposing secrets. Sandbox alert and widget delivery were verified on September 8, and production
authentication and delivery were verified end to end thereafter.

| Channel | Token | APNs push type | Topic | Payload |
| --- | --- | --- | --- | --- |
| Visible alert | Containing app | `alert` | `plusjade.clark-view` | `aps.alert`, optional `aps.sound` |
| Widget refresh | WidgetKit | `widgets` | `plusjade.clark-view.push-type.widgets` | `aps.content-changed: true` |

Alert permission does not control WidgetKit refreshes. A visible push does not
itself reload the widget. Send both requests when an event needs both effects.
Widget refreshes are opportunistic; preserve the hourly timeline. Refreshing
the widget reads stored source data and does not ingest new upstream data.
The old app-background fallback is a third transport; do not reuse its token
storage category to represent visible-notification opt-in.

## First visible push: Apple console

1. In Xcode, select the `clark_view` target and confirm **Push Notifications**
   under Signing & Capabilities. The app now includes `aps-environment`.
   Enable Push Notifications for the App ID in the Apple Developer account and
   let automatic signing refresh the profile if necessary.
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

6. Verify a banner with the app open, then repeat with it backgrounded/locked.
   Tap the notification to open the app. Focus and the user's notification
   settings may affect presentation. APNs acceptance alone is not proof that an
   alert appeared; use the console's development delivery logs when diagnosing.

This is a real remote notification through APNs, without a server private key.
A code build alone does not verify delivery; the sandbox device checks below do.

## Live server and APNs environments

All builds use the same live Val Town endpoint and val-scoped SQLite database.
Branches isolate code, not the database or Apple delivery environments.
`device_alert_tokens` is keyed by install identifier plus `environment`; it stores
an app token, the last observed permission (`allowed`), and a persistent test cooldown.
Existing `device_push_tokens` remains the widget/legacy-background registration store.
Each legacy/widget install-kind row retains its environment; a new registration
replaces that row. Alert permission is independent from widget activity.

Development/ad hoc provisioning profiles provide `aps-environment`; the Swift
helper extracts that entitlement from the embedded profile. Missing/malformed
entitlements in an existing profile stop registration. App Store builds without
an embedded profile use production; simulator builds use sandbox. This no longer
depends on `DEBUG`. Validate a signed device build when one is available.

The existing `APNS_KEY_ID` and `APNS_AUTH_KEY` are **production-only** credentials.
`APNS_TEAM_ID` is shared. Xcode development builds require a separate sandbox key:
`APNS_SANDBOX_KEY_ID` and `APNS_SANDBOX_AUTH_KEY`. Both environments can register
against the live server; missing credentials return `MissingCredentials:sandbox`
or `MissingCredentials:production`, with no cross-environment fallback.

[Configure environment variables](https://www.val.town/x/plusjade/sports-today/environment-variables).
Never place private key contents in source or logs.

## Server registration and self-test

- `POST /device/notifications/register`: `{device,token,environment,allowed}`.
  Environment and Boolean permission are mandatory; malformed tokens are rejected.
- `POST /device/notifications/test`: `{device,token,environment}`. Requires the
  current token, allowed permission, and at least 60 seconds since the last test
  attempt. Sends fixed Clark View text, never caller-provided announcements.
- Success means APNs accepted the request, not that a banner appeared. Errors are
  visible in the app. APNs 410 removes only the exact alert token/environment;
  `BadDeviceToken` is retained for diagnosis because environment mismatch can cause it.
- Permission is the last state observed by the app; Settings changes synchronize
  next time the app runs. iOS itself enforces notification presentation permission.
- Registration follows this prototype's existing public install-ID API model;
  it is not full device authentication. The self-test requires token knowledge,
  but enrollment/auth hardening is still needed before broader consumer rollout.

Run `tools/alert-push-check.ts` in Val Town for signing and mocked transport checks,
plus disposable SQLite fixtures (cleaned up). It sends no real APNs requests.
The user confirmed receipt of the sandbox alert sent with the app test button.
The sandbox widget test also passed (see below). There are no automatic event rules or
arbitrary announcement endpoint.

## References

- [Notification permission](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [APNs registration](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)
- [Console testing](https://developer.apple.com/documentation/usernotifications/testing-notifications-using-the-push-notification-console)
- [WidgetKit pushes](https://developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications)
- [Create an Apple service key](https://developer.apple.com/help/account/keys/create-a-private-key/)

## Device verification — September 8, 2026

- Sandbox visible alert: user confirmed receipt using **Send Test Notification**.
- Sandbox WidgetKit push: APNs accepted the request at **20:50:27 UTC
  (1:50:27 PM Pacific)**; the user confirmed **Last Attempt** and **Last Success**
  both advanced to **1:50:27**, without a manual reload. Visible notification
  permission had not been enabled on this reinstalled app.
- The server topic was corrected to `plusjade.clark-view.push-type.widgets`.
  Using the widget extension bundle ID caused `DeviceTokenNotForTopic`.
- Add the widget to the Home Screen before testing; pairing alone does not
  register a WidgetKit token. After a reinstall/merge, verify the current
  install-to-device mapping before selecting a token for a test.
- Production alert and widget delivery were subsequently confirmed end to end, so
  both APNs environments are now proven.

## Event reminders

Automatic reminders are live. `sports-today` queues one notification per upcoming
event per device and sends a visible alert a configurable time beforehand, default
one hour. It uses the alert channel only; a reminder does not refresh the widget.

Delivery is gated by the parent's `REMINDERS_ENABLED` variable. While it is unset the
jobs still run and the queue still drains, recording what each row would have sent
without contacting APNs. See the parent's `docs/event-reminders.md` for the queue
model, the sizing rule and the configuration.
