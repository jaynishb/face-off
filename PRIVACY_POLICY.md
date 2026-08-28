# Face Off — Privacy Policy

*Last updated: [DATE — fill in before publishing]*

## Summary

Face Off is an offline, local-only game. We do not collect, store, or transmit
any personal information from you or your device. There are no accounts, no
logins, and no cloud save. The only network activity in the app comes from
the advertising SDK described below.

## What we don't collect

Face Off does not collect, and has no mechanism to collect:

- Names, email addresses, or any account information (there are no accounts)
- Location data
- Contacts, photos, or any other device content
- Gameplay data sent to any server (match results and head-to-head scores
  are stored only on your device, and your session tally is cleared when
  you close the app)
- Analytics of any kind

## Advertising

Face Off shows interstitial ads between matches via [AdMob / Google Mobile
Ads SDK — TODO: confirm final ad network before submission]. The ad SDK may
collect data as described in its own privacy policy, which governs that
processing: https://policies.google.com/privacy

Ad behavior in this app is deliberately conservative:
- No ads are shown for a user's first 3 matches.
- No ads appear during a match, on launch, or on a rules card — only
  between match-end and the results screen.
- At most one interstitial per 3 completed matches, and never within 90
  seconds of the previous one.

If you purchase the "Remove Ads" upgrade, no further ad requests are made by
the app.

## In-app purchases

Face Off offers a single one-time, non-consumable purchase ("Remove Ads"),
processed by the Google Play Store or Apple App Store. We do not receive or
store your payment details — that is handled entirely by the platform.

## Children's privacy

Face Off is designed to be safe for a general audience, including children,
and contains no user-generated content, chat, or social features. Ad
configuration is set conservatively for this reason (see PRD §8.4). If this
app is listed under Google Play's Families program or otherwise targeted at
children, this policy and the ad SDK configuration must be reviewed for
COPPA / GDPR-K compliance before submission — this has not yet been done and
is called out as an open decision in `FACE_OFF_PRD.md` §14.

## Changes to this policy

If this policy changes, the updated version will be posted at this same
location with a revised "Last updated" date.

## Contact

[TODO: add a contact email before publishing/submitting to app stores.]

---

**Note for whoever ships this:** this document must be hosted at a public,
stable URL before store submission (Google Play and Apple both require a
privacy policy URL), and that URL needs to replace the placeholder in
`shell/settings/Settings.gd` (`PRIVACY_POLICY_URL`). Fill in the `[TODO]`
markers above first.
