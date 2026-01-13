#!/usr/bin/env bash

# My library.
# Intended for use via: require 'rayvn/oauth'

getOAuthService() {
    local providerName="${1,,}" # e.g. 'google'
    local resultMapVarName="${2}"
    local serviceScope="${3}"
    local clientId="${4:-}" # optional: client ID from caller
    local clientSecret="${5:-}" # optional: client secret from caller

    # First, make sure we know about this provider

    local authUrlVarName="_${providerName}AuthUrl"
    local tokenUrlVarName="_${providerName}TokenUrl"
    if ! varIsDefined authUrlVarName || ! varIsDefined tokenUrlVarName; then
        fail "OAuth service '${providerName}' not supported"
    fi

    # If not provided by caller, try environment variables
    if [[ -z "${clientId}" ]]; then
        local -n clientIdEnvVar="${providerName^^}_CLIENT_ID"
        clientId="${clientIdEnvVar:-}"
    fi
    if [[ -z "${clientSecret}" ]]; then
        local -n clientSecretEnvVar="${providerName^^}_CLIENT_SECRET"
        clientSecret="${clientSecretEnvVar:-}"
    fi

    # Ensure we have credentials (checks provided → env → keychain → prompt)
    _ensureClientIdAndSecret "${providerName}" clientId clientSecret
    local -n authUrl=${authUrlVarName}
    local -n tokenUrl=${tokenUrlVarName}

    # Build the service map

    local -A _oAuthServiceMap=() # named to avoid collisions with caller vars
    _oAuthServiceMap+=([${_oAuthProviderKey}]="${providerName}")
    _oAuthServiceMap+=([${_oAuthScopeKey}]="${serviceScope}")
    _oAuthServiceMap+=([${_oAuthIdKey}]="${clientId}")
    _oAuthServiceMap+=([${_oAuthSecretKey}]="${clientSecret}")
    _oAuthServiceMap+=([${_oAuthUrlKey}]="${authUrl}")
    _oAuthServiceMap+=([${_oAuthTokenKey}]="${tokenUrl}")

    # Copy to the callers map variable

    copyMap _oAuthServiceMap "${resultMapVarName}"
}

setupOAuthService() {
    local serviceVarName="${1}"
    _assertValidOAuthService "${serviceVarName}"
    _setupOAuthService "${serviceVarName}"
}

getOAuthAccessToken() {
    local serviceVarName="${1}"
    _assertValidOAuthService "${serviceVarName}"
    _getOAuthAccessToken "${serviceVarName}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/oauth' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_oauth() {
    require 'rayvn/core' 'rayvn/prompt' 'rayvn/secrets'

    # Define our service keys so we can validate

    declare -grx _oAuthProviderKey='providerName'
    declare -grx _oAuthScopeKey='scope'
    declare -grx _oAuthIdKey='clientId'
    declare -grx _oAuthSecretKey='clientSecret'
    declare -grx _oAuthUrlKey='authUrl'
    declare -grx _oAuthTokenKey='tokenUrl'

    declare -garx _oAuthServiceKeys=("${_oAuthProviderKey}" "${_oAuthScopeKey}" "${_oAuthIdKey}" "${_oAuthSecretKey}" \
                                     "${_oAuthUrlKey}" "${_oAuthTokenKey}" )

    # Google provider constants

    declare -grx _googleAuthUrl="https://accounts.google.com/o/oauth2/v2/auth"
    declare -grx _googleTokenUrl="https://oauth2.googleapis.com/token"

    # Add other provider urls here
}

_ensureClientIdAndSecret() {
    local providerName="${1}"
    local clientIdVarName="${2}"
    local clientSecretVarName="${3}"
    local -n clientIdRef="${clientIdVarName}"
    local -n clientSecretRef="${clientSecretVarName}"

    local clientIdFromKeychain=0
    local clientSecretFromKeychain=0

    # Try to get client ID from keychain if not already provided
    if [[ -z "${clientIdRef}" ]]; then
        clientIdRef=${ _retrieveSecret 'client_id'; }
        if [[ -n "${clientIdRef}" ]]; then
            clientIdFromKeychain=1
        fi
    fi

    # Try to get client secret from keychain if not already provided
    if [[ -z "${clientSecretRef}" ]]; then
        clientSecretRef=${ _retrieveSecret 'client_secret'; }
        if [[ -n "${clientSecretRef}" ]]; then
            clientSecretFromKeychain=1
        fi
    fi

    # Prompt for client ID if still not available
    if [[ -z "${clientIdRef}" ]]; then
        request "Enter your ${providerName^} API OAuth client ID" clientIdRef true || bye 'client ID is required'
    fi

    # Prompt for client secret if still not available
    if [[ -z "${clientSecretRef}" ]]; then
        requestHidden "Enter your ${providerName^} API OAuth client secret" clientSecretRef true || bye 'client secret is required'
    fi

    # Store credentials in keychain if we did not already
    if ((  ! clientIdFromKeychain )); then
        _storeSecret 'client_id' "${clientIdVarName}"
    fi
    if (( ! clientSecretFromKeychain )); then
        _storeSecret 'client_secret' "${clientSecretVarName}"
    fi
}

