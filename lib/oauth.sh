#!/usr/bin/env bash

# My library.
# Intended for use via: require 'rayvn/oauth'

getOAuthService() {
    local providerName="${1,,}" # e.g. 'google'
    local resultMapVarName="${2}"

    # First, make sure we know about this provider

    local authUrlVarName="_${providerName}AuthUrl"
    local tokenUrlVarName="_${providerName}TokenUrl"
    if ! varIsDefined authUrlVarName || ! varIsDefined tokenUrlVarName; then
        fail "OAuth service '${providerName}' not supported"
    fi

    # Collect the variables we need

    local -n clientIdEnvVar="${providerName^^}_CLIENT_ID"
    local -n clientSecretEnvVar="${providerName^^}_CLIENT_SECRET"
    local clientId="${clientIdEnvVar:-}"
    local clientSecret="${clientSecretEnvVar:-}"

    # Check keychain if not in environment
    if [[ -z "${clientId}" ]]; then
        clientId=${ secretRetrieve "oauth_${providerName}" "client_id"; }
    fi
    if [[ -z "${clientSecret}" ]]; then
        clientSecret=${ secretRetrieve "oauth_${providerName}" "client_secret"; }
    fi

    _ensureClientIdAndSecret "${providerName}" clientId clientSecret
    local -n authUrl=${authUrlVarName}
    local -n tokenUrl=${tokenUrlVarName}
    local tokenFile="${_tokensDir}/${providerName}-token.json"

    # Build the service map

    local -A _oAuthServiceMap=() # named to avoid collisions with caller vars
    _oAuthServiceMap+=([${_oAuthProviderKey}]="${providerName}")
    _oAuthServiceMap+=([${_oAuthIdKey}]="${clientId}")
    _oAuthServiceMap+=([${_oAuthSecretKey}]="${clientSecret}")
    _oAuthServiceMap+=([${_oAuthUrlKey}]="${authUrl}")
    _oAuthServiceMap+=([${_oAuthTokenKey}]="${tokenUrl}")
    _oAuthServiceMap+=([${_oAuthTokenFileKey}]="${tokenFile}")

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

    # Prep our config dir

    local configDir
    configDir="${ configDirPath '.tokens'; }"
    ensureDir "${configDir}"
    declare -grx _tokensDir="${configDir}"

    # Define our service keys so we can validate

    declare -grx _oAuthProviderKey='providerName'
    declare -grx _oAuthIdKey='clientId'
    declare -grx _oAuthSecretKey='clientSecret'
    declare -grx _oAuthUrlKey='authUrl'
    declare -grx _oAuthTokenKey='tokenUrl'
    declare -grx _oAuthTokenFileKey='tokenFile'

    declare -garx _oAuthServiceKeys=("${_oAuthProviderKey}" "${_oAuthIdKey}" "${_oAuthSecretKey}" \
                                     "${_oAuthUrlKey}" "${_oAuthTokenKey}" "${_oAuthTokenFileKey}" )

    # Google provider constants

    declare -grx _googleAuthUrl="https://accounts.google.com/o/oauth2/v2/auth"
    declare -grx _googleTokenUrl="https://oauth2.googleapis.com/token"

    # Add other provider urls here
}

