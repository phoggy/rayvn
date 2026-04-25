---
layout: default
title: "rayvn/secrets"
parent: API Reference
nav_order: 6
---

# rayvn/secrets

System keychain credential storage.

## Functions

### secretStore()

Store a secret in the system keychain (macOS Keychain or Linux secret-tool).


*Args*

| | |
|---|---|
| `service` *(string)* | Service name identifying the credential group. |
| `account` *(string)* | Account name (key) within the service. |
| `secret` *(string)* | Secret value to store. |
{: .args-table}

### secretRetrieve()

Retrieve a secret from the system keychain for the given service and account.


*Args*

| | |
|---|---|
| `service` *(string)* | Service name identifying the credential group. |
| `account` *(string)* | The account name (key) within the service. |
{: .args-table}

### secretDelete()

Delete a secret from the system keychain.


*Args*

| | |
|---|---|
| `service` *(string)* | Service name identifying the credential group. |
| `account` *(string)* | Account name (key) within the service. |
{: .args-table}

### secretExists()

Return 0 if a secret exists in the system keychain for the given service and account.


*Args*

| | |
|---|---|
| `service` *(string)* | Service name used to identify the credential group. |
| `account` *(string)* | Account name (key) within the service. |
{: .args-table}

