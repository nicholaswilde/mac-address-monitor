#!/bin/bash
# http://wiki.bash-hackers.org/howto/conffile
# https://github.com/nicholaswilde/mac-address-monitor/tree/master/smartapps/nicholaswilde/mac-address-monitor.src

# Debug 
bDebug = "true"
# TODO: Add debug function

# Check if run as sudo
if [ "$USER" != "root" ]; then
    echo Please run as sudo
    exit 1
fi

### Define variables ###
user=`who am i | awk '{print $1}'` >&2  # User who ran script using sudo
homeDir=`eval echo ~$user` >&2          # Home directory of user
installFile=`basename "$0"` >&2         # Name of install file

scriptName="MAC Address Monitor"    # Name of script
installDir="mac-address-monitor"    #
scriptFile="$installDir.sh"         #
configFile="$installDir.cfg"        #
defaultDir="$homeDir"   # 
installPath=""                      # Installation path
filePath=""                         # Path of script file
configPath=""
deviceName=""                       # Name of device

downloadUrl="https://raw.githubusercontent.com/nicholaswilde/$installDir/master/smartapps/nicholaswilde/$installDir.src/$scriptFile"

appId=""
secretKey=""

#----------------------- Check for required packages ---------------------------#
echo Checking for required packages ...
bNmap=`which nmap` >&2

if [ "$bNmap" = "" ]; then
    echo "nmap is not installed. Would you like to install it?"
    options=("Yes" "No")
    select opt in "${options[@]}"; do
        case $opt in
            "Yes")
                echo "Installing nmap ..."
                sudo apt-get -y install nmap
                # Check that nmap was installed properly
                bNmap=`which nmap` >&2
                if [ "$bNmap" = "" ]; then
                    echo "There was an error installing nmap."
                    echo "Exiting ..."
                    exit 1
                fi
                break
                ;;
            "No")
                echo "nmap is needed for $scriptName"
                # echo "Exiting ..."
                # exit 1
                break
                ;;
            *) "Invalid choice. Try 1 or 2";;
        esac
    done
else
    echo "nmap is already installed"
fi

bCurl=`which curl` >&2

if [ "$bCurl" = "" ]; then
    echo "curl is not installed. Would you like to install it?"
    options=("Yes" "No")
    select opt in "${options[@]}"; do
        case $opt in
            "Yes")
                echo "Installing curl ..."
                sudo apt-get -y install curl
                # Check that nmap was installed properly
                bCurl=`which curl` >&2
                if [ "$bCurl" = "" ]; then
                    echo "There was an error installing curl."
                    echo "Exiting ..."
                    exit 1
                fi
                break
                ;;
            "No")
                echo "curl is needed for $scriptName"
                # echo "Exiting ..."
                # exit 1
                break
                ;;
            *) "Invalid choice. Try 1 or 2";;
        esac
    done
else
    echo "curl is already installed"
fi

############################# User input ######################################
#----------------------------- Secret Key ------------------------------------#
echo -n "Enter the Secret Key and press [ENTER]: "
read secretKey

# Validate the secret key
if [[ ! "$secretKey" =~ ^[a-zA-Z0-9]{8}[-]([a-zA-Z0-9]{4}-){3}[a-zA-Z0-9]{12}$ ]]; then
    echo "The Secret Key was not entered or invalid!"
    echo "Exiting ..."
    exit 1
fi

#---------------------------- Device Name ------------------------------------#
echo -n "Enter the device name and press [ENTER]: "
read deviceName

# Replace all spaces with dashes
deviceName=${deviceName// /-} >&2

# Convert to lowercase
deviceName=`echo -n "$deviceName" | awk '{print tolower($0)}'` >&2
#echo "$deviceName"

# Redefine variables based on device name
scriptFile="$deviceName.sh"
configFile="$deviceName.cfg"
defaultDir="$homeDir"

#------------------------------ AppID ----------------------------------------#
# TODO: Get list of appIds using secretKey and present options including a custom one
echo -n "Enter the AppID and press [ENTER]: "
read appId

if [ "$appId" = "" ]; then
    echo An AppID was not entered
    echo Exiting ...
    exit 1
fi

#---------------------- Installation Directory -------------------------------#
echo -n "Script installation directory [$defaultDir]: "
read installPath

if [ "$installPath" = "" ]; then
    installPath=$defaultDir
fi

installPath="$installPath/$installDir"

filePath="$installPath/$scriptFile"
configPath="$installPath/$configFile"

# echo $configPath

#-------------------------- Cron Interval -------------------------------------#
# TODO: Add timer and present only possible options

echo "Cron interval: "
options=("15s" "30s" "60s" "Quit")
select opt in "${options[@]}"; do
    case $opt in
        "15s")
            echo "You chose 15s"
            cronInterval=15
            break
            ;;
        "30s")
            echo "You chose 30s"
            cronInterval=30
            break
            ;;
        "60s")
            echo "You chose 60s"
            cronInterval=60
            break
            ;;
        "Quit")
            echo "Exiting ..."
            exit 0
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
done



