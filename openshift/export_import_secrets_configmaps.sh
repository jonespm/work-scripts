#!/bin/bash

export_secrets_configmaps() {
  local project_name=$1
  local exports_dir=$2

  # Create the exports directory if it doesn't exist
  mkdir -p "$exports_dir"

  # Export secrets with type "Opaque" as JSON
  for secret in $(oc get secrets --field-selector type=Opaque -o name -n $project_name); do
    local secret_name=${secret//\//-}
    oc get -n $project_name $secret -o json > "${exports_dir}/${secret_name}.json"
    echo "Exported secret: $secret_name"
  done

  # Export config maps as JSON
  for configmap in $(oc get configmaps -o name -n $project_name); do
    local configmap_name=${configmap//\//-}
    oc get -n $project_name $configmap -o json > "${exports_dir}/${configmap_name}.json"
    echo "Exported config map: $configmap_name"
  done

  echo "Export complete. Secrets and config maps are exported to: ${exports_dir}"
}

import_secrets_configmaps() {
  local project_name=$1
  local imports_dir=$2

  # Import secrets and config maps from JSON files
  for file in "${imports_dir}"/*.json; do
    if [[ $file == *"secret-"* ]]; then
      oc apply -n $project_name -f "$file"
    elif [[ $file == *"configmap"* ]]; then
      oc apply -n $project_name -f "$file"
    fi
  done

  echo "Import complete. Secrets and config maps are imported to the project: ${project_name}"
}

main() {
  # Check if the correct number of arguments is provided
  if [ $# -ne 3 ]; then
    echo "Error: Invalid number of arguments."
    echo "Usage: ./export_import_secrets_configmaps.sh <import/export> <project-name> <directory-name>"
    exit 1
  fi

  local operation=$1
  local project_name=$2
  local directory_name=$3

  case $operation in
    "export")
      export_secrets_configmaps "$project_name" "$directory_name"
      ;;
    "import")
      import_secrets_configmaps "$project_name" "$directory_name"
      ;;
    *)
      echo "Error: Invalid operation. Supported operations are 'import' and 'export'."
      echo "Usage: ./export_import_secrets_configmaps.sh <import/export> <project-name> <directory-name>"
      exit 1
      ;;
  esac
}

# Execute the main function with provided arguments
main "$@"

