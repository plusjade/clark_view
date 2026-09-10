# Push notification setup

## Current state

The app requests alert/sound permission, registers its APNs token, shows foreground
banners, and can open notification settings. The paired screen can copy the app token
for a manual Apple console test or trigger a fixed self-test through Val Town. Tokens
are not logged or persisted locally.

The widget extension independently uploads its WidgetKit token to `POST /device/token`.
Sandbox alert and widget delivery are verified end to end. **Production authentication
and delivery remain unverified** — validate on a TestFlight/signed build before relying
on it for real users.

## Event reminders

Automatic reminders are live. `sports-today` queues one notification per upcoming
event per device and sends a visible alert a configurable time beforehand, default
one hour. It uses the alert channel only; a reminder does not refresh the widget.

Delivery is gated by the parent's `REMINDERS_ENABLED` variable. While it is unset the
jobs still run and the queue still drains, recording what each row would have sent
without contacting APNs. See the parent's `docs/event-reminders.md` for the queue
model, the sizing rule and the configuration.
