#!/bin/bash
set -e
set -o pipefail

helm ls elife-xpub-- --output json | jq -r '.Releases[].Name'
