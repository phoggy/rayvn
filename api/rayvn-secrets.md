---
layout: default
title: "rayvn/secrets"
parent: API Reference
nav_order: 1
---

# rayvn/secrets

## Functions

### secretStore

**Library:** `rayvn/secrets`

Secure credential storage library using system keychains.
Intended for use via: require 'rayvn/secrets'
Store a secret in the system keychain (macOS Keychain or Linux secret-tool).
Args: service account secret
  service - service name used to identify the credential group
  account - account name (key) within the service
  secret  - secret value to store

```bash
secretStore() {
```

### secretRetrieve

**Library:** `rayvn/secrets`

Retrieve a secret from the system keychain. Prints the value, or empty string if not found.
Args: service account
  service - service name used to identify the credential group
  account - account name (key) within the service

```bash
secretRetrieve() {
```

### secretDelete

**Library:** `rayvn/secrets`

Delete a secret from the system keychain.
Args: service account
  service - service name used to identify the credential group
  account - account name (key) within the service

```bash
secretDelete() {
```

### secretExists

**Library:** `rayvn/secrets`

Return 0 if a secret exists in the system keychain, 1 if not.
Args: service account
  service - service name used to identify the credential group
  account - account name (key) within the service

```bash
secretExists() {
```