_assertValidOAuthService() {
    local serviceVarName="${1}"
    local -n serviceRef="${serviceVarName}"
    local key
    for key in "${_oAuthServiceKeys[@]}"; do
        if [[ ${serviceRef[${key}]} == null ]]; then
            fail "service map ${serviceVarName} is not valid"
        fi
    done
}

_storeSecret() {
    local key="${1}"
    local -n valueRef="${2}"
    secretStore "${ _serviceKey; }" "${key}" "${valueRef}"
}

_retrieveSecret() {
    local key="${1}"
    secretRetrieve "${ _serviceKey; }" "${key}"
}

_deleteSecret() {
    local key="${1}"
    secretDelete "${ _serviceKey; }" "${key}"
}

_serviceKey() {
    [[ -n ${providerName} ]] || fail "providerName var not in scope" > ${terminal}
    echo "oauth_${providerName}"
}

# Capture OAuth authorization code via local HTTP server
_captureOAuthCode() {
    local port="${1}"
    local -n authCodeRef="${2}"

    # Create a named pipe for communication
    local pipePath
    pipePath=${ makeTempFile "oauth_pipe_XXXXXX"; }
    rm -f "${pipePath}"  # Remove the regular file created by makeTempFile
    mkfifo "${pipePath}" || fail "could not create named pipe ${pipePath}"

    # Start a simple HTTP server using netcat or bash
    (
        # Try to use nc (netcat) first for better compatibility
        if command -v nc > /dev/null 2>&1; then
            while true; do
                # Read HTTP request
                local request
                request=${ (echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n\r\n"; _oAuthSuccessHtml) | nc -l "${port}" 2> /dev/null; }

                # Extract code from request
                if [[ "${request}" =~ code=([^&[:space:]]+) ]]; then
                    local authCode="${BASH_REMATCH[1]}"
                    echo "${authCode}" > "${pipePath}"
                    break
                fi
            done
        else
            # Fallback: use bash with /dev/tcp (requires bash with network support)
            fail "netcat (nc) is required but not found. Please install netcat."
        fi
    ) &

    local serverPid=$!

    # Read the auth code from the pipe (blocks until server writes it)
    authCodeRef=${ cat "${pipePath}"; }

    # Clean up
    rm -f "${pipePath}"
    kill "${serverPid}" 2> /dev/null || true
}

# Perform OAuth setup
_setupOAuthService() {

    local serviceVarName="${1}"
    local -n serviceRef="${serviceVarName}"
    local authUrl="${serviceRef[${_oAuthUrlKey}]}"
    local tokenUrl="${serviceRef[${_oAuthTokenKey}]}"
    local clientId="${serviceRef[${_oAuthIdKey}]}"
    local clientSecret="${serviceRef[${_oAuthSecretKey}]}"
    local authScope="${serviceRef[${_oAuthScopeKey}]}"

    # Delete all secrets for this provider

    local providerName="${serviceRef[${_oAuthProviderKey}]}" # Required for secrets
    _deleteSecret 'token'
    _deleteSecret 'client_id'
    _deleteSecret 'client_secret'

    # Generate authorization URL
    local redirectPort
    redirectPort=${ _findFreePort; }
    local redirectUri="http://localhost:${redirectPort}"
    local authUrlWithParams="${authUrl}?client_id=${clientId}&redirect_uri=${redirectUri}&response_type=code&scope=${authScope}&access_type=offline"

    debug "Starting local OAuth callback server on port ${redirectPort}"
    show "Opening browser for authorization..."
    openUrl "${authUrlWithParams}"

    # Capture the authorization code from the callback
    local authCode
    show -n "Waiting for authorization callback"
    _captureOAuthCode "${redirectPort}" authCode

    if [[ -z "${authCode}" ]]; then
        fail "Failed to capture authorization code"
    fi

    echo " ${_greenCheckMark}"

    # Exchange authorization code for tokens
    local tokenResponse
    tokenResponse=${ curl -s -X POST "${tokenUrl}" \
      -d "client_id=${clientId}" \
      -d "client_secret=${clientSecret}" \
      -d "code=${authCode}" \
      -d "redirect_uri=${redirectUri}" \
      -d "grant_type=authorization_code"; }

    # Check for errors in token response
    local error
    error=${ echo "${tokenResponse}" | jq -r '.error // empty'; }
    if [[ -n "${error}" ]]; then
        local errorDescription
        errorDescription=${ echo "${tokenResponse}" | jq -r '.error_description // empty'; }
        fail "OAuth token exchange failed: ${error}" nl "${errorDescription}"
    fi

    # Add expiration timestamp to token response
    local expiresIn
    expiresIn=${ echo "${tokenResponse}" | jq -r '.expires_in // 0'; }
    local expirationTimestamp
    expirationTimestamp=$(( ${ date +%s; } + expiresIn ))

    # Save token with expiration timestamp (compress to single line for keychain storage)
    local token
    token=${ echo "${tokenResponse}" | jq -c --arg exp "${expirationTimestamp}" '. + {expiration_timestamp: ($exp | tonumber)}'; }
    _storeSecret 'token' token

    # Re-store credentials (they were deleted at the start of setup)
    _storeSecret 'client_id' clientId
    _storeSecret 'client_secret' clientSecret

    show success "Setup complete!"
}

# Get valid access token (refresh if needed)
_getOAuthAccessToken() {
    local serviceVarName="${1}"
    local -n serviceRef="${serviceVarName}"
    local providerName="${serviceRef[${_oAuthProviderKey}]}"
    local clientId="${serviceRef[${_oAuthIdKey}]}"
    local clientSecret="${serviceRef[${_oAuthSecretKey}]}"
    local token
    local accessToken
    local refreshToken
    local expirationTimestamp
    token=${ _retrieveSecret token; }
    accessToken=${ echo "${token}" | jq -r '.access_token // empty'; }
    refreshToken=${ echo "${token}" | jq -r '.refresh_token // empty'; }
    expirationTimestamp=${ echo "${token}" | jq -r '.expiration_timestamp // 0'; }

    # Check if token is expired
    local currentTimestamp
    currentTimestamp=${ date +%s; }
    local isExpired=false

    if [[ ${expirationTimestamp} -eq 0 ]] || [[ ${currentTimestamp} -ge ${expirationTimestamp} ]]; then
        isExpired=true
    fi

    # Only refresh if token is expired and we have a refresh token
    if [[ "${isExpired}" == true ]] && [[ -n "${refreshToken}" ]]; then
        _ensureClientIdAndSecret "${providerName}" clientId clientSecret

        local tokenResponse
        tokenResponse=${ curl -s -X POST "${_googleTokenUrl}" \
          -d "client_id=${clientId}" \
          -d "client_secret=${clientSecret}" \
          -d "refresh_token=${refreshToken}" \
          -d "grant_type=refresh_token"; }

        # Update access token but keep refresh token
        local newAccessToken
        newAccessToken=${ echo "${tokenResponse}" | jq -r '.access_token // empty'; }

        if [[ -n "${newAccessToken}" ]]; then
            accessToken="${newAccessToken}"

            # Get new expiration time
            local expiresIn
            expiresIn=${ echo "${tokenResponse}" | jq -r '.expires_in // 0'; }
            local newExpirationTimestamp
            newExpirationTimestamp=$(( ${ date +%s; } + expiresIn ))

            # Update token with new access token and expiration (compress to single line)
            token=${ echo "${token}" | jq -c --arg at "${newAccessToken}" --arg exp "${newExpirationTimestamp}" \
               '.access_token = $at | .expiration_timestamp = ($exp | tonumber)'; }
            _storeSecret 'token' token
        fi
    fi

    echo "${accessToken}"
}

_findFreePort() {
    local port
    local startPort="${1:-8080}"
    local maxPort="${2:-8180}"

    for port in ${ seq ${startPort} ${maxPort}; }; do
        # Try to connect to the port - if connection fails, port is free
        # Using bash's /dev/tcp feature with a timeout
        if ! timeout 0.1 bash -c "echo > /dev/tcp/127.0.0.1/${port}" 2> /dev/null; then
            # Port is free (connection failed)
            echo "${port}"
            return 0
        fi
    done

    # Fallback if no free port found in range
    fail "Could not find a free port in range ${startPort}-${maxPort}"
}

_oAuthSuccessHtml() {
    cat <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Authorization Successful</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 16px;
            padding: 48px 40px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            text-align: center;
            max-width: 440px;
            width: 100%;
        }
        .icon {
            font-size: 64px;
            margin-bottom: 24px;
            animation: scaleIn 0.5s ease-out;
        }
        h1 {
            color: #1a202c;
            font-size: 28px;
            font-weight: 600;
            margin-bottom: 12px;
        }
        p {
            color: #718096;
            font-size: 16px;
            line-height: 1.6;
        }
        @keyframes scaleIn {
            from { transform: scale(0); opacity: 0; }
            to { transform: scale(1); opacity: 1; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">✓</div>
        <h1>Authorization Successful</h1>
        <p>You can close this window and return to the terminal.</p>
    </div>
</body>
</html>
EOF
}
