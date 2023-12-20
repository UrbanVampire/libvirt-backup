#!/bin/bash
#
# VM's backup using libvirt.
# by UrbanVampire
# https://github.com/UrbanVampire
#
# Inspired by William Lam's ghettoVCB for VMWare: https://github.com/lamw/ghettoVCB
# Some ideas got from:
# sebastiaanfranken's vm-backup: https://gist.github.com/sebastiaanfranken/3ccec782f6e687ce0e30418bdfff78a4
# cabal95's vm-backup: https://gist.github.com/cabal95/e36c06e716d3328b512b
# Mark's multi-distro installer: https://unix.stackexchange.com/questions/46081/identifying-the-system-package-manager/571192#571192
#
# KNOWN ISSUES:
# Paths and names with spaces are NOT supported.

# Get script name
OWNNAME=$(basename $0)
SCRIPTNAME="${OWNNAME%.*}"

# Config file
CONFIGFILE="$0.config"
# One may prefer to store config in /etc
#CONFIGFILE="/etc/$SCRIPTNAME.config"
# WARNING! In that case you need to perform SUDO check.
# Just uncomment this string.
#if [ $EUID -ne 0 ]; then echo "Must be run with superuser privileges: sudo $OWNNAME"; exit 1; fi

# Functions

# Check if util is present and install it if needed
checkandinstall(){
	# 1st parameter - program name
	# 2nd parameter - program package
	if [ -z "$1" ]; then
		# echo 'Program name to check is empty.'
		return
	fi
	if [ -z "$2" ]; then
		package="$1"
	else
		package="$2"
	fi
	echo "Checking '$1'... "
	a=$(which $1)
	if [ -z "$a" ]; then
		echo "Not found. Installing:"
		if [ -x "$(command -v apk)" ];       then sudo apk add --no-cache $package
		elif [ -x "$(command -v apt-get)" ]; then sudo apt-get install -y $package
		elif [ -x "$(command -v dnf)" ];     then sudo dnf install $package
		elif [ -x "$(command -v yum)" ];     then sudo yum install -y $package
		elif [ -x "$(command -v zypper)" ];  then sudo zypper install $package
		elif [ -x "$(command -v pacman)" ];  then sudo pacman -S $package

		else echo -e "FAILED: Package manager not recognized. You must manually install '$1' util ('$package' package)."
			echo "Please contact UrbanVampire@GitHub (https://github.com/UrbanVampire)"
			echo "to add support for your package manager."
			exit 1
		fi
 		if [ $? -ne 0 ]; then
			echo -e "\nSomething went wrong during '$1' util ('$package' package) installation. Please install it manually."
			echo "Exiting."
			exit 1
		fi
	else
		echo "Found."
	fi
}
# Function to get domains list
getdom(){
	virsh list --all | tail -n +3 | awk '{print $2}'
}
# Function to get domain's disks list
getdisks(){
	virsh domblklist $DOMAIN --details | grep disk | awk '{print $4}'
}
# Add ending slash to path if needed
slasher(){
	case $1 in
	*/)
		echo $1
		;;
	*)
		echo $1/
		;;
	esac
}
# Output verbose log info
verboselog(){
	if [ ! -z "$VERBOSE" ] && [ $VERBOSE == 1 ]; then
		logger "$1"
	fi
}
# Output log info
logger(){
	# Current date and time
	a=$(date +"%Y-%m-%d %T.%6N")
	# Collect messages for e-mail and Telegram
	LOGTEXT=$(echo "$LOGTEXT\n[$a] - $1")
	# STDOUT
	if [ ! -z "$LOG2STD" ] && [ $LOG2STD == 1 ]; then
		echo $1
	fi
	# systemd
	if [ ! -z "$LOG2SYSD" ] && [ $LOG2SYSD == 1 ]; then
		systemd-cat -t $SCRIPTNAME echo "$1"
	fi
	# Logfile
	if [ ! -z "$LOG2FILE" ] && [ $LOG2FILE == 1 ]; then
		if [ -z "$LOGFILE" ]; then # Logfile specified?
				LOGFILE=$0.log
		fi
		echo "[$a] - $1" >> $LOGFILE
	fi
}
# Log if command returns an error
errorer(){
	outp=$(eval $1 2>&1)
	if [ $? -ne 0 ]; then
		logger "ERROR: $outp"
		return 1
	fi
	return 0
}

