#!/bin/bash

# This bash script is used to backup a user's home directory to /tmp/.

if [ -z $1 ]; then
        echo "No Folder to backup."
        exit 1
else
        if [ ! -d "/share/$1" ]; then
                echo "Directory $1 doesn't exist."
                exit 1
        fi
        source=$1
fi

input=/share/$source
output=/share/eSATA1/${source}_backup_$(date +%Y-%m-%d_%H%M%S).tgz
                                                                                                                                                                                                                                                                               
function total_files { 
        find $1 -type f | wc -l
}

function total_directories {
        find $1 -type d | wc -l
}

function total_archived_directories {
        tar -tzf $1 | grep  /$ | wc -l
}
 
function total_archived_files {
        tar -tzf $1 | grep -v /$ | wc -l
}

tar -czvf $output $input 2> /dev/null

src_files=$( total_files $input )
src_directories=$( total_directories $input )

arch_files=$( total_archived_files $output )
arch_directories=$( total_archived_directories $output )

echo "Files to be included: $src_files"
echo "Directories to be included: $src_directories"
echo "Files archived: $arch_files"
echo "Directories archived: $arch_directories"

if [ $src_files -eq $arch_files ]; then
        echo "Backup of $input completed!"
        echo "Details about the output backup file:"
        ls -l $output
else
        echo "Backup of $input failed!"
fi