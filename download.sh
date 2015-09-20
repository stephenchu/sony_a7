#! /bin/bash

set -o errexit
set -o nounset

USAGE=$(cat <<-"EOS"
  Usage:

    ./download.sh <SD_CARD_VOLUME> [ <DESTINATION> ]

  Example:

    ./download.sh /Volumes/NO\ NAME ~/Pictures/
EOS
)

VOLUME="${1?$USAGE}"
MY_PICTURES="${2:-"${HOME}/Pictures"}"

is_empty_folder() {
  if [ ! "$(ls -A "$1")" ]; then
    true
  else
    false
  fi
}

parse_folder_name() {
  local dir=$(basename "$1")

  local folder_number="${dir:0:3}"
  local year="201${dir:3:1}"
  local mm="${dir:4:2}"
  local dd="${dir:6:2}"
  printf "%s|" "$folder_number" "${year}_${mm}_${dd}"
}

find_similarly_named_destination_folder() {
  local date_string="$1"
  if ls -dA "${MY_PICTURES}"/${date_string}* &> /dev/null; then
    echo -n "$(ls -dA "${MY_PICTURES}"/${date_string}* 2>/dev/null)/RAW"
  fi
}

mkdir_destination_folder() {
  local date_string="$1"
  local folder="${MY_PICTURES}/${date_string}/RAW"
  mkdir -p "$folder"
  echo -n "$folder"
}

copy_files() {
  local folder="$1"
  local destination="$2"
  echo "Copying $(ls -lA "$folder" | wc -l) files from '$folder' to '$destination'..."
  rsync --info=progress2 --partial --archive "$folder/" "$destination"
}

backdate_folder() {
  local folder="$1"
  touch -r "$(find "$folder" -type f -print -quit)" "${folder%/RAW}"
}

download_pictures() {
  local PICTURE_FOLDER="${VOLUME}/DCIM"

  find -s "$PICTURE_FOLDER" -mindepth 1 -type d -print0 | while IFS= read -r -d $'\0' source; do
    if is_empty_folder "$source"; then
      echo "Skipped empty folder '$source'."
      continue
    fi

    local result=$(parse_folder_name "$source")
    local folder_number=$(echo "$result" | cut -d '|' -f 1)
    local date_string=$(echo "$result" | cut -d '|' -f 2)

    local destination="";
    if [ ! "$(find_similarly_named_destination_folder "$date_string")" = "" ]; then
      destination=$(find_similarly_named_destination_folder "$date_string")
    else
      destination=$(mkdir_destination_folder "$date_string")
    fi

    copy_files "$source" "$destination"

    backdate_folder "$destination"
  done
}
download_pictures
