# APNs registration checklist for TestFlight

Clark View receives WidgetKit refresh pushes, not user-visible notification alerts.
The widget extension registers its own token and the server sends a `widgets` push
to the widget topic. TestFlight is a **production APNs** deployment even when the
audience is internal.

Use this checklist before building the test sender. Apple references:

- [Enable push notifications for an App ID](https://developer.apple.com/help/account/capabilities/configure-push-notifications)
- [Create and manage APNs signing keys](https://developer.apple.com/help/account/capabilities/communicate-with-apns-using-authentication-tokens)
- [Establish a token-based APNs connection](https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns)
- [Register with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)

## Environment map (do not mix these columns)

| Install source | Token recorded as | APNs host used to send | Signed entitlement |
| --- | --- | --- | --- |
| Xcode debug install | `sandbox` | `api.sandbox.push.apple.com:443` | `aps-environment = development` |
| TestFlight (internal or external) | `production` | `api.push.apple.com:443` | `aps-environment = production` |
| App Store | `production` | `api.push.apple.com:443` | `aps-environment = production` |

An APNs device token belongs to the environment that issued it. A sandbox token
sent to the production host (or the reverse) will not work. Reinstalling or
restoring can also change a token, so always use the latest token uploaded by the
specific installation under test.

An APNs token-signing `.p8` key is not a sandbox key or a production key: the same
key can authenticate to either host, subject to its Apple Developer account scope.
The environment choice is the APNs host plus the matching device token. Do not
confuse the signing key with the per-install device token.

## 1. Confirm identifiers and ownership

- [ ] In Certificates, Identifiers & Profiles, select team `8ADZL76VCT`.
- [ ] Confirm the containing app's explicit bundle ID is
      `plusjade.clark-view`.
- [ ] Confirm the widget extension's explicit bundle ID is
      `plusjade.clark-view.ClarkViewWidget`.
- [ ] Treat the extension as the push recipient. Its APNs topic is:

      ```text
      plusjade.clark-view.ClarkViewWidget.push-type.widgets
      ```

- [ ] Enable the Push Notifications capability for the widget extension App ID.
      Only enable it for the containing app as well if the legacy app-background
      fallback is intentionally retained and tested.
- [ ] After changing an App ID capability, regenerate or refresh provisioning
      profiles. An old profile does not acquire the new entitlement by itself.

## 2. Create the server credential

Prefer token authentication (`.p8`) over separate APNs certificates.

- [ ] In **Users and Access > Integrations > Keys** (or Certificates,
      Identifiers & Profiles > Keys, depending on the current portal UI), create
      an APNs key with the scope needed for the Clark View topic.
- [ ] Record the **Key ID** and **Team ID**. Download the `.p8` file once and put
      it directly in the server's secret store.
- [ ] Configure the server secrets:

      | Server setting | Value |
      | --- | --- |
      | `APNS_KEY_ID` | Apple key ID; not the Team ID |
      | `APNS_TEAM_ID` | `8ADZL76VCT` |
      | `APNS_AUTH_KEY` | Complete contents of the downloaded `.p8` private key |
      | `APNS_WIDGET_TOPIC` | `plusjade.clark-view.ClarkViewWidget.push-type.widgets` |

- [ ] If `APNS_APP_TOPIC` remains configured for the legacy fallback, set it to
      `plusjade.clark-view`; never use that app topic for a WidgetKit token.
- [ ] Never place the `.p8` key in this repository, an Xcode build setting, the
      app bundle, app code, logs, screenshots, or chat. Rotate the key immediately
      in the Apple portal if it is exposed.
- [ ] Note who owns the key and how it will be revoked/rotated. Revoking it affects
      every service using that key, so check its scope before doing so.

## 3. Produce and inspect the TestFlight archive

The checked-in widget entitlement says `development` for local development.
Distribution signing must produce `production`; do not infer the shipped value by
reading the source entitlement file or from the build configuration name alone.

- [ ] In Xcode, select the `clark_view` target and the correct development team.
      Confirm **Automatically manage signing** (or the intended distribution
      profile) resolves without errors.
- [ ] Repeat for `ClarkViewWidgetExtension`. Confirm Push Notifications appears
      under Signing & Capabilities and the distribution profile includes it.
- [ ] Archive with the normal Release/TestFlight flow, then export or locate the
      archived app in Xcode Organizer.
- [ ] Inspect the actual signed extension, replacing the path below with the
      archive path:

      ```sh
      codesign -d --entitlements :- \
        ClarkView.xcarchive/Products/Applications/clark_view.app/PlugIns/ClarkViewWidgetExtension.appex
      ```

- [ ] Stop if the output does not contain:

      ```xml
      <key>aps-environment</key>
      <string>production</string>
      ```

- [ ] Also verify the signed extension identifier and application identifier:

      ```sh
      codesign -dvv \
        ClarkView.xcarchive/Products/Applications/clark_view.app/PlugIns/ClarkViewWidgetExtension.appex
      ```

- [ ] Upload that archive to App Store Connect and install it from **TestFlight**.
      Do not use an Xcode-installed debug build for the production-path test.

## 4. Capture the correct TestFlight token

- [ ] Launch the TestFlight app and add the Clark View widget. WidgetKit invokes
      the push handler when its token becomes available or changes.
- [ ] Confirm the server has a current, active widget token for this installation
      with environment exactly `production`. Inspect metadata only; do not copy
      the full token into tickets, chat, source, or routine logs.
- [ ] Confirm the token kind is `widget`, not a legacy app token.
- [ ] Confirm the app sent the same stable Clark View device ID used by pairing.
- [ ] If only a `sandbox` token appears, verify the app was actually installed
      from TestFlight and not launched over Xcode. Delete the stale installation,
      reinstall from TestFlight, re-add/open the widget as needed, and wait for a
      fresh registration.

The current client labels `DEBUG` builds as `sandbox` and non-`DEBUG` builds as
`production`. That matches Xcode Debug and the current TestFlight Release flow,
but the signed-entitlement inspection above remains the authority. Revisit this
assumption before introducing custom build configurations.

## 5. Preflight the eventual programmatic test

Use a local/server-side script first. **Do not send directly from an in-app
button** because that would require shipping the APNs private key. If a button is
later useful, it should call a narrowly authorized server diagnostic endpoint;
the server must own the key and choose the token associated with the authenticated
device.

For the first TestFlight push, verify that the sender will use all of these values:

| APNs request field | Required test value |
| --- | --- |
| Host | `https://api.push.apple.com` (production) |
| Method/path | `POST /3/device/<latest production widget token>` |
| `authorization` | `bearer <short-lived JWT signed by the .p8 key>` |
| `apns-topic` | `plusjade.clark-view.ClarkViewWidget.push-type.widgets` |
| `apns-push-type` | `widgets` |
| Payload | `{"aps":{"content-changed":true}}` |

- [ ] Log the APNs HTTP status, `apns-id`, and error `reason`, but redact the
      authorization JWT and device token.
- [ ] Test a single known internal device first. Do not broadcast while proving
      configuration.
- [ ] Expect push delivery to be opportunistic. Validate success by both the APNs
      response and the widget's subsequent resolver request/timeline change; a
      successful APNs response alone does not prove visible refresh.
- [ ] If APNs returns `BadDeviceToken`, check environment, token freshness, and
      topic before rotating credentials. If it returns `DeviceTokenNotForTopic`,
      check the extension topic and key scope. If it returns `InvalidProviderToken`
      or `ExpiredProviderToken`, check Key ID, Team ID, server clock, JWT signature,
      and JWT age.

## Ready-to-test gate

Do not build the sender until every item below is true:

- [ ] The TestFlight archive's **signed widget extension** has
      `aps-environment = production`.
- [ ] The server has a current widget token labeled `production` from the exact
      TestFlight installation being tested.
- [ ] The APNs credential remains server-side and its Key ID, Team ID, and topic
      scope are known.
- [ ] The sender will use the production host, the widget topic, push type
      `widgets`, and the widget payload shown above.
- [ ] Logs and test output redact secrets and full device tokens.
