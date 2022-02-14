#!/bin/sh

## last edit: 20220214

## Variables
BACKUP_SRC_PATH=${1%/}
BACKUP_SOURCE_PATH=${2%/}
NUM_OF_RETAINED_BACKUPS=$3
BACKUP_FILE_NAME=ROTATING-Backup-`hostname`-$4
BACKUP_FILE_LIST=$BACKUP_FILE_NAME"_list.txt"
RM_BACKUP_LIST=$BACKUP_FILE_NAME"_rm_list.txt"

## To Manually override path and set and uncomment the following variables:
# BACKUP_SOURCE_PATH=/mnt/Backup
# BACKUP_DEST_PATH=/mnt/Backup
# NUM_OF_RETAINED_BACKUPS=6
# BACKUP_FILE_NAME=ROTATING-Backup-`hostname`-weekly

ERROR0="No Arguments passed"
ERROR1="pease enter a backup source path, then destination and a number"
ERROR2="pease enter a backup destination path, then a number"
ERROR3="Enter a number of backups to keep"
ERROR4="Error, enter a valid storage Path for Backup Destination"

## print variables, uncomment for debugging
# echo BACKUP_SOURCE_PATH 	 = $BACKUP_SOURCE_PATH
# echo BACKUP_DEST_PATH 	 = $BACKUP_DEST_PATH
# echo NUM_OF_RETAINED_BACKUPS = $NUM_OF_RETAINED_BACKUPS
# echo BACKUP_FILE_NAME 		 = $BACKUP_FILE_NAME
# echo BACKUP_FILE_LIST 		 = $BACKUP_FILE_LIST
# echo RM_BACKUP_LIST 	 	 = $RM_BACKUP_LIST

## test arguments
echo " Arguments passed:" ;
echo "		argument 1:	$1" ;
echo "		argument 2:	$2" ;
echo "		argument 3:	$3" ;
echo "		argument 4:	$4" ;

## first Test if user provided any arguments
if [ "$#" -eq 0 ]
	then
		echo "		
		This script is for backing up the current folder of the linux filesystem
		onto a tar file, while keeping a specified number of versions.
		Originally written to backup the root of Proxmox VE, 
		but later modified to backup the current folder.

		Licensing:
		This program is free software: you can redistribute it and/or modify
		it under the terms of the GNU General Public License as published by
		the Free Software Foundation, either version 3 of the License, or
		(at your option) any later version.

		This program is distributed in the hope that it will be useful,
		but WITHOUT ANY WARRANTY; without even the implied warranty of
		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		GNU General Public License for more details.

		You should have received a copy of the GNU General Public License
		along with this program.  If not, see <https://www.gnu.org/licenses/>.
		
		for questions or feedback check out: 
		https://github.com/Mikesco3/rotating-tar-backup.sh
		"
		echo '\n'
		
		echo "ERROR0" $ERROR0 ;
		echo "  usage, run followed by these arguments: 
			1st argument: /path/to/backupSource or ./ for current folder, 
			2nd argument: /path/to/backupDestination (has to be full path), 
			3rd argument: n (number of backups to keep), 
			4th argument: (optional): backup type (manual, daily, weekly, monthly, etc)" ;
		echo "  for Example: ";
		echo "              rotating-backup.sh /mnt/ExtHD 3 weekly";
			
		exit 1
fi

echo '\n'

### Tests on First Argument  Source
## if not empty or contains just a number instead of a path
case $1 in
    ''|[0-9]*) echo "ERROR1" $ERROR1 ;;
    *) echo "backup Source path:" $1 ;;
esac

echo '\n' 


## check if backup path starts with slash
# case "$BACKUP_SOURCE_PATH" in
#   *\/*)
#     echo "Good, contains a slash"
#     ;;
#   *)
#     echo "Error: check your backup path" '\n'
# 	echo "argument Provided:"
#     ;;
# esac
echo $BACKUP_SOURCE_PATH 

echo '\n' 

### Tests on Second Argument Destination
## if not empty or contains just a number instead of a path
case $2 in
    ''|[0-9]*) echo "ERROR2" $ERROR2 ;;
    *) echo "backup Destination path:" $2 ;;
esac

echo '\n' 

