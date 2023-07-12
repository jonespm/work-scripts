#!/bin/bash
# Simple script to get all routes in all the projects I have access to and print it as a CSV list with the TTLs

# CSV header
echo "Name,Route,TTL"

# Get a list of all projects
projects=$(oc get projects --no-headers -o custom-columns=NAME:.metadata.name)

# Iterate through each project
for project in $projects; do
    # Get routes in the current project and extract name and host
    routes=$(oc get routes -n $project -o custom-columns=NAME:.metadata.name,HOST:.spec.host --no-headers)
    
    # Iterate through each route
    while read -r name host; do
        # Lookup TTL using dig command
        dig_output=$(dig $host)
        ttl=$(echo "$dig_output" | awk '/^;; ANSWER SECTION:$/ { getline; print $2 }')

        # Output in CSV format
        echo "$name,$host,$ttl"
    done <<< "$routes"
done
