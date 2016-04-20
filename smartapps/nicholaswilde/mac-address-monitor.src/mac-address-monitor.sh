#!/bin/sh

# Get name of config file
fileName=`basename "$0"`         # Name of script
configPath="./$fileName.cfg"

# Check that config file exists
if [ ! -f "$configPath" ]; then
  logger "$configPath does not exist"
  logger "Exiting ..."
  exit 1
fi

source $configPath

# Define variables
echo "$baseUrl"
echo "$secretKey"
echo "$appId"
echo "$macAddress"

targetSpec=`ip route show | grep -i 'default via'| awk '{print $3 }'`
header="Authorization: Bearer $secretKey"

onParams="device/on"
offParams="device/off"

onUrl=$baseUrl"/"$appId"/"$onParams
offUrl=$baseUrl"/"$appId"/"$offParams

deviceState="off"

# Get list of all mac addresses on the network
macAddresses=`sudo nmap -sP "$targetSpec"/24 | awk '/MAC Address:/{printf $3;print "; ";}'`

# List all MAC addresses
# echo "$macAddresses"

case "$macAddresses" in
  *"$macAddress"*)
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
