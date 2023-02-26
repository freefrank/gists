#!/bin/bash

set -e

function show_help {
    echo "Usage: $0 <directory> [<output directory>]"
    echo "Compresses all .rar files in the input directory and subdirectories into .zip files using pigz (if installed) for faster compression."
    echo ""
    echo "Options:"
    echo "-h, --help      Show this help message and exit."
    echo ""
    echo "Author: ChatGPT"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# -lt 1 ]]; then
    show_help
    exit 1
fi

# Get absolute path of input directory
input_dir="$(realpath "$1")"

# Create output directory if it doesn't exist
if [[ $# -eq 2 ]]; then
    output_dir="$(realpath "$2")"
    mkdir -p "$output_dir"
fi

# Create working directory
working_dir="/tmp/rar/working"
mkdir -p "$working_dir"

# Find all rar archives in the input directory and subdirectories
shopt -s globstar
rar_files=("$input_dir"/**/*.rar)
if [[ ${#rar_files[@]} -eq 0 ]]; then
    echo "No rar files found in $input_dir"
    exit 0
fi

for rar_file in "${rar_files[@]}"; do
    # Check if rar archive is password protected
    rar_pswd="$(unrar p -inul "$rar_file" 2>/dev/null | grep -Po 'Password:\s*\K.*')"
    if [[ -n $rar_pswd ]]; then
        echo "Skipping password-protected file $rar_file"
        continue
    fi
    
    # Extract rar archive to working directory with progress bar
    echo "Extracting $rar_file..."
    unrar x -y "$rar_file" "$working_dir" | pv -s $(du -sb "$rar_file" | awk '{print $1}') >/dev/null
    
    # Create zip archive with same name and location as rar archive with progress bar
    rar_dir="$(dirname "$rar_file")"
    rar_base="$(basename "$rar_file")"
    zip_name="${rar_base%.rar}.zip"
    zip_file="$rar_dir/$zip_name"
    echo "Creating $zip_file..."
    cd "$working_dir"
    if command -v pigz &> /dev/null
    then
        tar -cf - . | pigz --best > "$zip_file" 2>&1 | pv -s $(du -sb "$working_dir" | awk '{print $1}') >/dev/null
    else
        zip -r -q "$zip_file" . | pv -s $(du -sb "$working_dir" | awk '{print $1}') >/dev/null
    fi
    
    # Move zip archive to output directory if specified
    if [[ $# -eq 2 ]]; then
        mv "$zip_file" "$output_dir"
    fi
    
    # Delete original rar archive if there are no 2 parameter
    if [[ $# -eq 1 ]]; then
        echo "Deleting $rar_file..."
        rm "$rar_file"
    fi
done

echo "Done!"
