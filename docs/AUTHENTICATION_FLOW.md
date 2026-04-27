# iOS Authentication Flow

> How the Fotolokashen iOS app authenticates via OAuth 2.0 PKCE, handles email verification, and manages deep links.
>
> **Full cross-platform docs**: See `fotolokashen/docs/guides/authentication-flow.md` in the web repo.

---

## Login Flow

```
LoginView → AuthService.startLogin()
  → ASWebAuthenticationSession opens fotolokashen.com/login
    (ephemeral session — no Safari cookies shared)
  → User logs in on web
  → OAuth redirect: fotolokashen://oauth-callback?code=xxx
  → AuthService.handleCallback()
  → POST /api/auth/oauth/token (code exchange, redirect_uri: fotolokashen://oauth-callback)
  → access_token + refresh_token saved to Keychain
  → isAuthenticated = true
```

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