# Does config exist?
if [ ! -e $CONFIGFILE ]; then
	echo -e "\nLooks like I'm running for the first time."
	echo "At least I can't find my config file: $CONFIGFILE."
	echo "I'll create one."

	echo -e "\nBut first we need to check and install some utils. You may be prompted for SUDO password."
	# install requred utils
	checkandinstall awk gawk
	checkandinstall grep
	checkandinstall tail coreutils
	checkandinstall sed
	checkandinstall curl
	checkandinstall 7z p7zip-full
	checkandinstall tar
	checkandinstall gzip
	checkandinstall bzip2
	checkandinstall pigz

	a="### $SCRIPTNAME config file.

### Commented (started with \"#\") stings are ignored.

### Please remember that the computer always does what its TOLD to do, not what you'd WANT it to do.

### Folder to store backups:
BACKUPSTORAGE=\"/mnt/BackUp\"

### Backups folder structure pattern.
### \"(BUVMname)\" will be replaced with the VM's name.
BACKUPMASK=\"(BUVMname)/(BUVMname)_\$(date +%Y-%m-%d_%H-%M-%S)\"
#BACKUPMASK=\"(BUVMname)/\$(date +%Y)/\$(date +%m)/\$(date +%d)\"

### If set, backups will be compressed.
### Value must be one of the following:
### \"7z\" (recommended) - compress with 7zip (7z extention)
### \"tar.gz\" - compress with tar/gzip (tar.gz extention)
### \"pigz\" - compress with pigz (tar.gz extention)
### \"tar.bz\" - compress with tar/bzip2 (tar.bz extention)
### Default - do not compress.
COMPRESS=\"7z\"

### List of VMs to ignore during backup process, space separated.
### Default - backup all VMs.
#IGNORELIST=\"Vm1 Vm2\"

### Limit VM's backup to specified disks.
### Format:
### VM=\"/path/to/Disk1.qcow /path/to/Disk2.qcow\"
### where VM - virtual machine name,
### Disk1... - full path to VM's disk, space separated.
### If set, only listed disks will be copied.
### Default - backup all disks.
"
# form domains disks list
b=""
DOMAINS="$(getdom)"
for DOMAIN in $DOMAINS; do
	b=$(echo "$b\n#$DOMAIN=\"")
	DISKS="$(getdisks)"
	i=0
	for DISK in $DISKS; do
		if [ $i -gt 0 ]; then
			b=$(echo -e "$b ")
		fi
		i=1
		b=$(echo -e "$b$DISK")
	done
	b=$(echo -e "$b\"")
done
c="

### To automatically generate the list of VMs and it's disks
### just delete config file an run $OWNNAME script.

### Logging config.

### Verbose? If set to 0 or commented, only errors will be reported.
### Default - 0.
VERBOSE=1

### Report on succesful backup?
### If VERBOSE set to 0, on succesful backup no message will be displayed
### (and, more importantly, send to e-mail or Telegram).
### This option changes that behaviour.
### Default - 0.
#REPORTONSUCCESS=1

### Log to STDOUT? Default - 0.
LOG2STD=1

### Log to systemd? Default - 0.
#LOG2SYSD=1

### Log to logfile? Default - 0.
#LOG2FILE=1

### Log filename (if LOG2FILE is enabled).
### Default - same folder and name as script itself.
#LOGFILE=\"/var/log/$SCRIPTNAME.log\"

### Send logs to e-mail? Default - 0.
#LOG2EMAIL=1
### SMTP Settings (if LOG2EMAIL is enabled):
### SMTP Server:port:
#SMTPServer=\"smtp.mail.com:587\"
### SMTP Server User:
#SMTPUser=\"user@email.com\"
### SMTP Server password:
#SMTPPass=\"YourEmailPassword\"
### FROM addr/name:
#SMTPFrom=\"BackUp Robot <user@email.com>\"
### TO addr/name:
#SMTPTo=\"Ме Myself And I <user@email.com>\"
### Email subject:
#SMTPSubj=\"Backup Report \$(date +%Y-%m-%d)\"

### Send Logs to Telegram via Bot? Default - 0.
#LOG2TELEGRAM=1
### Telegram settings (if LOG2TELEGRAM is enabled):
### Bot API key:
#TLGAPIKEY=\"1234567890:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\"
### User(s) ID(s) to send message to, space separated:
#TLGUSERID=\"111111111 222222222\"
### Timeout. Default - 10.
#TLGTIMEOUT=10
"
	echo "$a$b$c" > $CONFIGFILE
	if [ $? -ne 0 ]; then
		echo "Error creating file $CONFIGFILE!"
		exit 1
	fi

	echo -e "\nConfig file $CONFIGFILE created."
	echo "Feel free to edit it the way you need."
	echo "If you make a mistake, just delete that file and run me again, I'll create a new one."

	echo -e "\nLooks like everything's ready. Now edit my config file: $CONFIGFILE"
	echo "and then run me again."
	exit 1
fi

