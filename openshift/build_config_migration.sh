#!/bin/bash

check_dependency() {
    command -v "$1" >/dev/null 2>&1 || { echo >&2 "$1 is required but it's not installed. Aborting."; exit 1; }
}

check_dependency "jq"

export_build_configs() {
    source_project="$1"
    export_directory="$2"

    oc project "$source_project"

    if [[ ! -d "$export_directory" ]]; then
        mkdir -p "$export_directory"
        echo "Created export directory: $export_directory"
    fi

    oc get bc -o json | jq -r '.items[] | .metadata.name' | while IFS= read -r name; do
        oc get bc "$name" -o json > "$export_directory/$name.json"
        echo "Exported $name.json"
    done

    echo "Build configurations exported to $export_directory directory."
}

import_build_configs() {
    target_project="$1"
    import_directory="$2"

    oc project "$target_project"

    for file in "$import_directory"/*.json; do
        # Extract the build configuration name from the file name
        name="${file##*/}"
        name="${name%.json}"

        # Check if the build configuration already exists
        if oc get bc "$name" >/dev/null 2>&1; then
            oc delete bc "$name"
            echo "Removed build configuration: $name"
        fi

        # Extract the associated ImageStream name without the tag from the build configuration JSON
        imagestream=$(jq -r '.spec.output.to.name | split(":")[0]' "$file" 2>/dev/null)

        if [[ -n "$imagestream" ]]; then
            # Check if the ImageStream exists
            if ! oc get is "$imagestream" >/dev/null 2>&1; then
                # Create the ImageStream using the extracted value
                oc create imagestream "$imagestream"
                echo "Created ImageStream: $imagestream"
            fi
        fi
        # Replace 'python:3.10-slim' with 'python:3.10-slim-bullseye' in the build configuration JSON using jq
        jq '.spec.strategy.sourceStrategy.from.name |= sub("python:3.10-slim"; "python:3.10-slim-bullseye")' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

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
    import_build_configs "$project_name" "$directory"
else
    echo "Invalid command. Please specify either 'export' or 'import'."
    exit 1
fi
