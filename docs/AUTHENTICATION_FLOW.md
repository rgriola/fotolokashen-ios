# iOS Authentication Flow

Updated October 29, 2026, 19:43 EDT.

> How the Fotolokashen iOS app authenticates via OAuth 2.0 PKCE, handles email verification, and manages deep links.
>
> **Full cross-platform docs**: See `fotolokashen/docs/guides/authentication-flow.md` in the web repo.

---

## Login Flow

```
LoginView → AuthService.startLogin()
  → ASWebAuthenticationSession opens fotolokashen.com/login
    (fresh random state + PKCE challenge; ephemeral session — no Safari cookies shared)
  → User logs in on web
  → OAuth redirect: fotolokashen://oauth-callback?code=xxx&state=yyy
  → AuthService.handleCallback()
  → Require exactly one nonempty state matching this login; reject before token exchange otherwise
  → POST /api/auth/oauth/token (code exchange, redirect_uri: fotolokashen://oauth-callback)
  → access_token + refresh_token saved to Keychain
  → isAuthenticated = true
```

Missing, empty, duplicate, mismatched or unexpected state ends the login attempt
with a sign-in verification error and clears PKCE/state. A successfully exchanged
code delivered again is still ignored, preserving the browser/deep-link duplicate
callback behavior.

**Rollout verification (October 29, 2026):** The user reports successful 1.6.2
login against preview and production. That older client does not send state;
web passthrough must remain optional for it. The new iOS build enforces state
locally. All 15 OAuth callback regression tests pass on iPhone 17 / iOS 27.0.
Physical production login with the stricter new build remains pending.

**Production retry (18:51 EDT):** The Xcode-installed strict build, still labeled
1.6.2 (62), rejected a production callback with the sign-in verification error.
Local web source was found to omit state forwarding in LoginForm and both
auth-callback redirects; that path is now corrected locally. Production's deployed
commit is unverified. Deploy the web correction, then repeat strict-build login,
logout, and login. The displayed version alone does not identify the older
App Store client.

**Preview verification (19:05 EDT):** Public JavaScript served by
`https://merkelvision.com/login` still omits state capture/forwarding, and
`/app/auth-callback` still constructs code-only custom-scheme redirects in both
paths. This was checked using synthetic callback values, without signing in.
The web fix is committed locally as `21ab0db`, but that domain is not serving
the corrected flow. Verify the Vercel deployment commit and domain assignment,
then repeat the login check; strict validation remains enabled.

**Redeploy follow-up (19:11 EDT):** After the reported fresh deployment,
`merkelvision.com` still served the same code-only callback and login chunks
(`07lm6hpruy36f.js` and `3ygtqx_67_a6y.js`). The user identified source commit
`21ab0db` and branch alias `fotolokashen-git-main-rodczaro.vercel.app`; direct
inspection of that alias redirects to Vercel authentication, so its deployed
application code could not be independently compared. Check the custom domain's
assigned deployment in Vercel; do not bypass deployment protection.

**Domain assignment confirmed by user (19:21 EDT):** `merkelvision.com` was
pointing to production, not preview. The recent attempts therefore did not test
the corrected preview deployment. Assign the test domain to the intended preview
deployment, then verify strict-build login, logout, and login again. Earlier
checks described as preview checks through this domain do not establish preview
compatibility; retest the older App Store client against the corrected preview
as well. No successful strict-build preview login has been confirmed yet.

**Login restored, user-confirmed (19:43 EDT):** Login now works with the new iOS
build after correcting domain/protection configuration. This supersedes the
preview-login blocker above. Logout/relogin, older App Store client compatibility
against the corrected preview, and strict-build production verification have not
yet been explicitly confirmed.

> **Note (fixed 2026-04-26):** `prefersEphemeralWebBrowserSession` is set to `true` so each OAuth
> session starts with a clean cookie jar. Previously `false` caused stale Safari web-session cookies
> to bleed into the in-app browser, producing a reload/redirect loop on sign-in.

---

## Registration Flow (New Account)

