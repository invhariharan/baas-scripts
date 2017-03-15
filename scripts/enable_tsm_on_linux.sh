#!/bin/sh
#-----------------------------------------------------------------------------------------#
# (C) COPYRIGHT IBM Global Services,  2015                                                #
# Unpublished Work                                                                        #
# All Rights Reserved                                                                     #
# Licensed Material - Property of IBM                                                     #
#-----------------------------------------------------------------------------------------#
#              Global System Management Architecture TSM automation	                  #
#-----------------------------------------------------------------------------------------#
#  File      : enable_tsm_on_linux.sh                                                     #
#  Project   : Tivoli Storage Manager Client Installation and Configuration Automation    #
#  Author    : Scott Neibarger		  	                                          #
#  Date      :                                                                            #
#  Version   : See variable "level" below                                                 #
#                                                                                         #
#-----------------------------------------------------------------------------------------#
#  SCRIPT DESCRIPTION                                                                     #
#-----------------------------------------------------------------------------------------#
#                                                                                         #
#  Automates the installation, configuration, registration, and association of a TSM node.#
#  After the node is registered in a policy domain, it's associated with a backup schedule. #
#  After it's associated with a schedule, the scheduler service is started.		  #
#                                                                                         #
#  Input parms (see the "_Usage" function):                                               #
#	{ --install-and-configure | --configure-only} : Script operation                  #
#       { -dip }          : -d for optional debug to standard output			  #
#                    	 : -i for interactive mode to be prompted for password.           #
#			 : -p specifies the client will be configured with the preferred  #
#			    policy domain and schedule                                    #
#                                                                                         #
#-----------------------------------------------------------------------------------------#
#  HISTORY OF CHANGES :                                                                   #
#-----------------------------------------------------------------------------------------#
# Date         Author       Version     Modification                                      #
#                                                                                         #
level="1.0.0-20150513"
#                                                                                         #
# Next is the template level (version) used to implement this script.                     #
template_level="N/A" # After complete refactor by D. Satsura any template usage was lost.
#-----------------------------------------------------------------------------------------#

case $1 in
	"--install-and-configure")
		operation=$1;;
	"--configure-only")
		operation=$1;;
	*)
		echo "The first argument to the script is incorrect."
        	echo "Usage: enable_tsm_on_linux.sh { --install-and-configure | --configure-only } { -dip }"
        	exit 11;;
esac

DEBUG=0
INTERACTIVE=0
USEPREFERRED=0
USEKEYS=0
OURSERVER=""
OURPD=""
OURSCHED=""
OURDAILYINCREMENTAL=""
PREFERREDSTARTTIME=""
WINDOWLEEWAYBEFORE=""
WINDOWLEEWAYAFTER=""
STRICTWINDOW=""
SERVERCREDENTIALS=""
MYSERVERADMIN=""
MYSERVERPASSWORD=""
nodename=`hostname`
nodePassword="testpasswd"
basedir=$PWD
tmpdir=$basedir/tmp
logfile=$basedir/enable_tsm_on_linux.log
ftptmpfile="$basedir/ftpresults.txt"
rpmlist="$basedir/rpmlist.txt"
installfile=""
tsmbindir=""
excludefile=""
rc=0

source $PWD/GSMA_functions.sh

# added by shn on 041615
case $2 in
	"-di")
		DEBUG=1
		INTERACTIVE=1;;
	"-id")
		DEBUG=1
		INTERACTIVE=1;;
	"-idp")
		DEBUG=1
		INTERACTIVE=1
		USEPREFERRED=1;;
	"-pid")
		DEBUG=1
		INTERACTIVE=1
		USEPREFERRED=1;;
	"-pi")
		INTERACTIVE=1
		USEPREFERRED=1;;
	"-ip")
		INTERACTIVE=1
		USEPREFERRED=1;;
	"-i")
		INTERACTIVE=1;;
	"-dip")
		DEBUG=1
		INTERACTIVE=1
		USEPREFERRED=1;;
	*)
                echo "Usage: enable_tsm_on_linux.sh { --install-and-configure | --configure-only } { -dip }"
		exit 11;;
	"")
                echo "Usage: enable_tsm_on_linux.sh { --install-and-configure | --configure-only } { -dip }"
		exit 11;;
esac

if [ -f "$logfile" ];
then
	[ $DEBUG -eq 1 ] && _print_to_stdout "[main] Removing pre-existing log file $logfile"
	rm $logfile
fi

setup() {
	local currfunc="setup"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."
	_get_os_type
	_set_path

	if [ ! -d "$tmpdir" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Creating temporary working directory $tmpdir"
		mkdir -p $tmpdir
	fi

	gskcryptinstalled=0
	gsksslinstalled=0
	TIVsmAPIinstalled=0
	TIVsmBAinstalled=0
	tsmbindir="/opt/tivoli/tsm/client/ba/bin"
	parm_file=$(_script_parm_file_name)
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] parm_file is $parm_file."

	excludefile=$tsmbindir/inclexcl.txt

	if [ -f "$parm_file" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] $parm_file exists."
	else
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] $parm_file does not exist."
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Exiting with [RC=11]"

		_append_to_log "$logfile" "[$currfunc] [ERROR] $parm_file does not exist."
		_append_to_log "$logfile" "[$currfunc] [ERROR]"
		_append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
		_append_to_log "$logfile" "[$currfunc] [ERROR]"
		_append_to_log "$logfile" "[$currfunc] [ERROR] Exiting with [RC=11]"
		exit 11
	fi

	if [ -f "/usr/bin/expect" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] The expect binary exists so we can continue."
	else
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] The expect binary does not exist."
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Exiting with [RC=11]"

		_append_to_log "$logfile" "[$currfunc] [ERROR] The expect binary does not exist."
		_append_to_log "$logfile" "[$currfunc] [ERROR]"
		_append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
		_append_to_log "$logfile" "[$currfunc] [ERROR]"
		_append_to_log "$logfile" "[$currfunc] [ERROR] Exiting with [RC=11]"
		exit 11
	fi

	if [ -f "/usr/bin/expr" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] The expr binary exists so we can continue."
	else
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] The expr binary does not exist."
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Exiting with [RC=11]"

		_append_to_log "$logfile" "[$currfunc] [ERROR] The expr binary does not exist."
		_append_to_log "$logfile" "[$currfunc] [ERROR]"
		_append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
		_append_to_log "$logfile" "[$currfunc] [ERROR]"
		_append_to_log "$logfile" "[$currfunc] [ERROR] Exiting with [RC=11]"
		exit 11
	fi

	parse_input_parameters

	if [ $INTERACTIVE -eq 1 ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Prompting for the password."
		get_tsmserver_credentials
		get_node_password
	else
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Using encryption to get the password."
	fi

	installfile="$RELATIVEBASEDIR/$RELATIVEOSDIR/$CLIENTPACKAGE"

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

create_exclude_list() {
	local currfunc="create_exclude_list"
        local FSLIST=""
        local DIRLIST=""
        local EXCLUDES=""

        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	# added by shn on 042015
	if [ -f "$excludefile" ];
	then
		rm $excludefile
	fi

        # specify the internal field separator
        oIFS="$IFS"
        IFS=$';'

        EXCLUDE=`egrep '^EXCLUDE;' $parm_file`
        if [ $? -eq 1 ];
        then
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] There were no file exclusions to add."
        else
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Looping through list of files."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Line is: $EXCLUDE"

                read -a EXCLUDES <<< "$EXCLUDE"

                for EXCLUDE in ${EXCLUDES[@]};
                do
                        if [ $EXCLUDE = "EXCLUDE" ];
                        then
                                continue
                        fi

                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Writing $EXCLUDE to $excludefile"
                        _append_to_log "$logfile" "[$currfunc] Writing $EXCLUDE to $excludefile"
                        _append_to_file $excludefile "exclude $EXCLUDE"
                done
        fi

        EXCLUDEFS=`egrep '^EXCLUDEFS' $parm_file`
        if [ $? -eq 1 ];
        then
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] There were no file system exclusions to add."
        else
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Looping through list of files."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Line is: $EXCLUDEFS"

                read -a FSLIST <<< $EXCLUDEFS

                for FS in ${FSLIST[@]};
                do
                        if [ $FS = "EXCLUDEFS" ];
                        then
                                continue
                        fi

                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Writing $FS to $excludefile"
                        _append_to_log "$logfile" "[$currfunc] Writing $FS to $excludefile"
                        _append_to_file $excludefile "exclude.fs $FS"
                done
        fi

        EXCLUDEDIR=`egrep '^EXCLUDEDIR' $parm_file`
        if [ $? -eq 1 ];
        then
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] There were no directory exclusions to add."
        else
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Looping through list of files."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Line is: $EXCLUDE"

                read -a DIRLIST <<< $EXCLUDEDIR

                for DIR in ${DIRLIST[@]};
                do
                        if [ $DIR = "EXCLUDEDIR" ];
                        then
                                continue
                        fi

                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Writing $DIR to $excludefile"
                        _append_to_log "$logfile" "[$currfunc] Writing $DIR to $excludefile"
                        _append_to_file $excludefile "exclude.dir $DIR"
                done
        fi

        IFS="$oIFS"
        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

