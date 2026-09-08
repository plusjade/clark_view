# Push notification setup

## Current state

The app supports requesting alert/sound permission, registering its APNs token,
foreground banners, and opening notification settings. The paired screen can
copy the app token for a manual Apple console test. Tokens are not logged or
persisted locally. App tokens are **not yet uploaded to Val Town**.

The existing widget extension independently uploads its WidgetKit token to
`POST /device/token`. As checked on September 8, 2026, `sports-today` has none of
the three required APNs credentials, so server widget delivery is skipped.

| Channel | Token | APNs push type | Topic | Payload |
| --- | --- | --- | --- | --- |
| Visible alert | Containing app | `alert` | `plusjade.clark-view` | `aps.alert`, optional `aps.sound` |
| Widget refresh | WidgetKit | `widgets` | `plusjade.clark-view.ClarkViewWidget.push-type.widgets` | `aps.content-changed: true` |

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
No notification has been sent or device delivery verified by the code build.

## Connect Val Town after the console test

Create an APNs signing key in
[Apple Developer → Keys](https://developer.apple.com/account/resources/authkeys/list).
Choose environment and scope that cover the intended development/production
delivery and app/widget topics. Environment-specific keys may require separate
server configuration; the existing sender assumes a single key set.
Keep the downloaded `.p8` private and store it directly in Val Town environment
variables rather than in this repository or chat:

- `APNS_KEY_ID`: the key identifier from Apple.
- `APNS_TEAM_ID`: the Apple team owning the app (Xcode currently uses `8ADZL76VCT`).
- `APNS_AUTH_KEY`: the complete PEM contents of the `.p8` file.

[Configure sports-today environment variables](https://www.val.town/x/plusjade/sports-today/environment-variables).

Remaining server work after credential/connection validation:

- Add a distinct visible-token registration category, including schema migration,
  route validation, permission synchronization, and retriable app uploads.
- Preserve widget-token preference only for refresh delivery; visible delivery
  must explicitly select the app token, never fall back to the widget token.
- Add a sender using `alert`, the app topic, and explicit APNs outcomes. Keep test
  sending private or authenticated; do not expose an anonymous arbitrary sender.
- Test one registered install, then independently verify a WidgetKit push causes
  a timeline fetch. Add event rules only after both transports are verified.

## References

- [Notification permission](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [APNs registration](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)
- [Console testing](https://developer.apple.com/documentation/usernotifications/testing-notifications-using-the-push-notification-console)
- [WidgetKit pushes](https://developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications)
- [Create an Apple service key](https://developer.apple.com/help/account/keys/create-a-private-key/)