```
LoginView → AuthService.startRegistration()
  → ASWebAuthenticationSession opens fotolokashen.com/register
  → User fills form → backend detects iOS via User-Agent
  → "Check Your Email" card shown in panel
  → User closes panel → opens email → taps verify link

  Email link: /verify-email?token=xxx&platform=ios

  →  verify-email page calls GET /api/auth/verify-email
  → Token verified → one-time autoLoginToken generated
  → autoLoginToken stored as SHA-256 hash in DB
  → Page redirects: fotolokashen://email-verified?token=xxx

  → DeepLinkManager.handleURL() receives deep link
  → AuthService.handleAutoLogin(token)
  → POST /api/auth/auto-login { token, client_id, device_name }
  → Server hashes token → finds user → returns access_token
  → Tokens saved to Keychain → isAuthenticated = true
  → Safari panel dismissed
```

---

## ⚠️ Known UX Gap — "Email Already Exists"

**Current behavior (broken):**

When a user opens the Create Account panel but already has an account:
1. `POST /api/auth/register` returns `409 EMAIL_EXISTS`
2. The web form shows an inline error message (toast not visible in Safari panel)
3. **The panel stays open — the user has no way to navigate to login from within the panel**

**Expected behavior:**

The panel should close and the app should prompt the user to log in instead.

**Required fix (not yet implemented):**

| Where | Change |
|---|---|
| `RegisterForm.tsx` | Detect `EMAIL_EXISTS` + iOS context → show brief message → redirect: `fotolokashen://register-redirect?action=login&reason=account_exists` |
| `AuthService.startRegistration()` | Append `&source=ios` to registration URL |
| `DeepLinkManager.swift` | Handle `register-redirect` → dismiss panel → alert user → call `startLogin()` |

See `fotolokashen/docs/guides/authentication-flow.md` for full implementation spec.

---

## Deep Links

| URL | Handler | Purpose |
|-----|---------|---------| 
| `fotolokashen://oauth-callback?code=xxx` | `AuthService.handleCallback()` | OAuth code exchange after login |
| `fotolokashen://email-verified?token=xxx` | `DeepLinkManager` → auto-login | Post-verification auto-login |
| `fotolokashen://register-redirect?action=login&reason=account_exists` | `DeepLinkManager` | ⚠️ **Not yet implemented** — "email exists" redirect |
| `fotolokashen://location/{id}` | `DeepLinkManager.navigateToLocation()` | Open a specific location |

---

## Token Security

All auth tokens (verification, reset, auto-login) are stored as **SHA-256 hashes** in the database. The raw token is sent to the user and hashed server-side on verification.

The `autoLoginToken` is:
- Generated as `crypto.randomBytes(32).toString('base64url')` on the web server
- Sent raw as a URL param in the `fotolokashen://email-verified?token=xxx` deep link
- Stored in DB as `SHA-256(rawToken)`
- On `POST /api/auth/auto-login`, the server hashes the incoming token before lookup

The token is **single-use** (cleared immediately on first use) and expires after **5 minutes**.

---

## How Platform Detection Works

`AuthService.startRegistration()` appends `?source=ios` to the registration URL. The `RegisterForm`
web component reads this query param and, on successful registration, redirects to
`fotolokashen://await-verification` to close the panel and show the native "check your email" UI.

The web backend also detects iOS via the `User-Agent` header and appends `&platform=ios` to the
verification email link, so the `verify-email` page triggers `fotolokashen://email-verified`
instead of the standard web login redirect.

---

## Key Files

| File | Role |
|------|------|
| `AuthService.swift` | OAuth PKCE flow, `startLogin()`, `startRegistration()`, `handleAutoLogin()` |
| `DeepLinkManager.swift` | URL routing, `emailVerified` flag, deep link dispatching |
| `ContentView.swift` / `LoginView` | Observes `emailVerified`, auto-triggers login |
| `Info.plist` | Registers `fotolokashen` custom URL scheme |
| `ConfigLoader.swift` | Backend URL, OAuth client ID, redirect URI |
