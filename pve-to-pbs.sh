#!/bin/bash

# Backup server (PBS) IP
ipPBS="x.x.x.x"

# Backup server (PBS) repository
repPBS="datastore_name"

# Backup server (PBS) user
userPBS="user"

# Backup server (PBS) password
passPBS="Password"

# VM's to be ignored in shutdown/restart commands in script. Use VM ID separated by pipe symbol, example: ignoreVM="100|103|102"
ignoreVM=""

# Directories to include in backup that is excluded by default. Separate each full path by space, example: includeDIR="/config /etc/pve"
includeDIR=""

###########################

function check-if-root {
	if [[ ${EUID} -ne 0 ]] ; then
		echo "Aborting because you are not root" ; exit 1
	fi
}

function stopservices {
	# scan for running VM's and store result in an array
	echo "Scanning for VM's status..."
	mapfile -t runningVM < <(pvesh get /cluster/resources --type vm --human-readable --noborder --noheader |
	awk '{printf "%s\n",$1" "$15}' |
	sed -e 's/lxc\//\/usr\/sbin\/pct /g' -e 's/qemu\//\/usr\/sbin\/qm /g' |
	awk '{t=$2;$2=$3;$3=t;print;}' |
	grep 'running')

	# print out the status of all VM's
	echo "$(pvesh get /cluster/resources --type vm --human-readable --noborder --noheader |
	awk '{printf "%s\n","Container"" "$1"["$2"] ""named"" ["$13"] ""is"" "$15}' |
	sed -e 's/lxc\//ID /g' -e 's/qemu\//ID /g')"

	# shutdown the running VM's
	echo "Shutting down the running VM's..."
	if ! [[ "${ignoreVM//|/}" =~ ^[0-9]+$ ]]; then ignoreVM="null"; fi
	for i in "${runningVM[@]}"; do echo $i | grep -vE "$ignoreVM" | sed -e 's/running/shutdown/g' | /bin/sh & done

	# wait for all VM's to shutdown
	while grep 'running' <<< $(pvesh get /cluster/resources --type vm --human-readable --noborder --noheader |
	grep -vE "$ignoreVM" | awk '{printf "%s\n", $15}') > /dev/null; do
	sleep 1
	done
}

function backup {
	# auth and backup
	echo "Backing up.."
	export PBS_REPOSITORY="$ipPBS":"$repPBS"
	export PBS_PASSWORD="$passPBS"
	proxmox-backup-client backup "$userPBS".pxar:/ $(sed -e 's/[[:space:]]/ --include-dev /' -e '0,/\// s/\//--include-dev \//' <<< $includeDIR)
}

function startservices {
	# start only previously running VM's
	echo "Restarting VM's again..."
	for i in "${runningVM[@]}"; do echo $i | sed -e 's/running/start/g' | /bin/sh & done
}

function cleanup {
	# cleaning up auth info
	echo "Cleaning up.."
	export PBS_REPOSITORY=""
	export PBS_PASSWORD=""
}

##########

check-if-root
stopservices
backup
startservices
cleanup
