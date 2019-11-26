#!/bin/bash
set -e
set -o pipefail

sudo -u elife -H helm ls elife-xpub-- --output json | jq -r '.Releases[].Name'
