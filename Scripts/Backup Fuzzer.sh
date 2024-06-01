#!/bin/bash

read -p "Please enter the URL: " url
extensions_file="$(dirname "$0")/extensions.txt"

# Remove trailing slash from URL
url="${url%/}"

# Extract the domain from the URL
domain="${url#*://}"

# Read extensions from the file
IFS=$'\n' read -d '' -r -a ext_array < "$extensions_file"

# Generate the URLs with different extensions and variations
urls=()
for ext in "${ext_array[@]}"; do
    urls+=("$url/$domain.$ext")
    urls+=("$url/www.$domain.$ext")
    urls+=("$url/$domain.$domain.$ext")
    urls+=("$url/www.$domain.$domain.$ext")
    urls+=("$url/$domain.$ext/")
    urls+=("$url/www.$domain.$ext/")
    urls+=("$url/$domain.$domain.$ext/")
    urls+=("$url/www.$domain.$domain.$ext/")
done

# Process the URLs and extract the desired format
processed_urls=()
for url in "${urls[@]}"; do
    filename=$(basename "$url")
    processed_urls+=("${filename#*/}")
done

# Write the URLs to the output file
output_file="$domain.txt"
for url in "${processed_urls[@]}"; do
    echo "$url" >> "$output_file"
done

echo "Processed URLs have been written to $output_file."