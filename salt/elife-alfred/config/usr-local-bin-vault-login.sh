#!/bin/bash
set -e

# needs the following environment variables:
#VAULT_ADDR
#VAULT_ROLE_ID
#VAULT_SECRET_ID
source /etc/profile

vault write -field=token auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID" > ~/.vault-token
