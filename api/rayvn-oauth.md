---
layout: default
title: "rayvn/oauth"
parent: API Reference
nav_order: 7
---

# rayvn/oauth

OAuth authorization code flow.

## Functions

### getOAuthService()

Build and populate an OAuth service map for the given provider.
Credentials resolve in order: caller args → env vars → keychain → interactive prompt.


*Args*

| | |
|---|---|
| `providerName` *(string)* | Name of the OAuth provider (e.g. 'google'). |
| `resultMapRef` | (mapRef)  Associative array to populate with service config. |
| `serviceScope` *(string)* | OAuth scope string. |
| `clientId` *(string)* | Optional client ID; if empty, resolved automatically. |
| `clientSecret` *(string)* | Optional client secret; if empty, resolved automatically. |
{: .args-table}

### setupOAuthService()

Run the full OAuth authorization code flow and store tokens in the keychain.


*Args*

| | |
|---|---|
| `serviceVarName` | (mapRef)  Name of an OAuth service map populated by getOAuthService. |
{: .args-table}

### getOAuthAccessToken()

Outputs a valid access token for the service, refreshing it automatically if expired.


*Args*

| | |
|---|---|
| `serviceVarName` | (mapRef)  Name of an OAuth service map populated by getOAuthService. |
{: .args-table}

