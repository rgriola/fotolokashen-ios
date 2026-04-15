# iOS Authentication Flow

> How the fotolokashen iOS app authenticates via OAuth 2.0 PKCE and handles email verification deep links.
>
> **Full cross-platform docs**: See `fotolokashen/docs/guides/authentication-flow.md` in the web repo.

---

## Login Flow

```
LoginView → AuthService.startLogin()
  → ASWebAuthenticationSession opens fotolokashen.com/login
  → User logs in on web → OAuth redirect to fotolokashen://oauth-callback?code=xxx
  → AuthService.handleCallback() → exchangeCodeForTokens()
  → Tokens saved to Keychain → isAuthenticated = true
```

## Registration Flow (with Email Verification)

```
LoginView → AuthService.startRegistration()
  → ASWebAuthenticationSession opens fotolokashen.com/register
  → User fills form → "Check Your Email" card shown
  → User dismisses browser → opens email → taps verify link
  → Safari: /verify-email?token=xxx&platform=ios
  → Email verified → auto-redirect to fotolokashen://email-verified
  → DeepLinkManager sets emailVerified = true
  → LoginView observes flag → auto-calls startLogin()
  → User logs in with new credentials
```

## Deep Links

| URL | Handler | Purpose |
|-----|---------|---------|
| `fotolokashen://oauth-callback?code=xxx` | `AuthService.handleCallback()` | OAuth code exchange |
| `fotolokashen://email-verified` | `DeepLinkManager` → `LoginView` | Post-verification app return |
| `fotolokashen://location/{id}` | `DeepLinkManager.navigateToLocation()` | Open a location |

## Key Files

| File | Role |
|------|------|
| `AuthService.swift` | OAuth PKCE flow, login/register, token management |
| `DeepLinkManager.swift` | URL routing, `emailVerified` flag |
| `ContentView.swift` → `LoginView` | Observes `emailVerified`, auto-triggers login |
| `Info.plist` | `fotolokashen` URL scheme registration |
| `ConfigLoader.swift` | Backend URL, OAuth client ID, redirect URI |

## How Platform Detection Works

The web backend detects iOS via the `User-Agent` header during registration and appends `&platform=ios` to the verification email link. This lets the verify-email web page redirect to `fotolokashen://email-verified` instead of showing the web login page.

The detection runs server-side in `POST /api/auth/register` — no iOS code changes needed for this part.