# Read config
source $CONFIGFILE

# Do some preparitions.
LOGTEXT=""
ERRORS=0
WARNINGS=0

# OK, let's start with backup itself

# We need root rights
if [ $EUID -ne 0 ]; then echo "Must be run with superuser privileges: sudo $OWNNAME"; exit 1; fi

# Get domains list
DOMAINS="$(getdom)"

BACKUPSTORAGE=$(slasher $BACKUPSTORAGE)
IFS=', ' read -r -a ignore <<< "$IGNORELIST"

for DOMAIN in $DOMAINS; do

	if [[ " ${ignore[*]} " =~ " ${DOMAIN} " ]]; then
		verboselog "Skipping domain '$DOMAIN' per config."
		continue
	fi

	# Create backup folder
	# Generate path
	BACKUPFOLDER=$(echo $BACKUPSTORAGE$(slasher $BACKUPMASK))
	# Replace macro with actual VM's name
	BACKUPFOLDER=$(echo "${BACKUPFOLDER//(BUVMname)/"$DOMAIN"}")
	verboselog "Creating folder $BACKUPFOLDER."
	if [ ! -d $BACKUPFOLDER ]; then
		errorer "mkdir -p $BACKUPFOLDER"
		if [ $? -ne 0 ]; then
			verboselog "Error creating folder $BACKUPFOLDER. '$DOMAIN' skipped."
			ERRORS=1
			continue
		fi
	fi

	# Store VM's settings
	verboselog "Storing '$DOMAIN' settings to '$BACKUPFOLDER$DOMAIN.xml'."
	virsh dumpxml $DOMAIN > $BACKUPFOLDER$DOMAIN.xml

	# Get disks info
	# Is VM has own config?
	if [ -v $DOMAIN ]; then
		verboselog "'$DOMAIN' has own disks list."
		LIST=${!DOMAIN}
		grepper=""
		for a in $LIST; do
			if [ -z "$grepper" ]; then
				grepper=$a
			else
				grepper=$(echo $grepper\|$a)
			fi
		done
	else
		grepper="disk"
	fi

	# Get disk names
	TARGETS=`virsh domblklist "$DOMAIN" --details | grep -P $grepper | awk '{print $3}'`
	# Get disk images
	IMAGES=`virsh domblklist "$DOMAIN" --details | grep -P $grepper | awk '{print $4}'`

	# Do some backcheck
	for a in $LIST; do
		if [[ ${IMAGES} != *$a* ]];then
			logger "WARNING! Disk image $a not found on '$DOMAIN'. Please check config."
			WARNINGS=1
		fi
	done
	if [ -z "$TARGETS" ]; then
		logger "WARNING! No disks found. '$DOMAIN' skipped."
		WARNINGS=1
		continue
	fi

	# Get VM status
	STATUS=$(virsh dominfo $DOMAIN | grep State | awk '{print $2}')

	# Do the snapshot
	if [ $STATUS == "shut" ]; then
		verboselog "VM '$DOMAIN' is shut off, skipping snapshot creation."
	else
		verboselog "Creating snapshot for '$DOMAIN'."
		DISKSPEC=""
		grepper2=""
		for a in $TARGETS; do
			DISKSPEC="$DISKSPEC --diskspec $a,snapshot=external"
			if [ -z "$grepper2" ]; then
				grepper2=$a
			else
				grepper2=$(echo $grepper2\|$a)
			fi
		done
		errorer "virsh snapshot-create-as --domain "$DOMAIN" --name backup --no-metadata --atomic --disk-only $DISKSPEC"
		if [ $? -ne 0 ]; then
			logger "Failed to create snapshot for '$DOMAIN'".
			ERRORS=1
			continue
		fi
		SNAPSHOTIMAGES=$(virsh domblklist $DOMAIN --details | grep -P $grepper2 | awk '{print $4}')
	fi

	# Copy disk images
	verboselog "Copying disks for '$DOMAIN'."
	for t in $IMAGES; do
		NAME=`basename "$t"`
		a="'$t' -> '$BACKUPFOLDER$NAME'"
		verboselog "$a"
		errorer "cp '$t' '$BACKUPFOLDER$NAME'"
		if [ $? -ne 0 ]; then
			logger "Failed to copy $a".
			ERRORS=1
		fi
	done

	# Merge changes back.
	if [ $STATUS != "shut" ]; then
		verboselog "Removing snapshots for '$DOMAIN'."
		for t in $TARGETS; do
			errorer "virsh blockcommit "$DOMAIN" "$t" --active --pivot"
			if [ $? -ne 0 ]; then
				logger "Could not merge changes for disk $t of '$DOMAIN'. VM may be in invalid state."
				ERRORS=1
			fi
		done
		if [ $ERRORS -ne 0 ]; then
			continue
		fi
		# Cleanup left over backup images.
		verboselog "Do some cleanups."
		for t in $SNAPSHOTIMAGES; do
			errorer "rm -f '$t'"
			if [ $? -ne 0 ]; then
				logger "Could not delete snapshot image $t of '$DOMAIN'. Remove it manually."
				ERRORS=1
			fi
		done
	fi

	if [ ! -z "$COMPRESS" ] ; then
		verboselog "Archiving backup for '$DOMAIN' with $COMPRESS."
		archivename=$(echo "$BACKUPFOLDER" | sed 's:/*$::')
		case $COMPRESS in
			7z)
				errorer "7z a $archivename.7z "$BACKUPFOLDER"/*"
				;;
			tar.gz)
				errorer "sudo tar -zcvf $archivename.tar.gz -C "$BACKUPFOLDER" . "
				;;
			tar.bz)
				errorer "sudo tar -jcvf $archivename.tar.bz -C "$BACKUPFOLDER" . "
				;;
			pigz)
				errorer "sudo tar --use-compress-program="pigz -9 " -cvf $archivename.tar.gz -C "$BACKUPFOLDER" . "
				;;
			*)
				logger "Unknown archive type: $COMPRESS."
				ERRORS=1
				continue
				;;
		esac
		if [ $? -ne 0 ]; then
			logger "Error archiving $BACKUPFOLDER."
			ERRORS=1
			continue
		fi
		# Removing archived files
		errorer "rm -R $BACKUPFOLDER"
		if [ $? -ne 0 ]; then
			logger "WARNING: Could not delete $BACKUPFOLDER after archiving."
			WARNINGS=1
		fi
	fi
