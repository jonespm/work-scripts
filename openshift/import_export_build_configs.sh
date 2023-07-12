#!/bin/bash

export_build_configs() {
    source_project="$1"
    export_directory="$2"

    oc project "$source_project"

    if [[ ! -d "$export_directory" ]]; then
        mkdir -p "$export_directory"
        echo "Created export directory: $export_directory"
    fi

    oc get bc -o name | while IFS= read -r line; do
        name="${line##*/}"  # Extract the build config name from the full resource name
        oc get "$line" -o yaml > "$export_directory/$name.yaml"
        echo "Exported $name.yaml"
    done

    echo "Build configurations exported to $export_directory directory."
}

import_build_configs() {
    target_project="$1"
    import_directory="$2"

    if ! command -v yq &> /dev/null; then
        echo "Error: yq is not installed. Please install yq to continue. You probably can brew install yq"
        exit 1
    fi

    oc project "$target_project"

    for file in "$import_directory"/*.yaml; do
        # Extract the build configuration name from the file name
        name="${file##*/}"
        name="${name%.yaml}"

        # Check if the build configuration already exists
        if oc get bc "$name" >/dev/null 2>&1; then
            oc delete bc "$name"
            echo "Removed build configuration: $name"
        fi

        # Extract the associated ImageStream name from the build configuration YAML
        # yq was the easiest way to just do this
        imagestream=$(yq eval '.spec.output.to.name' "$file" | awk -F: '{print $1}')
        
        if [[ -n "$imagestream" ]]; then
            # Check if the ImageStream exists
            if ! oc get is "$imagestream" >/dev/null 2>&1; then
                # Create the ImageStream using the extracted value
                oc create imagestream "$imagestream"
                echo "Created ImageStream: $imagestream"
            fi
        fi

        oc create -f "$file"
        echo "Created build configuration: $name"
    done

    echo "Build configurations imported from $import_directory."
}

# Check for the number of arguments
if [[ "$#" -lt 3 ]]; then
    echo "Insufficient number of arguments."
    echo "Usage: ./build_config_migration.sh export <source_project_name> <export_directory>"
    echo "Usage: ./build_config_migration.sh import <target_project_name> <import_directory>"
    exit 1
fi

command="$1"
project_name="$2"
directory="$3"

if [[ "$command" == "export" ]]; then
    export_build_configs "$project_name" "$directory"
elif [[ "$command" == "import" ]]; then
    # Check if yq is installed first
    import_build_configs "$project_name" "$directory"
else
    echo "Invalid command. Please specify either 'export' or 'import'."
    exit 1
fi

