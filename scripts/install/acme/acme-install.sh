#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# ACME.sh Install
# The latest acme.sh, from get.acme.sh, which downloads acme.sh itself from GitHub. Either download
# can fail, so the install is tried up to three times.
ACME_INSTALLER="/tmp/enginescript-get-acme.sh"
for attempt in 1 2 3; do
    if curl -fsSL --proto '=https' --retry 3 -o "${ACME_INSTALLER}" https://get.acme.sh \
        && sh "${ACME_INSTALLER}" \
        && [[ -x /root/.acme.sh/acme.sh ]]; then
        break
    fi
    echo "Warning: acme.sh install attempt ${attempt} of 3 failed." >&2
    [[ "${attempt}" -lt 3 ]] && sleep 10
done
rm -f "${ACME_INSTALLER}"
if [[ ! -x /root/.acme.sh/acme.sh ]]; then
    echo "Error: Failed to install acme.sh. Run es.install again to retry." >&2
    exit 1
fi

# Cloudflare Keys
export CF_Key="${CF_GLOBAL_API_KEY}"
export CF_Email="${CF_ACCOUNT_EMAIL}"

# Register ZeroSSL
# Use the user's Cloudflare email address so they have fewer fields to fill out in the options file.
/root/.acme.sh/acme.sh --register-account -m "${CF_ACCOUNT_EMAIL}"

/root/.acme.sh/acme.sh --upgrade --auto-upgrade

echo "ACME.sh completed successfully. Script done."
