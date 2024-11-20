#!/usr/bin/env bash
# th@bogus.net 2024 v1.00
# automation script for downloading maxmind data (and uploading to gravwell)
TODAY=$(date +"%Y%m%d")
CONFIG_FILE="$HOME/.mmuploadrc" # put your secrets in environment vars here

usage() {
    echo "Maxmind Database Downloader (and Gravwell Uploader) // (c) 2024 th@bogus.net"
    echo "Usage: $0 [-c|--config-file <CONFIG_FILE> ][-i|--id <ID>] [-l|--licence <LICENCE>] [-g|-gravwell-token <GRAVWELL_TOKEN>] [-u|-url <GRAVWELL_URL>]"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--id)
            ID="$2"
            shift 2
            ;;
        -l|--licence)
            LICENCE="$2"
            shift 2
            ;;
        -g|--gravwell-token)
            GRAVWELL_TOKEN="$2"
            shift 2
            ;;
        -u|--gravwell-url)
            GRAVWELL_URL="$2"
            shift 2
            ;;
        -c|--config-file)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            break
            ;;
    esac
done

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  echo "Warning: $CONFIG_FILE not found"
fi

if [[ -z "$ID" ]] || [[ -z "$LICENCE" ]]; then
  echo "Error: Both --id and --licence options are required."
  usage
fi

if [[ -z $(which curl) ]]; then 
  echo "Fatal: no curl installed"
  exit 1
fi

echo "Downloading MAXMIND database archives .."

for type in Country City; do
  curl -J -L -u $ID:$LICENCE "https://download.maxmind.com/geoip/databases/GeoLite2-$type/download?suffix=tar.gz" -o GeoLite2-$type.tar.gz
  curl -J -L -u $ID:$LICENSE "https://download.maxmind.com/geoip/databases/GeoLite2-$type/download?suffix=tar.gz.sha256" -o GeoLite2-$type.tar.gz.sha256
  if [ ! -s GeoLite2-$type.tar.gz ]; then
    echo "Fatal: Downloaded $type file is 0 bytes!"
    exit 1
  fi

  ## todo: check sha256 hash

  if [ ! -d GeoLite2-$type_$TODAY ]; then
    mkdir GeoLite2-$type_$TODAY || (echo "Error: Unable to create destination directory" && exit 1)
  else 
    ls -lart GeoLite2-$type_$TODAY
  fi

  tar zvxf GeoLite2-$type.tar.gz --strip-components=1 -C GeoLite2-$type_$TODAY || exit 1 

  if [[ ! -z $GRAVWELL_TOKEN ]]; then
    echo "Uploading MAXMIND Geolite2 $type mmdb to Gravwell server..."
    curl -k -X PUT --header \
      "Gravwell-Token: $GRAVWELL_TOKEN" \
      -F file=@GeoLite2-$type_$TODAY/GeoLite2-$type.mmdb \
      $GRAVWELL_URL

    if [ -d GeoLite2-$type_$TODAY ]; then
      echo "Cleaning up $type..."
      rm -r GeoLite2-$type_$TODAY
      rm -f GeoLite2-$type.tar.gz GeoLite2-$type.tar.gz.sha256
    fi
  fi
done
