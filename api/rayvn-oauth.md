---
layout: default
title: "rayvn/oauth"
parent: API Reference
nav_order: 5
---

# rayvn/oauth

## Functions

### getOAuthService

**Library:** `rayvn/oauth`

My library.
Intended for use via: require 'rayvn/oauth'
Build and populate an OAuth service map for a given provider and scope.
Credentials are resolved from: caller args → environment variables → system keychain → interactive prompt.
Args: providerName resultMapVar serviceScope [clientId] [clientSecret]
  providerName  - OAuth provider name, lowercase (e.g. 'google')
  resultMapVar  - name of an associative array to populate with the service configuration
  serviceScope  - OAuth scope string (e.g. 'https://www.googleapis.com/auth/gmail.readonly')
  clientId      - optional OAuth client ID; if omitted, resolved from env/keychain/prompt
  clientSecret  - optional OAuth client secret; if omitted, resolved from env/keychain/prompt

```bash
getOAuthService() {
```

### setupOAuthService

**Library:** `rayvn/oauth`

Perform the full OAuth authorization code flow: open browser, capture callback, exchange for tokens.
Stores the resulting tokens in the system keychain.
Args: serviceVar
  serviceVar - name of an OAuth service map populated by `getOAuthService()`

```bash
setupOAuthService() {
```

### getOAuthAccessToken

**Library:** `rayvn/oauth`

Return a valid access token for the service, refreshing it automatically if expired.
Args: serviceVar
  serviceVar - name of an OAuth service map populated by `getOAuthService()`

```bash
getOAuthAccessToken() {
```

