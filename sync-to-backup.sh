#!/bin/bash

# The script synchronizes content while preserving ownership of a directory
# (source) with another directory (destination) on the local system.
#
# The script assumes the following directory layout on both source and
# destination:
#
#       /<a base directory>/<dataset>/<filesystem>
#
# with <a base directory> varying depending on whether we refer to
# the source (e.g. a locally mounted NFS share): /mnt/source/users/user
#   - <base directory>: mnt/source
#   - <dataset>:        users
#   - <filesystem>:     user
#
# or the destination (e.g. a local disk): /mnt/destination/users/user
#   - <base directory>: mnt/destination
#   - <dataset>:        users
#   - <filesystem>:     user
#
# On destination the <dataset> directory must exist. The <filesystem> 
# directory will be created by rsync.
#
# Directories owned by another user than the user running this script
# must have the <dataset> directory owned by that other user on 
# destination. This usually does not apply to root.
#
# The user running the script must be able to sudo as the users
# defined in the backup map.

start=$(date +%s.%N)
declare -A map=(
  ["node/machine1"]="root"
  ["users/user0"]="user0"
  ["projects/project1"]="user1"
)
source_base_dir="/mnt/source"
destination_base_dir="/mnt/destination"
rsync_args="-avtogE --delete"
slowdown=1

# arguments: 1. user, 2. rsync args, 3. from, 4. to
_sync() {
  if ! [ "$#" == "4" ]; then
    echo -ne "  \n  wrong number of paramters in call to ${FUNCNAME} ($#)"
    sleep ${slowdown}
    echo -e " \e[31mprogram will exit\e[0m"
    exit 0
  fi;
  echo -e "\e[32m"
  sudo -u ${1} /usr/bin/rsync ${2} ${3} ${4}
  echo -e "\e[0m"
}

echo
echo -e "This will sync all files from source: \e[97m\e[1m${source_base_dir}\e[0m"
echo -e "                      to destination: \e[97m\e[1m${destination_base_dir}\e[0m"
echo
echo 'Make sure the source is not empty, otherwise the script will delete all the files on destination!'
echo
echo -e "\033[31;7mIMPORTANT\033[0m: All source shares must be mounted prior to running this script."
echo
read -p 'Are all the source filesystems mounted on this host? (yes/no): ' answer

if [ "${answer}" == "yes" ]; then
  read -p 'Are you sure? (yes/no): ' confirmation
  if [ "${answer}" == "yes" ] && [ "${confirmation}" == "yes" ]; then
    for share in "${!map[@]}"; do
      owner=${map[${share}]}
      # remove <filesystem>, e.g. users/user becomes users
      dataset=$(echo ${share%/*})
      source="${source_base_dir}/${share}"
      destination="${destination_base_dir}/${dataset}"
      echo -e "\n\e[97m\e[1msync\e[0m \e[33m\e[1m${source}\e[0m"
      echo "  -> using: user=${owner}, args=${rsync_args}, from=${source}, to=${destination}"
      echo -ne "  -> checking if destination directory \e[1m${destination}\e[0m exists... "
      if [ -d ${destination} ]; then
        sleep ${slowdown}
        echo -e "\e[32myes\e[0m"
        echo -ne "  -> checking if \e[1m${source}\e[0m is mounted... "
        mountpoint=$(/usr/bin/nfsstat -m|grep ${source}|awk '{ print $1 }')
        sleep ${slowdown}
        if [ "${mountpoint}" == "${source}" ]; then
          echo -e "\e[32myes\e[0m"
          _sync "${owner}" "${rsync_args}" "${source}" "${destination}"
        else
          echo -e "\e[31mno, sync skipped\e[0m"
        fi;
      else
        sleep ${slowdown}
        echo -e "\e[31mno, sync skipped\e[0m"
      fi;
    done;
  else
    echo ''
    echo 'operation aborted.'
  fi;
fi;
end=$(echo "$(date +%s.%N) - ${start}" | bc)
duration=$(printf "%.2f seconds" ${end})
echo -e "\n\e[97m\e[1mfinished in ${duration} seconds\e[0m\n"
exit 0
