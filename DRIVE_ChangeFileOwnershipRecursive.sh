#!/bin/bash
#
# This script will recursively transfer ownership of a file/folder to a new user.
# It will also remove read/write permissions from the old user for all files.
# If a file is found that is not owned by the old user the ownership does not
# change, though the new user is granted write permissions to the file. 
#
# NOTE: It may be necessary to run this script twice to fix write/read permissions 
# after changing file ownership.
#
# A log file will attempt to be created in the same directory as this script is executed.
#

version=1.0

# Current file/folder owner
current_owner="techops@serrc.org"

# New file/folder owner
new_owner="serrcnet-admin@serrc.org"

# ID of root directory in which to recursively work
root_directory="0B_cmbW4BbPuONE95VHdVbmdxTTA"

# Path to the Gam application
gam="/Applications/gam/gam"

# -------------------------------------------------
# Shouldn't need to make changes below this point
# -------------------------------------------------

main () {

    script_name=$(basename "$0")
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    log_file="$script_path/${script_name%.*}.log" 

    sub_dirs=( $root_directory )

    log_nodate ""
    log_nodate "################################################################################################"
    log_nodate "  $script_name  version $version"
    echo "  See log file at $log_file"
    log_nodate "################################################################################################"

    log_nodate ""
    log_date "Starting"
    log_nodate ""
    log_nodate "Root directory ID: $root_directory"
    log_nodate "Current owner: $current_owner"
    log_nodate "New owner: $new_owner"
    log_nodate ""

    # Loop until all directories have been processed
    while ! [ ${#sub_dirs[@]} -eq 0 ]; do

        log_nodate ""
        log_date "Checking contents of directory ID: ${sub_dirs[0]}"
        log_nodate "--------------------------------------------------------------------------------------------------"

        # Initial check of root directory

        # Get contents of current directory
        IFS=$'\n'
        directory_contents=( $($gam user $new_owner show filelist anyowner query "('${sub_dirs[0]}' in parents)") )

        # Loop through contents of current directory
        for ((i=1; i < ${#directory_contents[@]}; i++)); do
            file_url=$(echo ${directory_contents[$i]} | awk -F',' '{print $3}')
            if [[ $file_url == *folders* ]]; then
                # If item is a directory, ID is needed for processing instead of URL
                file_url=${file_url##*/}

                # Save directory for recursive search
                sub_dirs+=( $file_url )                
            fi

            # Get file ownership and permissions
            file_acls=$($gam user $new_owner show drivefileacl $file_url)
            file_owner=$(echo "$file_acls" | grep -B 2 owner | head -1 | awk -F ': ' '{print $2}')
            file_writers=( $(echo "$file_acls" | grep -B 2 writer | grep emailAddress | awk -F ' ' '{print $2}') )
            file_readers=( $(echo "$afile_aclscl" | grep -B 2 reader | grep emailAddress | awk -F ' ' '{print $2}') )
            
            # Change file ownership to new owner if owned by current owner
            if [[ $file_owner == "$current_owner" ]]; then
                log_date "Transfering file to user $new_owner: $file_url"
                echo ""
                $gam user $current_owner add drivefileacl $file_url user $new_owner role owner
            fi

            # If file not owned by new owner, make sure new owner has writer permissions
            if [[ "$file_owner" != "$new_owner" ]] && [[ ! ${file_writers[*]} =~ "$new_owner" ]]; then
                log_date "Granting writer privileges to user $new_owner: $file_url"
                echo ""
                $gam user $new_owner add drivefileacl $file_url anyone role writer
            fi

            # If current user in writers or readers group, remove permission
            if [[ ${file_writers[*]} =~ "$current_owner" ]] || [[ ${file_readers[@]} =~ "$current_owner" ]]; then
                log_date "Removing writer/reader privileges from user $current_owner: $file_url"
                echo ""
                $gam user $new_owner delete drivefileacl $file_url $current_owner
            fi
        done

        # Remove first directory from array
        unset sub_dirs[0]
        sub_dirs=( ${sub_dirs[@]} )

    done

    log_nodate ""
    log_date "Completed"
}


log_date () {
	# logging function formatted to include a date
	printf "%b\n" "$(date '+%Y/%m/%d %H:%M:%S'): $1" >> "$log_file" 2>&1
	printf "%b\n" "$1"
}


log_nodate () {
	# logging function formatted to not include a date
	printf "%b\n" "$1" >> "$log_file" 2>&1
	printf "%b\n" "$1"
}

main