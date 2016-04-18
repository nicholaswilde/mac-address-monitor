#!/bin/sh

fileName=`basename "$0"` >&2         # Name of install file
source ./$fileName.cfg

# Define variables
echo $appId
appMac="$macAddress"
targetSpec=`ip route show | grep -i 'default via'| awk '{print $3 }'`
header="Authorization: Bearer "$secretKey

baseUrl="https://graph-na02-useast1.api.smartthings.com/api/smartapps/installations"
onParams="device/on"
offParams="device/off"

onUrl=$baseUrl"/"$appId"/"$onParams
offUrl=$baseUrl"/"$appId"/"$offParams

deviceState="off"

# Get list of all mac addresses on the network
macAddresses=`sudo nmap -sP "$targetSpec"/24 | awk '/MAC Address:/{printf $3;print "; ";}'`

# List all MAC addresses
# echo $macAddresses

case "$macAddresses" in
  *"$appMac"*)
  echo "address found"
  deviceState=on
  ;;
esac

if [ "$deviceState" = on ]; then
  echo "turning on"
  curl -H "$header" -X GET "$onUrl"
else
  echo "turning off"
  curl -H "$header" -X GET "$offUrl"
fi
