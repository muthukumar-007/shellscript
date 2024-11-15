#!/bin/bash

# Load configuration file for FTP/SFTP credentials
CONFIG_FILE="config.conf"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file '$CONFIG_FILE' not found."
    exit 1
fi

# Function to check if the source directory exists and is readable
check_source_directory() {
    if [ ! -d "$1" ]; then
        echo "Error: Source directory '$1' does not exist."
        exit 1
    elif [ ! -r "$1" ]; then
        echo "Error: No read permissions for source directory '$1'."
        exit 1
    fi
}

# Function to check if files matching the pattern exist and are readable in the source directory
check_files_exist_and_permissions() {
    local source_dir=$1
    local pattern=$2

    if ! ls "$source_dir"/$pattern &>/dev/null; then
        echo "Error: No files matching pattern '$pattern' found in '$source_dir'."
        exit 1
    fi

    # Check read permissions for each file matching the pattern
    for file in "$source_dir"/$pattern; do
        if [ ! -r "$file" ]; then
            echo "Error: No read permissions for file '$file'."
            exit 1
        fi
    done
}

# Function to check if the destination directory exists and is writable (for local moves)
check_destination_directory_permissions() {
    if [ ! -d "$1" ]; then
        echo "Error: Destination directory '$1' does not exist."
        exit 1
    elif [ ! -w "$1" ]; then
        echo "Error: No write permissions for destination directory '$1'."
        exit 1
    fi
}

# Function to move files locally
move_local() {
    local source_dir=$1
    local pattern=$2
    local destination_dir=$3

    # Move files matching the pattern
    mv "$source_dir"/$pattern "$destination_dir"
    if [ $? -eq 0 ]; then
        echo "Files moved successfully to $destination_dir"
    else
        echo "Failed to move files."
        exit 1
    fi
}

# Function to upload files to FTP/SFTP
upload_remote() {
    local protocol=$1
    local source_dir=$2
    local pattern=$3
    local destination_url=$4
    local account_name=$5

    # Dynamically fetch user and password based on the account name
    local user_var="FTP_USER_$account_name"
    local pass_var="FTP_PASS_$account_name"
    local user=${!user_var}
    local pass=${!pass_var}

    # Check if credentials are set
    if [ -z "$user" ] || [ -z "$pass" ]; then
        echo "Error: Credentials for account '$account_name' not found in the config file."
        exit 1
    fi

    for file in "$source_dir"/$pattern; do
        curl -T "$file" "$protocol://$destination_url" --user "$user:$pass"
        if [ $? -eq 0 ]; then
            echo "File '$file' uploaded successfully to $destination_url"
        else
            echo "Failed to upload file '$file'."
            exit 1
        fi
    done
}

# Check if the correct number of arguments are provided
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <source_directory> <file_pattern> <destination> <protocol> <account_name>"
    echo "Protocol options: local, ftp, sftp"
    exit 1
fi

# Assign parameters to variables for readability
SOURCE_DIR="$1"
PATTERN="$2"
DESTINATION="$3"
PROTOCOL="$4"
ACCOUNT_NAME="$5"

# Validate the protocol and take action accordingly
case "$PROTOCOL" in
    local)
        check_source_directory "$SOURCE_DIR"
        check_files_exist_and_permissions "$SOURCE_DIR" "$PATTERN"
        check_destination_directory_permissions "$DESTINATION"
        move_local "$SOURCE_DIR" "$PATTERN" "$DESTINATION"
        ;;
    ftp | sftp)
        check_source_directory "$SOURCE_DIR"
        check_files_exist_and_permissions "$SOURCE_DIR" "$PATTERN"
        upload_remote "$PROTOCOL" "$SOURCE_DIR" "$PATTERN" "$DESTINATION" "$ACCOUNT_NAME"
        ;;
    *)
        echo "Error: Invalid protocol. Use 'local', 'ftp', or 'sftp'."
        exit 1
        ;;
esac
