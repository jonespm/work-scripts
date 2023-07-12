#!/bin/bash
# Script to apply letencrypt certificates to a single projects in Openshift or all projects you have access to

# Global variable for the issuer name, use the staging one for testing
#ISSUER_NAME="letsencrypt-staging"
ISSUER_NAME="letsencrypt"

# Function to create a certificate for a route
create_route_certificate() {
  local project=$1
  local name=$2
  local host=$3

  # Create certificate object with the DNS name
  cert_name="${name}-cert"
  cat <<EOF | oc apply -n "$project" -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: $cert_name
spec:
  dnsNames:
    - $host
  secretName: $cert_name
  issuerRef:
    name: $ISSUER_NAME
    kind: ClusterIssuer
EOF

  # Remove existing caCertificate from the route
  oc patch route "$name" -n "$project" --type json -p '[{"op": "remove", "path": "/spec/tls/caCertificate"}]'

  # Update the route annotation to use the certificate
  oc annotate route "$name" -n "$project" cert-utils-operator.redhat-cop.io/certs-from-secret="$cert_name"
}

# Check if a project argument is provided
if [[ -n $1 ]]; then
  # Run the script for a single named project
  project=$1

  # Check if the provided project exists
  if oc get project "$project" &>/dev/null; then
    # Get routes in the specified project and extract name and host
    routes=$(oc get routes -n "$project" -o custom-columns=NAME:.metadata.name,HOST:.spec.host --no-headers)

    # Iterate through each route in the project
    while read -r route; do
      name=$(echo "$route" | awk '{print $1}')  # Extract route name
      host=$(echo "$route" | awk '{print $2}')  # Extract route host

      create_route_certificate "$project" "$name" "$host"
    done <<< "$routes"
  else
    echo "Project $project not found."
    exit 1
  fi
else
  echo "Missing project argument. Please provide the project name."
  exit 1
fi