done

if [ "${ERRORS}" == 1 ]; then
	logger "Backup completed with errors."
elif [ "${WARNINGS}" == 1 ]; then
	logger "Backup completed with warnings."
else
	if [ ! -z "$REPORTONSUCCESS" ] && [ $REPORTONSUCCESS == 1 ]; then
		logger "Backup completed successfully."
	else
		verboselog "Backup completed successfully."
	fi
fi

# Send e-mail.
if [ ! -z "$LOG2EMAIL" ] && [ $LOG2EMAIL == 1 ]; then
	if [ -z "$SMTPServer" ]; then logger "SMTPServer not set." ; LOG2EMAIL=0 ; fi
	if [ -z "$SMTPUser" ]; then logger "SMTPUser not set." ; LOG2EMAIL=0 ; fi
	if [ -z "$SMTPPass" ]; then logger "SMTPPass not set." ; LOG2EMAIL=0 ; fi
	if [ -z "$SMTPFrom" ]; then logger "SMTPFrom not set." ; LOG2EMAIL=0 ; fi
	if [ -z "$SMTPTo" ]; then logger "SMTPTo not set." ; LOG2EMAIL=0 ; fi
	if [ -z "$SMTPSubj" ]; then
		SMTPSubj="Backup Test Report $(date +%Y-%m-%d)"
	fi
	if [ $LOG2EMAIL == 1 ]; then
		if [ ! -z "$LOGTEXT" ]; then
			TMPFILE=$(mktemp)
			echo -e "From: $SMTPFrom\nTo: $SMTPTo\nSubject: $SMTPSubj\n\n$LOGTEXT" > $TMPFILE
			curl "$SMTPServer" --ssl-reqd --user "$SMTPUser:$SMTPPass" --mail-from "$SMTPFrom" --mail-rcpt "$SMTPTo" --upload-file $TMPFILE > /dev/null
			rm $TMPFILE
		fi
	fi
fi

# Send Telegram message
if [ ! -z "$LOG2TELEGRAM" ] && [ $LOG2TELEGRAM == 1 ]; then
	if [ -z "$TLGAPIKEY" ]; then logger "TLGAPIKEY not set." ; LOG2TELEGRAM=0 ; fi
	if [ -z "$TLGUSERID" ]; then logger "TLGUSERID not set." ; LOG2TELEGRAM=0 ; fi
	if [ -z "$TLGTIMEOUT" ]; then
		TLGTIMEOUT=10
	fi
	if [ $LOG2TELEGRAM == 1 ]; then
		if [ ! -z "$LOGTEXT" ]; then
			for USERID in $TLGUSERID; do
				curl -s --max-time $TLGTIMEOUT -d "chat_id=$USERID&disable_web_page_preview=1&text=$(sed 's/\\n/\n/g' <<< $LOGTEXT)" "https://api.telegram.org/bot$TLGAPIKEY/sendMessage" > /dev/null
			done
		fi
	fi
fi