# Does the file byte count on our host match what's on the FTP server?
confirm_file_bytecount() {
	local currfunc="confirm_file_bytecount"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	# this should work with both ftp and sftp output
	actualbytecount=`grep -i "\-rw" $ftptmpfile | awk '{print $5}'`
	#downloadedbytecount=`ls -ltr $PWD/$CLIENTPACKAGE | awk '{print $5}'`

	if [ -f "$PWD/$CLIENTPACKAGE" ];
	then
		downloadedbytecount=`ls -ltr $PWD/$CLIENTPACKAGE | awk '{print $5}'`
	else
		downloadedbytecount=0
	fi

	if [ $downloadedbytecount -ne $actualbytecount ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] The file on the FTP server has $actualbytecount bytes while the downloaded file is $downloadedbytecount bytes."
		_append_to_log "$logfile" "[$currfunc] The file on the FTP server has $actualbytecount bytes while the downloaded file is $downloadedbytecount bytes."
		rc=-1
	else
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] $installfile was downloaded successfully."
		_append_to_log "$logfile" "[$currfunc] $installfile was downloaded successfully."
		rc=0
	fi

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

# We should always have /usr/bin/ftp on our target
download_client_package() {
	retrycount=3
	retry=3
	local currfunc="download_client_package"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	# does the file exist on the target host? If yes, then is it the same byte count? if yes, don't redownload
	if [ -e "$PWD/$CLIENTPACKAGE" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Client package exists on host; checking if it's the same byte count."
		_append_to_log "$logfile" "[$currfunc] Client package exists on host; checking if it's the same byte count."
		get_file_size_on_ftp_host

		if [ $actualbytecount -eq $downloadedbytecount ];
		then
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] $installfile already exists on this host."
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
			_append_to_log "$logfile" "[$currfunc] $installfile already exists on this host."
			rc=1
			return
		fi

		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] $installfile byte count on the host is $downloadedbytecount; actual should be $actualbytecount."
		_append_to_log "$logfile" "[$currfunc] $installfile byte count on the host is $downloadedbytecount; actual should be $actualbytecount."
	else
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] $PWD/$CLIENTPACKAGE does not exist on the local host."
		_append_to_log "$logfile" "[$currfunc] $PWD/$CLIENTPACKAGE does not exist on the local host."
	fi

	rc=0
	get_file_size_on_ftp_host
	transfer_file
	get_file_size_on_ftp_host
	confirm_file_bytecount

	# set retry to zero so we retry
	if [ "$rc" -eq "-1" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] confirm_file_bytecount returned -1; setting retry=0 so we try again."
		_append_to_log "$logfile" "[$currfunc] confirm_file_bytecount returned -1; setting retry=0 so we try again."
		retry=0
	fi

	# if the ftp didn't succeed the first, second, or third time, retry
	while [ $retry -lt $retrycount ]
	do
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Had to retry after download. RETRY=$retry; RETRYCOUNT=$retrycount."
		_append_to_log "$logfile" "[$currfunc] Had to retry after download. RETRY=$retry; RETRYCOUNT=$retrycount."

		while [ $rc -ne 0 ]
		do
			transfer_file
			get_file_size_on_ftp_host
			confirm_file_bytecount
			retry=$((retry+1))
		done

		if [ $rc -eq 0 ];
		then
			retry=$retrycount
		fi
	done

	if [ $rc -ne 0 ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Failed to download client package."
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Exiting with [RC=4]"

		_append_to_log "$logfile" "[$currfunc] [ERROR] Failed to download client package."
                _append_to_log "$logfile" "[$currfunc] [ERROR]"
                _append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                _append_to_log "$logfile" "[$currfunc] [ERROR]"
                _append_to_log "$logfile" "[$currfunc] [ERROR] Exiting with [RC=4]"

		exit 4
	fi

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

transfer_file() {
	local currfunc="transfer_file"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	# download the file using /usr/bin/ftp
	if [ $FTPPROTOCOL = "ftp" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Transferring file via $FTPPROTOCOL"
		_append_to_log "$logfile" "[$currfunc] Transferring file via $FTPPROTOCOL"
		# ftp the file
		/usr/bin/ftp -vi $FTPHOST 2>&1 1>$ftptmpfile <<ftp
			bin
			cd $RELATIVEBASEDIR/$RELATIVEOSDIR
			ls $CLIENTPACKAGE
			get $CLIENTPACKAGE
			quit
ftp
	fi

	# download the file using /usr/bin/sftp
	if [ $FTPPROTOCOL = "sftp" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Using protocol $FTPPROTOCOL (USEKEYS=$USEKEYS) to download file: ${installfile}"
		_append_to_log "$logfile" "[$currfunc] Using protocol $FTPPROTOCOL (USEKEYS=$USEKEYS) to download file: ${installfile}"

		# we're using expect as we will have to input the password
		if [ "$USEKEYS" = 0 ];
		then
			/usr/bin/expect -c "
			spawn /usr/bin/sftp $FTPUSER@$FTPHOST
			expect \"password:\"
			send \"$FTPPASS\r\"
			expect \"sftp>\"
			send \"ls -l $RELATIVEBASEDIR/$RELATIVEOSDIR/$CLIENTPACKAGE\r\"
			expect \"sftp>\"
			send \"get $RELATIVEBASEDIR/$RELATIVEOSDIR/$CLIENTPACKAGE\r\"
			expect \"sftp>\"
			send \"quit\r\"
			interact " > $ftptmpfile
		else
			/usr/bin/sftp $FTPUSER@$FTPHOST > $ftptmpfile <<sftp
			ls -l "$RELATIVEBASEDIR/$RELATIVEOSDIR/$CLIENTPACKAGE"
			get "$RELATIVEBASEDIR/$RELATIVEOSDIR/$CLIENTPACKAGE"
sftp
		fi
	fi

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

get_file_size_on_ftp_host() {
	local currfunc="get_file_size_on_ftp_host"
	local sshkeyoutput=null
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	if [ $FTPPROTOCOL = "ftp" ];
	then
		/usr/bin/ftp -vi $FTPHOST > $ftptmpfile 2>&1 <<ftp
			bin
			cd "$RELATIVEBASEDIR/$RELATIVEOSDIR"
			ls $CLIENTPACKAGE
			quit
ftp
		actualbytecount=`grep -i "\-rw" $ftptmpfile | awk '{print $5}'`
		downloadedbytecount=`ls -ltr $PWD/$CLIENTPACKAGE | awk '{print $5}'`
	fi

	if [ $FTPPROTOCOL = "sftp" ];
	then
		sshkeyoutput=`grep $FTPHOST $HOME/.ssh/known_hosts`

		if [ $? -eq 0 ];
		then
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Found a host key in $HOME/.ssh/known_hosts; no need to add it."
			_append_to_log "$logfile" "[$currfunc] Found a host key in $HOME/.ssh/known_hosts; no need to add it."
		else
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Adding ssh key with ssh-keyscan $FTPHOST to $HOME/.ssh/known_hosts."
			_append_to_log "$logfile" "[$currfunc] Adding ssh key with ssh-keyscan $FTPHOST to $HOME/.ssh/known_hosts."
			/usr/bin/ssh-keyscan $FTPHOST >> $HOME/.ssh/known_hosts
		fi

                # we're using expect as we will have to input the password
                if [ "$USEKEYS" = 0 ];
                then
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Calling /usr/bin/expect to invoke sftp so we can input the password."
                        _append_to_log "$logfile" "[$currfunc] Calling /usr/bin/expect to invoke sftp so we can input the password."

                        /usr/bin/expect -c "
                        spawn /usr/bin/sftp $FTPUSER@$FTPHOST
                        expect \"password:\"
                        send \"$FTPPASS\r\"
                        expect \"sftp>\"
                        send \"ls -l $RELATIVEBASEDIR/$RELATIVEOSDIR/$CLIENTPACKAGE\r\"
                        expect \"sftp>\"
                        send \"get $RELATIVEBASEDIR/$RELATIVEOSDIR/$CLIENTPACKAGE\r\"
                        expect \"sftp>\"
                        send \"quit\r\"
                        interact " > $ftptmpfile
                else
                        /usr/bin/sftp $FTPUSER@$FTPHOST > $ftptmpfile <<sftp
                        cd "$RELATIVEBASEDIR/$RELATIVEOSDIR"
                        ls -l "$RELATIVEBASEDIR/$RELATIVEOSDIR/$CLIENTPACKAGE"
                        quit
sftp
                fi
	fi

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

# this function creates or updates the $HOME/.netrc file
update_netrc() {
	local currfunc="update_netrc"
	local netrcfile="$HOME/.netrc"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	if [ -f $netrcfile ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Running: grep \"machine $FTPHOST login $FTPUSER password $FTPPASS\" $netrcfile"
		grep "machine $FTPHOST login $FTPUSER password $FTPPASS" $netrcfile 2>&1 1>/dev/null

		if [ $? -eq 0 ];
		then
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] The .netrc entry already exists; no need to create it."
			_append_to_log "$logfile" "[$currfunc] The .netrc entry already exists; no need to create it."
		else
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] $netrcfile exists so we'll append to it..."
			echo "machine $FTPHOST login $FTPUSER password $FTPPASS" >> $netrcfile
		fi
	else
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] $netrcfile does not exist, creating..."
		_append_to_log "$logfile" "[$currfunc] $netrcfile does not exist, creating..."
		echo "machine $FTPHOST login $FTPUSER password $FTPPASS" > $netrcfile
	fi

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

# installs the TSM client on Linux
install_linux_client()  {
	local currfunc="install_linux_client"
	local rpmoutput=null
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	_extract_archive "$PWD/$CLIENTPACKAGE"

	# Install the RPMs in the following order
	for rpm in gskcrypt gskssl TIVsmAPI TIVsmBA;
	do
		case $rpm in
			"gskcrypt")
				if [ "$gskcryptinstalled" -ne 1 ];
				then
					[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Running: sudo rpm -Uvi $gskcryptpackage"
					rpmoutput=`sudo rpm -Uvi $gskcryptpackage 2>&1`

					if [ $? -ne 0 ];
					then
						[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] RPM install failed: $rpmoutput."
						[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Exiting with [RC=4]"

						_append_to_log "$logfile" "[$currfunc] [ERROR] RPM install failed: $rpmoutput."
                				_append_to_log "$logfile" "[$currfunc] [ERROR]"
                				_append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                				_append_to_log "$logfile" "[$currfunc] [ERROR]"
                				_append_to_log "$logfile" "[$currfunc] [ERROR] Exiting with [RC=4]"

						exit 4
					else
						_append_to_log "$logfile" "[$currfunc] RPM install of $gskcryptpackage succeeded."
					fi
				else
					[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] $gskcryptpackage already installed; skipping."
				fi;;
			"gskssl")
				if [ "$gsksslinstalled" -ne 1 ];
				then
					[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Running: rpm -Uvi $gsksslpackage"
					rpmoutput=`sudo rpm -Uvi $gsksslpackage 2>&1`

					if [ $? -ne 0 ];
					then
						[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] RPM install failed: $rpmoutput."
						[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Exiting with [RC=4]"

						_append_to_log "$logfile" "[$currfunc] [ERROR] RPM install failed: $rpmoutput."
                				_append_to_log "$logfile" "[$currfunc] [ERROR]"
                				_append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                				_append_to_log "$logfile" "[$currfunc] [ERROR]"
                				_append_to_log "$logfile" "[$currfunc] [ERROR] Exiting with [RC=4]"

						exit 4
					else
						_append_to_log "$logfile" "[$currfunc] RPM install of $gsksslpackage succeeded."
					fi
				else
					[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] $gsksslpackage already installed; skipping."
				fi;;
			"TIVsmAPI")
				if [ "$TIVsmAPIinstalled" -ne 1 ];
				then
					[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Running: rpm -Uvi $TIVsmAPIpackage"
					rpmoutput=`sudo rpm -Uvi $TIVsmAPIpackage 2>&1`

					if [ $? -ne 0 ];
					then
						[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] RPM install failed: $rpmoutput."
						[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Exiting with [RC=4]"

						_append_to_log "$logfile" "[$currfunc] [ERROR] RPM install failed: $rpmoutput."
                				_append_to_log "$logfile" "[$currfunc] [ERROR]"
                				_append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                				_append_to_log "$logfile" "[$currfunc] [ERROR]"
                				_append_to_log "$logfile" "[$currfunc] [ERROR] Exiting with [RC=4]"

						exit 4
					else
						_append_to_log "$logfile" "[$currfunc] RPM install of $TIVsmAPIpackage succeeded."
					fi
				else
					[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] $TIVsmAPIpackage already installed; skipping."
				fi;;
			"TIVsmBA")
				if [ "$TIVsmBAinstalled" -ne 1 ];
				then
					[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Running: rpm -Uvi $TIVsmBApackage"
					rpmoutput=`sudo rpm -Uvi $TIVsmBApackage 2>&1`

					if [ $? -ne 0 ];
					then
						[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] RPM install failed: $rpmoutput."
						[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Exiting with [RC=4]"

						_append_to_log "$logfile" "[$currfunc] [ERROR] RPM install failed: $rpmoutput."
                				_append_to_log "$logfile" "[$currfunc] [ERROR]"
                				_append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                				_append_to_log "$logfile" "[$currfunc] [ERROR]"
                				_append_to_log "$logfile" "[$currfunc] [ERROR] Exiting with [RC=4]"

						exit 4
					else
						_append_to_log "$logfile" "[$currfunc] RPM install of $TIVsmBApackage succeeded."
					fi
				else
					[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] $TIVsmBApackage already installed; skipping."
				fi;;
		esac

	done

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
	return
}

check_linux_install() {
	local currfunc="check_linux_install"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	get_installed_rpms

	if [ $rc -eq 4 ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] All packages are installed so we can skip the download, extract, and install."
		rc=-1
	fi
}

get_installed_rpms() {
	local currfunc="get_installed_rpms"
	local rpmoutput=null
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Creating temporary RPM list."
	_append_to_log "$logfile" "[$currfunc] Creating temporary RPM list."

	local rpmoutput=`rpm -qa 2>&1 1> $rpmlist`

	if [ "$?" -ne 0 ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] RPM failed: $rpmoutput."
		_append_to_log "$logfile" "[$currfunc] RPM failed: $rpmoutput."
		exit 4
	else
		local totalrpms=`wc -l $rpmlist`
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] The installed packages temporary file has $totalrpms entries."
		_append_to_log "$logfile" "[$currfunc] The installed packages temporary file has $totalrpms entries."
	fi

	rc=0
	for rpm in gskcrypt gskssl TIVsm-API TIVsm-BA;
	do
		# set packageVariable to the value of $rpm
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Searching RPM DB: grep $rpm $rpmlist"
		packageVariable=`grep $rpm $rpmlist`

		if [ "$?" -eq 0 ];
		then
			rc=$((rc+1))
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Package $packageVariable is already installed."
			_append_to_log "$logfile" "[$currfunc] Package $packageVariable is already installed."

			case $rpm in
				"gskcrypt")
					[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Setting gskcryptinstalled to 1 for yes."
					gskcryptinstalledversion=`grep $rpm $rpmlist | tr "-" ";" | tr "." ";" | cut -d ";" -f2-5 | tr -d ";"`
					exprresult=`expr $gskcryptversion \>= $gskcryptinstalledversion`
					gskcryptinstalled=$exprresult;;
				"gskssl")
					[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Setting gsksslinstalled to 1 for yes."
					gsksslinstalledversion=`grep $rpm $rpmlist | tr "-" ";" | tr "." ";" | cut -d ";" -f2-5 | tr -d ";"`
					exprresult=`expr $gsksslversion \>= $gsksslinstalledversion`
					gsksslinstalled=$exprresult;;
				"TIVsm-API")
					[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Setting TIVsmAPIinstalled to 1 for yes."
					TIVsmAPIinstalledversion=`grep $rpm $rpmlist | tr "-" ";" | tr "." ";" | cut -d ";" -f3-5| tr -d ";"`
					exprresult=`expr $TIVsmAPIversion \>= $TIVsmAPIinstalledversion`
					TIVsmAPIinstalled=$exprresult;;
				"TIVsm-BA")
					[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Setting TIVsmBAinstalled to 1 for yes."
					TIVsmBAinstalledversion=`grep $rpm $rpmlist | tr "-" ";" | tr "." ";" | cut -d ";" -f3-5| tr -d ";"`
					exprresult=`expr $TIVsmBAversion \>= $TIVsmBAinstalledversion`
					TIVsmBAinstalled=$exprresult;;
			esac
		fi

		# set packageName to the value of $packageVariable; this acts like a hash
		#packageName=`eval echo $"$(echo ${!packageVariable})"`
	done

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

parse_input_parameters() {
	local currfunc="parse_input_parameters"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	# added by shn on 041915
	if [ "$operation" = "--install-and-configure" ];
	then
		get_transfer_details
	fi

        # set up some globals
        CONTACT=`egrep '^CONTACT' $parm_file | cut -d "=" -f2`
        PREFERREDSTARTTIME=`egrep '^SCHEDDETAILS' $parm_file | cut -d ";" -f2`
        STRICTWINDOW=`egrep '^SCHEDDETAILS' $parm_file | cut -d ";" -f3`
        WINDOWLEEWAYBEFORE=`egrep '^SCHEDDETAILS' $parm_file | cut -d ";" -f4`
        WINDOWLEEWAYAFTER=`egrep '^SCHEDDETAILS' $parm_file | cut -d ";" -f5`
	local TSMSERVERCOUNT=`egrep '^TSMSERVER' $parm_file | wc -l`

	# added by shn on 04092015
	if [ "$TSMSERVERCOUNT" -lt 1 ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Our TSMSERVER configuration item count is less than zero. Please check the parameter file and confirm TSMSERVER is not commented and does not contain spaces at the beginning of the line."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exiting with [RC=11]"

		_append_to_log "$logfile" "[$currfunc] [ERROR] Our TSMSERVER configuration item count is less than zero. Please check the parameter file and confirm TSMSERVER is not commented and does not contain spaces at the beginning of the line."
                _append_to_log "$logfile" "[$currfunc] [ERROR]"
                _append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                _append_to_log "$logfile" "[$currfunc] [ERROR]"
                _append_to_log "$logfile" "[$currfunc] Exiting with [RC=11]"
		exit 11
	fi

	# added by shn on 04092015
	if [ "$PREFERREDSTARTTIME" = "" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] We did not get any SCHEDDETAILS configuration item data. Please check the parameter file and confirm SCHEDDETAILS is not commented and does not contain spaces at the beginning of the line."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exiting with [RC=11]"

		_append_to_log "$logfile" "[$currfunc] [ERROR] We did not get any SCHEDDETAILS configuration item data. Please check the parameter file and confirm SCHEDDETAILS is not commented and does not contain spaces at the beginning of the line."
                _append_to_log "$logfile" "[$currfunc] [ERROR]"
                _append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                _append_to_log "$logfile" "[$currfunc] [ERROR]"
                _append_to_log "$logfile" "[$currfunc] Exiting with [RC=11]"
		exit 11
	fi

	# added by shn on 04092015
	if [ "$STRICTWINDOW" = "" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] We did not get any SCHEDDETAILS configuration item data. Please check the parameter file and confirm SCHEDDETAILS is not commented and does not contain spaces."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exiting with [RC=11]"

		_append_to_log "$logfile" "[$currfunc] [ERROR] We did not get any SCHEDDETAILS configuration item data. Please check the parameter file and confirm SCHEDDETAILS is not commented and does not contain spaces."
                _append_to_log "$logfile" "[$currfunc] [ERROR]"
                _append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                _append_to_log "$logfile" "[$currfunc] [ERROR]"
                _append_to_log "$logfile" "[$currfunc] Exiting with [RC=11]"
		exit 11
	fi

	# added by shn on 04092015
	if [ "$CONTACT" = "" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] We did not get any CONTACT configuration item data. Please check the parameter file and confirm SCHEDDETAILS is not commented and does not contain spaces."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exiting with [RC=11]"

		_append_to_log "$logfile" "[$currfunc] [ERROR] We did not get any CONTACT configuration item data. Please check the parameter file and confirm SCHEDDETAILS is not commented and does not contain spaces."
                _append_to_log "$logfile" "[$currfunc] [ERROR]"
                _append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                _append_to_log "$logfile" "[$currfunc] [ERROR]"
                _append_to_log "$logfile" "[$currfunc] Exiting with [RC=11]"
		exit 11
	fi

	# added by shn on 042215; creates a schedule, for example, named DAILY_1000 for a daily 10am backup

	OURDAILYINCREMENTAL=`echo DAILY_${PREFERREDSTARTTIME} | tr ":" " " | awk '{print $1 $2}'`
	if [ "$OURDAILYINCREMENTAL" = "" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] We did not get any CONTACT configuration item data. Please check the parameter file and confirm SCHEDDETAILS is not commented and does not contain spaces."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exiting with [RC=11]"

		_append_to_log "$logfile" "[$currfunc] [ERROR] We did not get any CONTACT configuration item data. Please check the parameter file and confirm SCHEDDETAILS is not commented and does not contain spaces."
                _append_to_log "$logfile" "[$currfunc] [ERROR]"
                _append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                _append_to_log "$logfile" "[$currfunc] [ERROR]"
                _append_to_log "$logfile" "[$currfunc] Exiting with [RC=11]"
		exit 11
	fi

        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Parsed values: CONTACT=$CONTACT, STARTTIME=$PREFERREDSTARTTIME, STRICTWINDOW=$STRICTWINDOW, LEEWAYBEFORE=$WINDOWLEEWAYBEFORE, LEEWAYAFTER=$WINDOWLEEWAYAFTER"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

get_linux_package_details() {
	local currfunc="get_linux_package_details"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	RPMLIST=`egrep '^RPMLIST' $parm_file`

	if [ $? -ne 0 ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Could not find a configuration for specifying the Linux RPMs."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exiting with [RC=11]"

                _append_to_log "$logfile" "[$currfunc] [ERROR] Could not find a configuration for specifying the Linux RPMs."
                _append_to_log "$logfile" "[$currfunc] [ERROR]"
                _append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                _append_to_log "$logfile" "[$currfunc] [ERROR]"
                _append_to_log "$logfile" "[$currfunc] Exiting with [RC=11]"
                exit 11
	fi

	# specify the internal field separator
	oIFS="$IFS"
	IFS=';' read -a LINUXPACKAGEARRAY <<< "$RPMLIST"

	# read in the values
	gskcryptpackage=${LINUXPACKAGEARRAY[1]}
	gsksslpackage=${LINUXPACKAGEARRAY[2]}
	TIVsmAPIpackage=${LINUXPACKAGEARRAY[3]}
	TIVsmBApackage=${LINUXPACKAGEARRAY[4]}
	TIVsmAPIversion=${LINUXPACKAGEARRAY[5]}
	TIVsmBAversion=${LINUXPACKAGEARRAY[6]}

	# get the version from each value
	gskcryptversion=`echo $gskcryptpackage | tr "-" ";" | tr "." ";" | cut -d ";" -f2-5 | tr -d ";"`
	gsksslversion=`echo $gsksslpackage | tr "-" ";" | tr "." ";" | cut -d ";" -f2-5 | tr -d ";"`

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Parsed values: gskcryptpackage=$gskcryptpackage, gsksslpackage=$gsksslpackage, TIVsmAPIpackage=$TIVsmAPIpackage, TIVsmBApackage=$TIVsmBApackage"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Parsed values: gskcryptversion=$gskcryptversion, gsksslversion=$gsksslversion, TIVsmAPIversion=$TIVsmAPIversion, TIVsmBAversion=$TIVsmBAversion"

	IFS="$oIFS"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

get_transfer_details() {
	local currfunc="get_transfer_details"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	USEKEYS=0
	ftpcount=`egrep '^FTPDETAILS' $parm_file | wc -l`

	if [ $ftpcount -gt 1 ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] There are too many FTPDETAILS configuration items uncommented. There can be only one."
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exiting with [RC=11]"

		_append_to_log "$logfile" "[$currfunc] [ERROR] There are too many FTPDETAILS configuration items uncommented. There can be only one."
		_append_to_log "$logfile" "[$currfunc] [ERROR]"
		_append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
		_append_to_log "$logfile" "[$currfunc] [ERROR]"
		_append_to_log "$logfile" "[$currfunc] Exiting with [RC=11]"

		exit 11
	fi

	FTPDETAILS=`egrep '^FTPDETAILS' $parm_file`

	if [ $? -ne 0 ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Could not find a configuration for downloading the software."
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exiting with [RC=11]"

		_append_to_log "$logfile" "[$currfunc] [ERROR] Could not find a configuration for downloading the software."
		_append_to_log "$logfile" "[$currfunc] [ERROR]"
		_append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
		_append_to_log "$logfile" "[$currfunc] [ERROR]"
		_append_to_log "$logfile" "[$currfunc] Exiting with [RC=11]"
		exit 11
	fi

	# specify the internal field separator
	oIFS="$IFS"
	IFS=';' read -a FTPARRAY <<< "$FTPDETAILS"

	FTPPROTOCOL=${FTPARRAY[1]}
	FTPHOST=${FTPARRAY[2]}
	FTPUSER=${FTPARRAY[3]}

	#if [ $INTERACTIVE -eq 1 ];
	#then
	#	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Prompting for the password."
	#	get_ftp_password
	#	FTPPASS=$promptValue
	#else
	#	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Using encryption to get the password."
		FTPPASS=${FTPARRAY[4]}
	#fi

	RELATIVEBASEDIR=${FTPARRAY[5]}
	RELATIVEOSDIR=${FTPARRAY[6]}
	CLIENTPACKAGE=${FTPARRAY[7]}
	REQUIREDSPACE=${FTPARRAY[8]}

	check_available_space "$REQUIREDSPACE"

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Parsed values: FTPPROTOCOL=$FTPPROTOCOL, FTPHOST=$FTPHOST, FTPUSER=$FTPUSER, RELATIVEBASEDIR=$RELATIVEBASEDIR, RELATIVEOSDIR=$RELATIVEOSDIR, CLIENTPACKAGE=$CLIENTPACKAGE."

	if [ "$FTPPASS" == "" ];
	then
		if [ "$FTPPROTOCOL" = "sftp" ];
		then
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] There is a blank password entry but the protocol is sftp. Assuming public keys are exchanged."
			_append_to_log "$logfile" "[$currfunc] There is a blank password entry but the protocol is sftp. Assuming public keys are exchanged."
			USEKEYS=1
		else
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] There is no password in the parameter file and the protocol is not sftp."
                	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
                	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exiting with [RC=4]"

i			_append_to_log "$logfile" "[$currfunc] [ERROR] There is no password in the parameter file and the protocol is not sftp."
                	_append_to_log "$logfile" "[$currfunc] [ERROR]"
                	_append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                	_append_to_log "$logfile" "[$currfunc] [ERROR]"
                	_append_to_log "$logfile" "[$currfunc] Exiting with [RC=4]"

			exit 4
		fi
	fi

	IFS="$oIFS"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

install() {
	local currfunc="install"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	get_linux_package_details
	check_linux_install

	if [ $rc -eq -1 ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Skipping client installation."
		_append_to_log "$logfile" "[$currfunc] Skipping client installation."
	else
		if [ $FTPPROTOCOL = "ftp" ];
		then
			update_netrc
		fi

		download_client_package
		install_linux_client
	fi

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

create_dsm_opt() {
	local currfunc="create_dsm_opt"
	local thisserver=$1

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Location for dsm.opt file is $dsmopt."

	if [ -f "$dsmopt" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Removing pre-existing dsm.opt file."
		rm $dsmopt
	fi

	_append_to_file "$dsmopt" "**************************************************"
	_append_to_file "$dsmopt" "* Tivoli Storage Manager client options file      "
	_append_to_file "$dsmopt" "**************************************************"
	_append_to_file "$dsmopt" "Servername $thisserver"
	_append_to_log "$logfile" "[$currfunc] Created $dsmopt file."

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

create_dsm_sys() {
	local currfunc="create_dsm_sys"
	local DEFAULTSET=0
	local TSMSERVERNAME=""
	local TSMNODENAME=""
	local TSMSERVERPORT=""
	local TSMPROTOCOL=""
	local TSMSERVERUSER=""
	local TSMSERVERPASS=""
	local DSMSYSEXISTS=0

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Location for dsm.sys file is $dsmsys."

	# modified by shn on 042115
	if [ -f "$dsmsys" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Found a pre-existing $dsmsys. We will only append servers that don't exists in the $dsmsys."
		_append_to_log "$logfile" "[$currfunc] Found a pre-existing $dsmsys. We will only append servers that don't exist in the $dsmsys."
		DSMSYSEXISTS=1
	fi

	# modified by shn on 042115
	if [ $DSMSYSEXISTS -eq 0 ];
	then
		_append_to_file "$dsmsys" "**************************************************"
		_append_to_file "$dsmsys" "* Tivoli Storage Manager client system options file"
		_append_to_file "$dsmsys" "**************************************************"
	fi

	tsmserverlist=(`egrep '^TSMSERVER' $parm_file`)

	for server in ${tsmserverlist[@]};
	do
		serverdetails=(`echo $server | sed 's/;/ /g'`)
		TSMSERVERNAME=${serverdetails[1]}
		TSMSERVERPORT=${serverdetails[2]}
		TSMPROTOCOL=${serverdetails[3]}
		TSMSERVERUSER=${serverdetails[4]}
		TSMSERVERPASS=${serverdetails[5]}

		#if [ "$DEFAULTSET" -eq 0 ];
		#then
		#	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Setting the default server, which defaults to the first in the list."
		#	_append_to_file "$dsmsys" "Defaultserver $TSMSERVERNAME"
		#	DEFAULTSET=1
		#fi

		# added by shn on 042115
		serverExists=`grep $TSMSERVERNAME $dsmsys`
		if [ $? -eq 0 ];
		then
			serveropt=$tsmbindir/$TSMSERVERNAME".opt"

			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] $TSMSERVERNAME already exists in the $dsmsys. Skipping."
			_append_to_log "$logfile" "[$currfunc] $TSMSERVERNAME already exists in the $dsmsys. Skipping."
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Creating opt file for server $TSMSERVERNAME -- filename is $serveropt"
			if [ ! -f "$serveropt" ];
			then
				_append_to_file "$serveropt" "**************************************************"
				_append_to_file "$serveropt" "* Tivoli Storage Manager client options file"
				_append_to_file "$serveropt" "**************************************************"
				_append_to_file "$serveropt" "Servername $TSMSERVERNAME"
				_append_to_log "$logfile" "[$currfunc] Created $serveropt file."
			fi

			continue
		fi

		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Adding details to dsm.sys file: TSMSERVERNAME=$TSMSERVERNAME, TSMSERVERPORT=$TSMSERVERPORT, TSMPROTOCOL=$TSMPROTOCOL"

		serveropt=$tsmbindir/$TSMSERVERNAME".opt"

		_append_to_file "$dsmsys" "* Begin server configuration"
		_append_to_file "$dsmsys" "Servername	$TSMSERVERNAME"
		_append_to_file "$dsmsys" "COMMMethod	$TSMPROTOCOL"
		_append_to_file "$dsmsys" "TCPPort	$TSMSERVERPORT"
		_append_to_file "$dsmsys" "TCPServeraddress	$TSMSERVERNAME"
		_append_to_file "$dsmsys" "Nodename	$nodename"
                _append_to_file "$dsmsys" "Schedmode    PROMPTED"
                _append_to_file "$dsmsys" "PASSWORDACCESS       GENERATE"
                _append_to_file "$dsmsys" "SCHEDLOGNAME $tsmbindir/dsmsched.log"
                _append_to_file "$dsmsys" "ERRORLOGNAME $tsmbindir/dsmerror.log"
                _append_to_file "$dsmsys" "INCLEXCL     $excludefile"
                _append_to_file "$dsmsys" "SCHEDLOGRETENTION 30 D"
                _append_to_file "$dsmsys" "ERRORLOGRETENTION 30 D"
                _append_to_file "$dsmsys" "DOMAIN       all-local"
		_append_to_file "$dsmsys" "* End server configuration"

		# Create a .opt file for each server where the name of the file is the name of the server appended with .opt.
		# Remove any pre-existing files
		if [ -f $serveropt ];
		then
			rm $serveropt
		fi

		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Creating opt file for server $server -- filename is $serveropt"
		_append_to_file "$serveropt" "**************************************************"
		_append_to_file "$serveropt" "* Tivoli Storage Manager client options file"
		_append_to_file "$serveropt" "**************************************************"
		_append_to_file "$serveropt" "Servername $TSMSERVERNAME"
		_append_to_log "$logfile" "[$currfunc] Created $serveropt file."
	done

	_append_to_log "$logfile" "[$currfunc] Created $dsmsys file."

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

# this consolidates our exceptions so we don't have to have the same lines of code in more than one location
# added by shn on 041715
catch_tsm_exception() {
	local currfunc="catch_tsm_exception"
	local exception=$1

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Function input is: $exception"

	rc=0

	# We're likely to run into more of these errors in the field and we may or may not know how to deal with them via the Knowledge Center, technotes, or other documentation.
	# Wouldn't code-level autocorrections be neat?
        case $exception in
		"ANS1033E An invalid TCP/IP address was specified.") # added by shn on 042015
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] ANS1033E An invalid TCP/IP address was specified."
                        _append_to_log "$logfile", "[$currfunc] ANS1033E An invalid TCP/IP address was specified."
                        rc="ANS1033E";;
		"ANS8023E Unable to establish session with server.")
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] ANS8023E Unable to establish session with server."
                        _append_to_log "$logfile", "[$currfunc] ANS8023E Unable to establish session with server."
			rc="ANS8023E";;
                "ANS1017E Session rejected: TCP/IP connection failure.")
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] ANS1017E Session rejected: TCP/IP connection failure"
                        _append_to_log "$logfile", "[$currfunc] ANS1017E Session rejected: TCP/IP connection failure"
                        rc="ANS1017E";;
                "ANS8034E Your administrator ID is not recognized by this server.")
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] ANS8034E Your administrator ID is not recognized by this server."
                        _append_to_log "$logfile", "[$currfunc] ANS8034E Your administrator ID is not recognized by this server."
                        rc="ANS8034E";;
                "ANR2034E SELECT: No match found using this criteria.")
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] ANR2034E SELECT: No match found using this criteria."
                        _append_to_log "$logfile", "[$currfunc] ANR2034E SELECT: No match found using this criteria."
                        rc="ANR2034E";;
        esac

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

query_domains_by_platform_name() {
	local currfunc="query_domains_by_platform_name"
	local adminuser=$1
	local adminpass=$2
	local servername=$3
	local nodelist="${tmpdir}/${servername}_nodelist.txt"
	local TOTALNODECOUNT=""

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	# remove the file if it exists so we don't create duplicates after failed runs
	if [ -f "$nodelist" ];
	then
		rm $nodelist
	fi

	# specify the internal field separator
	oIFS="$IFS"
	IFS=$'\n'

	# This gets a list of the policies with the node counts by platform type
	# This assumes ostype is always going to match all forms in the TSM DB.
	# Welcome to APAR city
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] TSM QUERY= \"select num_nodes,domain_name from domains where domain_name in (select domain_name from nodes where platform_name like '%$ostype%')\""
	for RESULT in `dsmadmc -dataonly=yes -commadelimited -id=$adminuser -password=$adminpass "select num_nodes,domain_name from domains where domain_name in (select domain_name from nodes where platform_name like '%$ostype%')"`
	do
		local PDNAME=""
		local NODECOUNT=""

		# added by shn on 041715
		catch_tsm_exception "$RESULT"
		if [ "$rc" != "0" ];
		then
			break
		fi

		IFS=',' read -a RESULTS <<< "$RESULT"
		PDNAME=${RESULTS[1]}
		NODECOUNT=${RESULTS[0]}
		TOTALNODECOUNT=`expr $TOTALNODECOUNT + $NODECOUNT`

		_append_to_file "$nodelist" "$NODECOUNT $PDNAME" # modified by shn on 042115
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Parsed values: PDNAME=$PDNAME, NODECOUNT=$NODECOUNT, TOTALNODECOUNT=$TOTALNODECOUNT"
	done


	IFS="$oIFS"
	_append_to_log "$logfile" "[$currfunc] Final nodecount is $TOTALNODECOUNT"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Final nodecount is $TOTALNODECOUNT"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

query_client_schedules() {
	local currfunc="query_client_schedules"
	local adminuser=$1
	local adminpass=$2
	local servername=$3
	local schedlist="${tmpdir}/${servername}_schedlist.txt"
	local PDNAME=""
	local SCHEDNAME=""
	local ACTION=""
	local PRIORITY=""
	local STARTDATETIME=""
	local DURATION=""
	local PERIOD=""
	local DAYOFWEEK=""
	local MONTH=""
	local DAYOFMONTH=""
	local WEEKOFMONTH=""

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	# remove the file if it exists so we don't create duplicates after failed runs
	if [ -f "$schedlist" ];
	then
		rm $schedlist
	fi

	# specify the internal field separator
        oIFS="$IFS"
	IFS=$'\n'

	        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] TSM QUERY=select starttime,domain_name,schedule_name from client_schedules where domain_name in (select domain_name from nodes where platform_name like '%$ostype%' and action='INCREMENTAL')"
        _append_to_log "$logfile" "[$currfunc] TSM QUERY=select starttime,domain_name,schedule_name from client_schedules where domain_name in (select domain_name from nodes where platform_name like '%$ostype%' and action='INCREMENTAL')"

        # Get a list of all schedules by domain_name for the node's platform
	for SCHED in `dsmadmc -dataonly=yes -commadelimited -id=$adminuser -password=$adminpass "select starttime,domain_name,schedule_name from client_schedules where domain_name in (select domain_name from nodes where platform_name like '%$ostype%') and action='INCREMENTAL'"`;
	do
		# added by shn on 041715
		catch_tsm_exception "$SCHED"
		if [ "$rc" != "0" ];
		then
			break
		fi

                IFS=$',' read -a SCHEDDETAILS <<< "$SCHED"
		STARTTIME=${SCHEDDETAILS[0]}
		PDNAME=${SCHEDDETAILS[1]}
		SCHEDNAME=${SCHEDDETAILS[2]}

		_append_to_file "$schedlist" "$SCHED"
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Parsed values: PDNAME=$PDNAME, SCHEDNAME=$SCHEDNAME, ACTION=$ACTION, STARTTIME=$STARTTIME"
	done

	IFS="$oIFS"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

query_association() {
	local currfunc="query_association"
	local adminuser=$1
	local adminpass=$2
	local servername=$3
	local assoclist="${tmpdir}/${servername}_assoclist.txt"
	local PDNAME=""
	local SCHEDNAME=""
	local NODENAME=""

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	# remove the file if it exists so we don't create duplicates after failed runs
	if [ -f "$assoclist" ];
	then
		rm $assoclist
	fi

	# specify the internal field separator
	oIFS="$IFS"
	IFS=$'\n'

        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] TSM QUERY=select domain_name,schedule_name,node_name from associations where domain_name in (select domain_name from nodes where platform_name like '%$ostype%')"
        _append_to_log "$logfile" "[$currfunc] TSM QUERY=select domain_name,schedule_name,node_name from associations where domain_name in (select domain_name from nodes where platform_name like '%$ostype%')"

	for ASSOCIATION in `dsmadmc -dataonly=yes -commadelimited -id=$adminuser -password=$adminpass "select domain_name,schedule_name,node_name from associations where domain_name in (select domain_name from nodes where platform_name like '%$ostype%')"`;
	do
		# added by shn on 041715
		catch_tsm_exception "$ASSOCIATION"
		if [ "$rc" != "0" ];
		then
			break
		fi

                IFS=$',' read -a ASSOCIATIONDETAILS  <<< "$ASSOCIATION"
		PDNAME=${ASSOCIATIONDETAILS[0]}
		SCHEDNAME=${ASSOCIATIONDETAILS[1]}
		NODENAME=${ASSOCIATIONDETAILS[2]}

		_append_to_file "$assoclist" "$ASSOCIATION"
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Parsed values: PDNAME=$PDNAME, SCHEDNAME=$SCHEDNAME, NODENAME=$NODENAME"
	done

	IFS="$oIFS"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

query_db() {
	local currfunc="query_db"
	local adminuser=$1
	local adminpass=$2
	local servername=$3
	local dblist="${tmpdir}/${servername}_dblist.txt"
	local DBNAME=""
	local TOTALPAGES=""
	local USABLEPAGES=""
	local USEDPAGED=""
	local FREEPAGES=""

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	# remove the file if it exists; we don't want to create duplicate values
	if [ -f $dblist ];
	then
		rm $dblist
	fi

	# specify the internal field separator
        oIFS="$IFS"
	IFS=$'\n'

        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Writing output to temporary file $dblist"
        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] TSM QUERY=\"select free_space_mb,database_name from db order by 2\""
        _append_to_log "$logfile" "[$currfunc] TSM QUERY=select free_space_mb,database_name from db order by 2"

	for DB in `dsmadmc -dataonly=yes -tabdelimited -id=$adminuser -password=$adminpass "select free_space_mb,database_name from db order by 2"`
	do
		# added by shn on 041715
		catch_tsm_exception "$DB"
		if [ "$rc" != "0" ];
		then
			break
		fi

                IFS=$'\t' read -a DBDETAILS <<< "$DB"
                DBNAME=${DBDETAILS[1]}
		FREESPCMB=${DBDETAILS[0]}

		_append_to_file "$dblist" "$DB"
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Parsed values: DBNAME=$DBNAME, FREESPCMB=$FREESPCMB"
	done

	IFS="$oIFS"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

choose_db() {
	local currfunc="choose_db"
	local dblist="$tmpdir/dblist.txt"
	local filename=""
	local servername=""
	local line=""

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	# remove the file if it exists so we don't create duplicates after a failed run.
	if [ -f $dblist ];
	then
		rm $dblist
	fi

	oIFS="$IFS"

	for dbfile in `ls -ltr $tmpdir/*_dblist.txt | awk '{print $9}'`;
	do
		filename=`basename $dbfile`
		servername=`echo $filename | cut -d"_" -f1`
		lowwatermark=`grep TSMSERVER $parm_file | grep $servername | cut -d";" -f8` # updated by shn on 042015 for addition of preferred config opt
		IFS=$'\n'

		for db in `cat $dbfile`;
		do
                        dbname=`echo $db | awk '{print $2}'`
                        freespacemb=`echo $db | awk '{print $1}'`
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] DBNAME=$dbname, FREESPACEMB=$freespacemb"

                        # we want to avoid registering with a server which somehow became too low on space to be added to the list
                        #if [ $freespacemb -gt $lowwatermark ];
                        #then
                                line="$db ${servername}"
                                echo $line >> $dblist

                                if [ $? -eq 0 ];
                                then
                                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Concatenated $line to $dblist"
                                else
                                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Failed to append to $dblist"
                                fi
                        #else
                        #        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Skipping DB $dbname. The free space in MB, $freespacemb, is less than the low-water mark of $lowwatermark."
                        #        _append_to_log "$logfile" "[$currfunc] Skipping DB $dbname. The free space in MB, $freespacemb, is less than the low-water mark of $lowwatermark."
                        #fi
		done
	done

        if [ ! -f "$dblist" ];
        then
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] We may have skipped all databases due to the low-water mark. $dblist is missing!"
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function and script."
                _append_to_log "$logfile" "[$currfunc] We may have skipped all databases due to the low-water mark. $dblist is missing!"
                _append_to_log "$logfile" "[$currfunc] Exited function and script."
                #exit
        else
                ourdbserver=`sort -nr $dblist | head -1 | awk '{print $3}'`
                ourdb=`sort -nr $dblist | head -1 | awk '{print $2}'`
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Our DB is $ourdb on server $ourdbserver"
                _append_to_log "$logfile" "[$currfunc] Our DB is $ourdb on server $ourdbserver"
        fi

	IFS="$oIFS"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

choose_policy_domain() {
	local currfunc="choose_policy_domain"
	local nodelist="$tmpdir/nodelist.txt"
	local filename=""
	local servername=""
	local line=""

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	# remove the file if it exists so we don't create duplicates after a failed run.
	if [ -f $nodelist ];
	then
		rm $nodelist
	fi

	oIFS="$IFS"

	ls $tmpdir/*_nodelist.txt | while read nodefile
	do
		filename=`basename $nodefile`
		servername=`echo $filename | cut -d"_" -f1`
		IFS=$'\n'

		cat $nodefile | while read policydomain
		do
			line="$policydomain $servername"
			echo $line >> $nodelist

			if [ $? -eq 0 ];
			then
				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Concatenated $line to $nodelist"
				continue
			else
				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Failed to append to $nodelist"
			fi
		done
	done

        ourpdserver=`sort -n $nodelist | head -1 | awk '{print $3}'`
        ourpd=`sort -n $nodelist | head -1 | awk '{print $2}'`
        nodecount=`sort -n $nodelist | head -1 | awk '{print $1}'`
        dbnodecount=`sort -n $tmpdir/${ourdbserver}_nodelist.txt | head -1 | awk '{print $1}'` # added by shn on 042015
        dbpd=`sort -n $tmpdir/${ourdbserver}_nodelist.txt | head -1 | awk '{print $2}'` # added by shn on 042015

        if [ "$ourdbserver" != "$ourpdserver" ];
        then
                # added by shn on 042015
                if [ "$dbnodecount" = "$nodecount" ];
                then
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Our DB server, $ourdbserver, has the same node count as $ourpdserver."
                        _append_to_log "$logfile" "[$currfunc] Our DB server, $ourdbserver, has the same node count as $ourpdserver."
                        OURSERVER=$ourdbserver
                        pdname=$dbpd
                fi

                if [ $dbnodecount -gt $nodecount ];
                then
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Our DB server, $ourdbserver, has the least space used but more active nodes than $ourpdserver"
                        OURSERVER=$ourpdserver
                        pdname=$ourpd
                        _append_to_log "$logfile" "[$currfunc] Our DB server, $ourdbserver, has the least space used but more active nodes than $ourpdserver"
                fi
        else
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Our DB server also has the fewest nodes."
		_append_to_log "$logfile" "[$currfunc] Our DB server also has the fewest nodes."
                nodecount=`sort -n $tmpdir/${ourpdserver}_nodelist.txt | head -1 | awk '{print $1}'`
                OURSERVER=$ourdbserver
                pdname=`sort -n $tmpdir/${ourpdserver}_nodelist.txt | head -1 | awk '{print $2}'`
        fi

        IFS="$oIFS"
        OURPD="$pdname"
        _append_to_log "$logfile" "[$currfunc] Our PD is $OURPD on server $OURSERVER with nodecount $nodecount"

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Our PD is $pdname on server $ourserver with nodecount $nodecount"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

choose_schedule() {
        local currfunc="choose_schedule"
        local servername=$1
	local pdname=$2
        local schedfile=$tmpdir/schedlist.txt
        local schedcount=0
        local action=""
        local nodecount=0
        local starttime=""
        local line=""
        local matchingschedules=0
        local useleeway=0
        local oursched=""
        preferredstarthour=`echo $PREFERREDSTARTTIME | cut -d ":" -f1`
        preferredstartminute=`echo $PREFERREDSTARTTIME | cut -d ":" -f2`

        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

        if [ -f $schedfile ];
        then
                rm $schedfile
        fi

        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Our server is $servername, our preferred window is $PREFERREDSTARTTIME, with before leeway of $WINDOWLEEWAYBEFORE, and after of $WINDOWLEEWAYAFTER"
        _append_to_log "$logfile" "[$currfunc] Our server is $servername, our preferred window is $PREFERREDSTARTTIME, with before leeway of $WINDOWLEEWAYBEFORE, and after of $WINDOWLEEWAYAFTER"
        matchingschedules=`grep $PREFERREDSTARTTIME $tmpdir/${servername}_schedlist.txt | wc -l`

        if [ $matchingschedules -eq 0 ];
        then
		if [ $STRICTWINDOW = "no" ];
		then
                	useleeway=1
		fi
        fi

        cat $tmpdir/${servername}_schedlist.txt | cut -d "," -f1- | tr "," " " | while read schedule
        do
                schedname=`echo $schedule | awk '{print $3}'`
		policy=`echo $schedule | awk '{print $2}'`
                starttime=`echo $schedule | awk '{print $1}'`
                starthour=`echo $starttime | cut -d ":" -f1`
                startminute=`echo $starttime | cut -d ":" -f2`

		if [ "$policy" != "$pdname" ];
		then
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Schedule is in $policy does not match our policy domain, $pdname. Skipping."
			continue
		fi

                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Schedule details are: SCHEDNAME=$schedname, ACTION=$action, STARTTIME=$starttime"

                if [ $useleeway -eq 1 ]
                then
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Schedule $schedname does not match our preferred start time of $PREFERREDSTARTTIME -- using leeway"
                        _append_to_log "$logfile" "[$currfunc] Schedule $schedname does not match our preferred start time of $PREFERREDSTARTTIME -- using leeway"

                        if [ "$preferredstarthour" -gt "$starthour" ];
                        then
                                difference=`expr $preferredstarthour - $starthour`
                                canadd=`expr $difference \>= $WINDOWLEEWAYBEFORE`

                                if [ $canadd -eq 1 ];
                                then
                                        nodecount=`grep $schedname $tmpdir/${servername}_assoclist.txt | wc -l`
                                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Node count for schedule $schedname is $nodecount"
                                        _append_to_file $schedfile "$starthour	$schedname	$nodecount"
                                fi
                        fi

                        if [ "$preferredstarthour" -lt "$starthour" ];
                        then
                                difference=`expr $starthour - $preferredstarthour`
                                canadd=`expr $difference \<= $WINDOWLEEWAYAFTER`

                                if [ $canadd -eq 1 ];
                                then
                                        nodecount=`grep $schedname $tmpdir/${servername}_assoclist.txt | wc -l`
                                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Node count for schedule $schedname is $nodecount"
                                        _append_to_file $schedfile "$starthour	$schedname	$nodecount"
                                fi
                        fi

			if [ "$preferredstarthour" -eq "$starthour" ];
			then
				[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Schedule $schedname matches our start hour."
                                nodecount=`grep $schedname $tmpdir/${servername}_assoclist.txt | wc -l`
                                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Node count for schedule $schedname is $nodecount"
                                _append_to_file $schedfile "$starthour	$schedname	$nodecount"
			fi
                else
                        if [ "$starttime" = "$PREFERREDSTARTTIME" ];
                        then
				[ $DEBUG -eq 1 ] & _print_to_stdout "[$currfunc] Schedule $schedname matches $PREFERREDSTARTTIME"
                                nodecount=`grep $schedname $tmpdir/${servername}_assoclist.txt | wc -l`
                                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Node count for schedule $schedname is $nodecount"
                                _append_to_file $schedfile "$starthour	$schedname	$nodecount"
                        fi
                fi
        done

        if [ ! -f $schedfile ];
        then
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] No $schedfile exists!"

                if [ "$STRICTWINDOW" = "yes" ];
                then
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] No schedules match our preferred window and our window is strict."
                else
			# modified by shn on 042015
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] No schedules match our preferred window even with leeway!"
                        _append_to_log "$logfile" "[$currfunc] No schedules match our preferred window even with leeway!"
                fi
        else
                if [ $useleeway -eq 1 ];
                then
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] We need to pick a schedule nearest to our preferred start hour of $preferredstarthour!"
                        find_closest_value "$preferredstarthour"
                        oursched=$OURSCHED
			thisnodecount=`grep $oursched $schedfile | head -1 | awk '{print $3'}` # added by shn on 042015
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Our preferred schedule is $oursched with nodecount $thisnodecount"
                        _append_to_log "$logfile" "[$currfunc] Our preferred schedule is $oursched with nodecount $thisnodecount"
                else
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Sorting our schedules..."
                        oursched=`sort -n $schedfile | head -1 | awk '{print $2}'`
			thisnodecount=`sort -n $schedfile | head -1 | awk '{print $3}'` # added by shn on 042015
                        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Our preferred schedule is $oursched with nodecount $thisnodecount"
                        _append_to_log "$logfile" "[$currfunc] Our preferred schedule is $oursched with nodecount $thisnodecount"
                fi
        fi

        OURSCHED=$oursched

        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

# this matches the closest schedule
find_closest_value() {
	local currfunc="find_closest_value"
        local targetvalue=$1
        local schedfile=$tmpdir/schedlist.txt
	local VALUES=""
        local ARRAY=""
	local SCHEDULES=""
	local SCHEDARRAY=""
        local closest=""
        local prev=""
	local thissched=""
	local index=0

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	if [ ! -f "$schedfile" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] The $schedfile is missing. We couldn't find any matching schedules."
		append_to_log "$logfile" "[$currfunc] The $schedfile is missing. We couldn't find any matching schedules."
		OURSCHED=""
		return
	fi

	VALUES=`cat $schedfile | awk '{print $1}'`
	SCHEDULES=`cat $schedfile | awk '{print $2}'`
        read -a ARRAY <<< $VALUES
	read -a SCHEDARRAY <<< $SCHEDULES
        closest=${ARRAY[0]}
        prev=`expr $closest - $targetvalue`
        prev=`echo $prev | tr -d -`

        for STARTTIME in ${ARRAY[@]};
        do
                local HOUR=`echo $STARTTIME | cut -d ":" -f1`
                local diff=`expr $HOUR - $targetvalue`
                diff=`echo $diff | tr -d -` # this turns it into an absolute value
                result=`expr $diff \< $prev`

                if [ "$result" = "1" ];
                then
                        prev=$diff
                        closest=$HOUR
			thissched=$index
                fi

		index=`expr $index + 1`
        done

	OURSCHED=${SCHEDARRAY[$thissched]}
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] OURSCHED=$OURSCHED"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

register_and_associate_client() {
        local currfunc="register_and_associate_client"
        local adminuser=$1
        local adminpass=$2
        local registercmd="dsmadmc -id=sauser -password=b2rc3l0nafc register node $nodename $nodePassword userid=none contact=$CONTACT domain=$OURPD"
        local associatecmd="dsmadmc -id=sauser -password=b2rc3l0nafc define association $OURPD $OURSCHED $nodename"

		#local registercmd="dsmadmc -id=$adminuser -password=$adminpass register node $nodename $nodePassword userid=none contact=$CONTACT domain=$OURPD"
        #local associatecmd="dsmadmc -id=$adminuser -password=$adminpass define association $OURPD $OURSCHED $nodename"
        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

        output=`$registercmd`

        if [ $? -ne 0 ];
        then
                [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Register command failed: $output"
                _append_to_log "$logfile" "[$currfunc] Register command failed: $output"
                rc=-1
        fi

	if [ "$OURSCHED" != "" ];
	then
		output=`$associatecmd`

		if [ $? -ne 0 ];
		then
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Associate command failed: $output"
			_append_to_log "$logfile" "[$currfunc] Associate command failed: $output"
			rc=-1
		fi
	else
		# whole block modified by shn on 042115
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] The schedule is undefined so we will create it."
		_append_to_log "$logfile" "[$currfunc] The schedule is undefined so we will create it."

		# Added by shn on 042215
		schedExists=`grep $OURPD $tmpdir/${OURSERVER}_schedlist.txt | grep $OURDAILYINCREMENTAL`
		if [ $? -eq 1 ];
		then
			create_daily_schedule "$adminuser" "$adminpass" "$OURPD"
		fi

		associatecmd="dsmadmc -id=$adminuser -password=$adminpass define association $OURPD $OURDAILYINCREMENTAL $nodename"
		output=`$associatecmd`

		if [ $? -ne 0 ];
		then
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Associate command failed: $output"
			_append_to_log "$logfile" "[$currfunc] Associate command failed: $output"
			rc=-1
		fi
	fi

        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

configure_linux() {
	local currfunc="configure_linux"
	local servername=""
	local adminuser=""
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	# Set the default location for the dsm.opt and dsm.sys files
	dsmopt=/opt/tivoli/tsm/client/ba/bin/dsm.opt
	dsmsys=/opt/tivoli/tsm/client/ba/bin/dsm.sys

	if [ -f "$dsmsys" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Removing pre-existing dsm.sys file."
		rm $dsmsys
	fi

	if [ -f "$dsmopt" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Removing pre-existing dsm.opt file."
		rm $dsmopt
	fi

	# The dsm.sys file contains all server definitions
	create_dsm_sys

        for optfile in `ls -ltr $tsmbindir/*.opt | grep -v dsmvddk | awk '{print $9}'`;
        do
                servername=`grep Servername $optfile | awk '{print $2}'`

		# added by shn on 042015
		# skips .opt files not defined in the parameter file
		local isServerInParam=`egrep '^TSMSERVER;$servername' $parm_file`
		if [ $? -eq 1 ];
		then
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Skipping opt file $optfile due to it not being in the parameter file"
			_append_to_log "$logfile" "[$currfunc] Skipping opt file $optfile due to it not being in the parameter file"
			continue
		fi

                adminuser=`egrep '^TSMSERVER' $parm_file | grep $servername | tr ";" " " | awk '{print $5}'` # modified by shn on 042115
		get_admin_password "$servername" # added by shn on 041615
		adminpass=$MYSERVERPASSWORD # added by shn on 041615
                rc=""

		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Connecting to server $servername with opt file $optfile, adminuser=$adminuser"
		_append_to_log "$logfile" "[$currfunc] Connecting to server $servername with opt file $optfile, adminuser=$adminuser"

		# copy the server-specific opt file to dsm.opt
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Copying $optfile to ${tsmbindir}/dsm.opt"
		cpresult=`cp $optfile ${tsmbindir}/dsm.opt`

		# added by shn on 04092015
		if [ $? -ne 0 ];
		then
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Could not copy opt file. result=$cpresult."
                	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
              		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
       	        	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exiting with [RC=11]"

			_append_to_log "$logfile" "[$currfunc] [ERROR] Could not copy opt file. result=$cpresult."
                	_append_to_log "$logfile" "[$currfunc] [ERROR]"
                	_append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
                	_append_to_log "$logfile" "[$currfunc] [ERROR]"
                	_append_to_log "$logfile" "[$currfunc] Exiting with [RC=11]"

			exit 11
		fi

                query_db "$adminuser" "$adminpass" "$servername"

                # Save run time and skip the rest since this server is unreachable.
                if [ "$rc" = "ANS1017E" ];
                then
                        continue
                fi

                query_domains_by_platform_name "$adminuser" "$adminpass" "$servername"
                query_client_schedules "$adminuser" "$adminpass" "$servername"
                query_association "$adminuser" "$adminpass" "$servername"
        done

        # Here we determine which server we'll register with
        choose_db

	# added by shn on 042015 for preferred config opt
	if [ $USEPREFERRED -eq 1 ];
	then
		choose_policy_domain
		get_preferred_schedule
		get_preferred_policydomain
	else
		choose_policy_domain
		choose_schedule $OURSERVER $OURPD
	fi

        # The dsm.opt file contains the primary server
        create_dsm_opt $OURSERVER

        adminuser=`egrep TSMSERVER $basedir/$parm_file | grep $OURSERVER | tr ";" " " | awk '{print $5}'`
	get_admin_password "$servername" # added by shn on 041615
	adminpass=$MYSERVERPASSWORD # added by shn on 041615

        # Register the node
        register_and_associate_client "$adminuser" "$adminpass"

        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

configure() {
	local currfunc="configure"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	rc=0
	create_exclude_list
	configure_linux

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

# added by shn on 04092015
start_scheduler_service() {
        local currfunc="start_scheduler_service"
        local servername=`grep Servername $dsmopt | awk '{print $2}'`
        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	# added by shn on 041615
	dsmcProcessList=`ps -eaf | grep dsmc | grep schedule | awk '{print $2}'`
	for dsmcProcess in ${dsmcProcessList[@]};
	do
		_append_to_log "$logfile" "[$currfunc] Found an existing scheduler service running. Killing PID $dsmcProcess"
		kill -9 $dsmcProcess
	done

	get_admin_password "$servername"
	adminpass=$MYSERVERPASSWORD

        /usr/bin/expect -c "
        spawn dsmc schedule
        expect {
                -re \"Please enter your user id\" { send \"\r\" }
        }
        expect {
                -re \"Please enter password\" { send \"$nodePassword\r\" }
        }
        expect \"Waiting to be contacted by the server\"
        send \003
        send \"\r\"
        interact "

        [ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

get_ftp_password() {
	local currfunc="get_ftp_password"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	echo "Please input the password for the ftp user. If public keys are exchanged, just hit enter."
	stty -echo
	read promptValue
	stty echo

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

get_node_password() {
	local currfunc="get_node_password"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	#echo "Please input the node password."
	#stty -echo
	#read nodePassword
	#stty echo

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

get_tsmserver_credentials() {
	local currfunc="get_tsmserver_credentails"
	local promptValue="b2rc3l0nafc"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."
        tsmserverlist=`egrep '^TSMSERVER' $parm_file`

        for server in ${tsmserverlist[@]};
	do
		local serverName=`echo $server | cut -d ";" -f2`
		local serverAdmin=`echo $server | cut -d ";" -f5`

		#echo "Please input the password for $serverAdmin on $serverName"
		#stty -echo
		#read promptValue

		if [ "$SERVERCREDENTIALS" = "" ];
		then
			SERVERCREDENTIALS="${serverName};${promptValue}"
			continue
		fi

		SERVERCREDENTIALS="${SERVERCREDENTIALS}:${serverName};${promptValue}"
	done

	stty echo
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

get_admin_password() {
	local currfunc="get_admin_password"
	local serverName=$1
	local serverFound=0
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	tsmserverlist=`echo $SERVERCREDENTIALS | tr ":" " "`
	for server in ${tsmserverlist[@]};
	do
		local thisServer=`echo $server | tr ";" " " | awk '{print $1}'`
		local thisPassword=`echo $server | tr ";" " " | awk '{print $2}'`

		if [ "$thisServer" = "$serverName" ];
		then
			serverFound=1
			MYSERVERPASSWORD=$thisPassword
			[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Returning server password for ${serverName}."
			break
		fi
	done

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

# Currently we only check available space for PWD since geninstall will automatically expand /usr
# added by shn on 042015
check_available_space() {
	local currfunc="check_available_space"
	local availableSpacePWD=`df -k $PWD | grep -v Filesystem | awk '{print $4}'`
	local requiredSpacePWD=$1

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	if [ $requiredSpacePWD -gt $availableSpacePWD ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Available space in $PWD is $availableSpacePWD; required space for download is $requiredSpacePWD."
               	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
              	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
               	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
       	       	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exiting with [RC=11]"

		_append_to_log "$logfile" "[$currfunc] [ERROR] Available space in $PWD is $availableSpacePWD; required space for download is $requiredSpacePWD."
               	_append_to_log "$logfile" "[$currfunc] [ERROR]"
               	_append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
               	_append_to_log "$logfile" "[$currfunc] [ERROR]"
               	_append_to_log "$logfile" "[$currfunc] Exiting with [RC=11]"

		exit 11
	fi

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

# added by shn on 042015
get_preferred_schedule() {
	local currfunc="get_preferred_schedule"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	if [ "$OURSERVER" = "" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] The TSM server has not been chosen or is unset for an undetermined reason."
               	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
              	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
               	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
       	       	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exiting with [RC=11]"

		_append_to_log "$logfile" "[$currfunc] [ERROR] The TSM server has not been chosen or is unset for an undetermined reason."
               	_append_to_log "$logfile" "[$currfunc] [ERROR]"
               	_append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
               	_append_to_log "$logfile" "[$currfunc] [ERROR]"
               	_append_to_log "$logfile" "[$currfunc] Exiting with [RC=11]"

		exit 11
	fi

	OURSCHED=`egrep '^TSMSERVER' $parm_file | grep $OURSERVER | cut -d";" -f7`

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] The preferred schedule in the parameter file is $OURSCHED"
	_append_to_log "$logfile" "[$currfunc] The preferred schedule in the parameter file is $OURSCHED"

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

# added by shn on 042015
get_preferred_policydomain() {
	local currfunc="get_preferred_policydomain"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	if [ "$OURSERVER" = "" ];
	then
		[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] The TSM server has not been chosen or is unset for an undetermined reason."
               	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
              	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR] Human intervention is required to correct the problem."
               	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] [ERROR]"
       	       	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exiting with [RC=11]"

		_append_to_log "$logfile" "[$currfunc] [ERROR] The TSM server has not been chosen or is unset for an undetermined reason."
               	_append_to_log "$logfile" "[$currfunc] [ERROR]"
               	_append_to_log "$logfile" "[$currfunc] [ERROR] Human intervention is required to correct the problem."
               	_append_to_log "$logfile" "[$currfunc] [ERROR]"
               	_append_to_log "$logfile" "[$currfunc] Exiting with [RC=11]"

		exit 11
	fi

	OURPD=`egrep '^TSMSERVER' $parm_file | grep $OURSERVER | cut -d";" -f6`

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] The preferred policy domain in the parameter file is $OURPD"
	_append_to_log "$logfile" "[$currfunc] The preferred policy domain in the parameter file is $OURPD"

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

# completed by shn on 042215 but this is unfinished due to uncertain requirements.
create_daily_schedule() {
	local currfunc="create_daily_schedule"
	local adminuser=$1
	local adminpass=$2
	local policydomain=$3
	local startTime=`echo $PREFERREDSTARTTIME | tr ":" " " | awk '{print $1 $2}'`
	local schedname="DAILY_${startTime}"
	local definecmd="dsmadmc -id=$adminuser -password=$adminpass define schedule $policydomain $schedname desc=\"Daily Incremental Backup\" action=incremental startd=today startt=$PREFERREDSTARTTIME"
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."
	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Creating new schedule in Policy Domain $OURPD named $schedname with start time of $PREFERREDSTARTTIME"
	_append_to_log "$logfile" "[$currfunc] Creating new schedule in Policy Domain $OURPD named $schedname with start time of $PREFERREDSTARTTIME"

	cmdresult=`$definecmd`
	catch_tsm_exception "$cmdresult"

	[ $DEBUG -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

# Invoke all the work here
setup

if [ "$operation" = "--install-and-configure" ];
then
        install
fi

configure
rc=0

# Log nicely and exit.
currfunc="main"
cd /tmp

inittablistings=`grep "TSM scheduler" /etc/inittab`
if [ $? -ne 0 ];
then
	_append_to_log "$logfile" "[$currfunc] Added inittab entry."
	_append_to_file "/etc/inittab" "itsm:2:once:/usr/bin/dsmc sched > /dev/null 2>&1 # TSM scheduler" # added by shn on 04092015
else
	_append_to_log "$logfile" "[$currfunc] The inittab entry already exists."
fi

#start_scheduler_service # added by shn on 04092015
nohup dsmc schedule 2>/dev/null &

if [ "$rc" -eq 0 ];
then
	_append_to_log "$logfile" "[$currfunc] dsmc schedule daemon started successfully. Check /tmp/nohup.out for details."
	_append_to_log "$logfile" "[$currfunc] Exiting script with [RC=0]."
	exit 0
else
	_append_to_log "$logfile" "[$currfunc] [ERROR] Exiting script with [RC=$rc]."
	exit $rc
fi