#-- Secret Key --#

# Find index of $array
function findIndex() {
    local i=0;
    for str in "${array[@]}"; do
        if [[ $str == *$1* ]]; then
            echo $i
            return
        else
            ((i++))
        fi
    done
    echo "-1"
}

curlResp=`curl -H "Authorization: Bearer $secretKey" -X GET "https://graph.api.smartthings.com/api/smartapps/endpoints"` &> /dev/null

# See if an error was returned
curlErr=`echo $curlResp | grep -Po '(?<="error":")[^"]*'` &> /dev/null

# Exit if an error occured
if [ ! $curlErr = "" ]; then
    echo "An error occured! $curlErr"
    echo "Exiting ..."
    exit 1
fi

# Find the URIs from the JSON response
uris=`echo $curlResp | grep -Po '(?<="uri":")[^"]*'` &> /dev/null

# Convert uris to an array
readarray -t array <<<"$uris"

# Find the index of the uri
index=`findIndex $appId`

# Find the baseUrls from the JSON response
baseUrls=`echo $curlResp | grep -Po '(?<="base_url":")[^"]*'` &> /dev/null

# Convert baseUrls to array
readarray -t baseUrls <<<"$baseUrls"
baseUrl=${baseUrls[$index]}

echo "baseUrl: $baseUrl"

#-- MAC address --#
echo "Scanning network for MAC addresses ..."

# Get IP address
targetSpec=`ip route show | grep -i 'default via'| awk '{print $3 }'` >&2

# List MAC addresses using nmap
nmap -sP "$targetSpec"/24 | awk '/Nmap scan report for/{printf $5;}/MAC Address:/{print " => "$3;}'| sort
echo -n "Device MAC address [00:00:00:00:00:00]: "
read macAddress

# Validate mac address
if [[ ! "$macAddress" =~ ^([a-fA-F0-9]{2}:){5}[a-zA-Z0-9]{2}$ ]]; then
    echo "Invalid MAC address"
    echo "Exiting ..."
    exit 1
fi

#-- Installation Directory --#
if [ -d "$installPath" ]; then
    echo "Installation directory already exists!"
else
    echo "Making directory ..."
    runuser -l "$user" -c "mkdir -p \"$installPath\""
    echo $?
fi

### Installation ###
# Download the script
echo "Downloading script ..."
echo "$downloadUrl"
runuser -l "$user" -c "curl --create-dirs -o \"$filePath\" \"$downloadUrl\""
if [ ! "$?" = 0 ]; then
   echo "Download failed!"
   echo "Exiting ..."
   exit 1
fi
# Change file permissions
echo "Making the script executable ..."
chmod +x "$filePath"

#-- Config file --#
bConfigSkip=""
# Check if file already exists
if [ -f "$configPath" ]; then
    echo "$configPath already exists"
    echo "Would you like to replace it?"
    options=("Yes" "No")
    select opt in "${options[@]}"; do
        case $opt in
            "Yes")
                echo "Deleting $configPath ..."
                rm "$configPath"
                break
                ;;
            "No")
                echo "Skipping config file export ..."
                bConfigSkip="false"
                break
                ;;
            *) "Invalid choice. Try 1 or 2";;
        esac
    done
fi

# Export config file
if [ ! "$bConfigSkip" = "false" ]; then
    echo "Exporting credentials to $configFile ..."
    runuser -l "$user" -c "touch \"$configPath\""
    runuser -l "$user" -c "echo \"baseUrl=$baseUrl\" | tee -a \"$configPath\" &> /dev/null"
    runuser -l "$user" -c "echo \"macAddress=$macAddress\" | tee -a \"$configPath\" &> /dev/null"
    runuser -l "$user" -c "echo \"appId=$appId\" | tee -a \"$configPath\" &> /dev/null"
    runuser -l "$user" -c "echo \"secretKey=$secretKey\" | tee -a \"$configPath\" &> /dev/null"
fi

# Add script to cron
echo "Adding script to cron ..."

# case "$cronInterval" in
#   "15")
        # runuser -l "$user" -c "cru a $scriptName \"* * * * * $filePath\""
        # runuser -l "$user" -c "cru a $scriptName30 \"* * * * * sleep 15; $filePath\""
        # runuser -l "$user" -c "cru a $scriptName30 \"* * * * * sleep 30; $filePath\""
        # runuser -l "$user" -c "cru a $scriptName30 \"* * * * * sleep 45; $filePath\""
        #;;
# "30")
        # runuser -l "$user" -c "cru a $scriptName \"* * * * * $filePath\""
        # runuser -l "$user" -c "cru a $scriptName30 \"* * * * * sleep 30; $filePath\""
        #;;
# "60")
        # runuser -l "$user" -c "cru a $scriptName \"* * * * * $filePath\""
        #;;
# esac

echo "Installation finished!"