## check if backup path starts with slash
case "$BACKUP_DEST_PATH" in
  *\/*)
    echo "Good, contains a slash"
    ;;
  *)
    echo "Error: check your backup path" '\n'
	echo "argument Provided:"
    ;;
esac
echo $BACKUP_DEST_PATH 

### Tests on Third Argument 
## check if NOT empty and if it is a number 
case $3 in
    ''|*[!0-9]*) 
		echo "	Error with third argument"
		echo "	ERROR3" $ERROR3 
		exit 1
	;;
    *) 	echo "	backups to keep:" $3 ;;
esac

echo '\n' 

### START
if [ -d "$BACKUP_DEST_PATH" ]; then
	## Take action if $BACKUP_DEST_PATH exists ##
	echo "Backing up Proxmox to ${BACKUP_DEST_PATH}..."
	cd /
	pwd
	echo tar "$BACKUP_DEST_PATH/$BACKUP_FILE_NAME""_root_""`date +"%Y-%m-%d-%H%M"`".tgz .

	## Be sure to add to the --exclude lines the path for 
	## any other location that should NOT be included in the tar file
	## for example the Destination folder for the backups.
	tar \
	--exclude='./dev' \
	--exclude='./sys' \
	--exclude='./proc' \
	--exclude='./mnt' \
	--exclude='./tmp' \
	--exclude='./run' \
	--exclude='./var/log' \
	--exclude='./var/spool' \
	--exclude='./var/lib/samba/private' \
	--exclude='./var/lib/lxcfs' \
	--exclude='./var/lib/vz' \
	--exclude='./lost+found' \
	--exclude='./tank100' \
	--exclude='./_Backup' \
	--exclude=${BACKUP_DEST_PATH} \
	--exclude='*/dump/*' \
	--exclude='*/template/iso/*' \
	--exclude='*/template/cache/*' \
	-zcvf "$BACKUP_DEST_PATH/$BACKUP_FILE_NAME""_root_""`date +"%Y-%m-%d-%H%M"`".tgz .
	
	echo '\n'
	cd $BACKUP_DEST_PATH
	pwd 
	echo '\n'

	## Build a list of current backups
	ls -1 |grep tgz |grep -i $BACKUP_FILE_NAME > $BACKUP_FILE_LIST
	cat $BACKUP_FILE_LIST

	## Prepare list of backups to be deleted
	cp $BACKUP_FILE_LIST "`echo $BACKUP_FILE_LIST`"_bak
	tac $BACKUP_FILE_LIST  | \
	awk "{ if ( NR > $NUM_OF_RETAINED_BACKUPS ) print; }" | \
	tac > $RM_BACKUP_LIST
	cat  $RM_BACKUP_LIST
	
	echo '\n'

	## Delete previous backups
	if [ -f "$BACKUP_DEST_PATH/$RM_BACKUP_LIST" ]; then
		echo "$BACKUP_DEST_PATH/$RM_BACKUP_LIST exists."
		echo "About to delete backups older than $NUM_OF_RETAINED_BACKUPS backups"
		
		echo '\n'
		
		for f in $( cat $RM_BACKUP_LIST ) ; do 
			echo "$f" 
			rm "$f"
			done
		echo "Done"
		echo '\n'
		## rename the list of backups just deleted
		mv $RM_BACKUP_LIST "`echo $RM_BACKUP_LIST`"_bak
	else 
		echo "$BACKUP_DEST_PATH/$RM_BACKUP_LIST does not exist."
		exit 1
	fi
	
	echo '\n'

else
	###  Control will jump here if $BACKUP_DEST_PATH does NOT exists ###
	echo $ERROR4 
	echo "Error: ${BACKUP_DEST_PATH} not found. Can not continue."
	exit 1
fi
### END

## GPLv3 
	# This program is free software: you can redistribute it and/or modify
	# it under the terms of the GNU General Public License as published by
	# the Free Software Foundation, either version 3 of the License, or
	# (at your option) any later version.
	#
	# This program is distributed in the hope that it will be useful,
	# but WITHOUT ANY WARRANTY; without even the implied warranty of
	# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	# GNU General Public License for more details.
	#
	# You should have received a copy of the GNU General Public License
	# along with this program.  If not, see <https://www.gnu.org/licenses/>.
	#
##
	
## 20210824: Added gpl, made it ready for proxmox VE 7 and published on github 
## 20220214: changed it to backup any current folder and published on github 