_ensureClientIdAndSecret() {
    local providerName="${1}"
    local -n clientIdRef="${2}"
    local -n clientSecretRef="${3}"

    if [[ -z "${clientIdRef}" ]]; then
        request "Enter your ${providerName^} API OAuth client ID" clientIdRef true || bye 'client ID is required'
        secretStore "oauth_${providerName}" "client_id" "${clientIdRef}"
    fi
    if [[ -z "${clientSecretRef}" ]]; then
        requestHidden "Enter your ${providerName^} API OAuth client secret" clientSecretRef true || bye 'client secret is required'
        secretStore "oauth_${providerName}" "client_secret" "${clientSecretRef}"
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

# Capture OAuth authorization code via local HTTP server
_captureOAuthCode() {
    local authCode=""

    # Create a named pipe for communication
    local pipePath
    pipePath=${ tempDirPath "oauth_pipe"; }
    mkfifo "${pipePath}" || fail "could not create named pipe ${pipePath}"

    # Start a simple HTTP server using netcat or bash
    {
        # Try to use nc (netcat) first for better compatibility
        if command -v nc > /dev/null 2>&1; then
            while true; do
                # Read HTTP request   TODO: uh, what? How is this 'reading' an http request?
                local request
                request=${ echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<html><body><h1>Authorization Successful</h1><p>You can close this window and return to the terminal.</p></body></html>" | nc -l "${redirectPort}" 2> /dev/null; }

                # Extract code from request
                if [[ "${request}" =~ code=([^&[:space:]]+) ]]; then
                    authCode="${BASH_REMATCH[1]}"
                    echo "${authCode}" > "${pipePath}"
                    break
                fi
            done
        else
            # Fallback: use bash with /dev/tcp (requires bash with network support)
            fail "netcat (nc) is required but not found. Please install netcat."
        fi
    } &

    local serverPid=$!

    # Read the auth code from the pipe (blocks until server writes it)
    authCode=${ cat "${pipePath}"; }

    # Clean up
    rm -f "${pipePath}"
    kill "${serverPid}" 2> /dev/null || true

    echo "${authCode}"
}

# Perform OAuth setup
_setupOAuthService() {
    local serviceVarName="${1}"
    local -n serviceRef="${serviceVarName}"
    local scope="${2}"
    local authUrl="${serviceRef[${_oAuthUrlKey}]}"
    local tokenUrl="${serviceRef[${_oAuthTokenKey}]}"
    local clientId="${serviceRef[${_oAuthIdKey}]}"
    local clientSecret="${serviceRef[${_oAuthSecretKey}]}"
    local tokenFile="${serviceRef[${_oAuthTokenFileKey}]}"

    local redirectPort
    redirectPort=${ _findFreePort; }
    local redirectUri="http://localhost:${redirectPort}"

    # Generate authorization URL
    local authUrlWithParams="${authUrl}?client_id=${clientId}&redirect_uri=${redirectUri}&response_type=code&scope=${scope}&access_type=offline"

    show "Starting local OAuth callback server on port" bold "${redirectPort}"
    show "Opening browser for authorization..."
    open "${authUrlWithParams}"

    # Capture the authorization code from the callback
    local authCode
    show "Waiting for authorization callback..."
    authCode=${ _captureOAuthCode "${redirectPort}"; }

    if [[ -z "${authCode}" ]]; then
        fail "Failed to capture authorization code"
    fi

    show success "Authorization code received"

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

    # Save tokens with expiration timestamp
    echo "${tokenResponse}" | jq --arg exp "${expirationTimestamp}" '. + {expiration_timestamp: ($exp | tonumber)}' > "${tokenFile}"
    chmod 600 "${tokenFile}"

    show success "Setup complete! Tokens saved to ${tokenFile}"
}

# Get valid access token (refresh if needed)
_getOAuthAccessToken() {
    local serviceVarName="${1}"
    local -n serviceRef="${serviceVarName}"
    local providerName="${serviceRef[${_oAuthProviderKey}]}"
    local clientId="${serviceRef[${_oAuthIdKey}]}"
    local clientSecret="${serviceRef[${_oAuthSecretKey}]}"
    local tokenFile="${serviceRef[${_oAuthTokenFileKey}]}"
    local accessToken
    local refreshToken
    local expirationTimestamp

    accessToken=${ jq -r '.access_token // empty' "${tokenFile}"; }
    refreshToken=${ jq -r '.refresh_token // empty' "${tokenFile}"; }
    expirationTimestamp=${ jq -r '.expiration_timestamp // 0' "${tokenFile}"; }

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

            # Update token file with new access token and expiration
            jq --arg at "${newAccessToken}" --arg exp "${newExpirationTimestamp}" \
               '.access_token = $at | .expiration_timestamp = ($exp | tonumber)' \
               "${tokenFile}" > "${tokenFile}.tmp"
            mv "${tokenFile}.tmp" "${tokenFile}"
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
