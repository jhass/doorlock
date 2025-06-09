#!/bin/sh
# docker-entrypoint.sh: Inject POCKETBASE_URL into Flutter web app at runtime

set -e

: "${POCKETBASE_URL:?POCKETBASE_URL environment variable must be set}"

# Write env.js with the runtime value
cat <<EOF > /usr/share/nginx/html/env.js
window.env = {
  POCKETBASE_URL: "${POCKETBASE_URL}"
};
EOF

exec "$@"
