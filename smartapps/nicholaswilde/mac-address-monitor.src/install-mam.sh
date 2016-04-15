#!/bin/bash
# http://wiki.bash-hackers.org/howto/conffile
# https://github.com/nicholaswilde/mac-address-monitor/tree/master/smartapps/nicholaswilde/mac-address-monitor.src

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
defaultDir="$homeDir/$installDir"   # 
installPath=""                      # Installation path
filePath=""                         # Path of script file
configPath=""
deviceName=""                       # Name of device

downloadUrl="https://raw.githubusercontent.com/nicholaswilde/$installDir/master/smartapps/nicholaswilde/$installDir.src/$scriptFile"

appId=""
secretKey=""

### User input ###
#-- Device Name --#
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
defaultDir="$homeDir/$deviceName"

#-- AppID --#
echo -n "Enter the AppID and press [ENTER]: "
read appId

if [ "$appId" = "" ]; then
    echo An AppID was not entered
    echo Exiting ...
    exit 1
fi

#-- Secret Key --#
echo -n "Enter the Secret Key and press [ENTER]: "
read secretKey

if [ "$secretKey" = "" ]; then
    echo "A Secret Key was not entered!"
    echo "Exiting ..."
    exit 1
fi

#-- Installation Directory --#
echo -n "Script installation directory [$defaultDir]: "
read installPath

if [ "$installPath" = "" ]; then
    installPath=$defaultDir
fi

filePath="$installPath/$scriptFile"
configPath="$installPath/$configFile"

#-- Cron Interval --#
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

#-- Check for required packages --#
echo Checking for required packages ...
bNmap=`which nmap` >&2

if [ "$bNmap" = "" ]; then
    echo "nmap is not installed. Would you like to install it?"
    options=("Yes" "No")
    select opt in "${options[@]}"; do
        case $opt in
            "Yes")
                echo "Installing nmap ..."
                # sudo apt-get -y install nmap
                # Check that nmap was installed properly
                # bNmap=`which nmap` >&2
                # if [ "$bNmap" = "" ]; then
                    # echo "There was an error installing nmap."
                    # echo "Exiting ..."
                    # exit 1
                # fi
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
    runuser -l "$user" -c "mkdir \"$installPath\""
fi

### Installation ###
# Download the script
echo "Downloading script ..."
echo "$downloadUrl"
runuser -l "$user" -c "wget \"$downloadUrl\" -O \"$filePath\""
if [ ! "$?" = 0 ]; then
   echo "Download failed!"
   echo "Exiting ..."
   exit 1
fi
# Change file permissions
echo Making the script executable ...
# chmod +x "$filePath"

# Export credentials to config file
echo "Exporting credentials to $configFile ..."
# delete file
# touch "$configPath"
# echo "appId=$appId" >> "$configPath"
# echo "secretKey=$secretKey" >> "$configPath"

# Add script to cron
echo "Adding script to cron ..."

# case "$cronInterval" in
#   "15")
        # cru a $scriptName "* * * * * $filePath"
        # cru a $scriptName30 "* * * * * sleep 15; $filePath"
        # cru a $scriptName30 "* * * * * sleep 30; $filePath"
        # cru a $scriptName30 "* * * * * sleep 45; $filePath"
        #;;
# "30")
        # cru a $scriptName "* * * * * $filePath"
        # cru a $scriptName30 "* * * * * sleep 30; $filePath"
        #;;
# "60")
        # cru a $scriptName "* * * * * $filePath"
        #;; 
# esac

echo "Installation finished!"
