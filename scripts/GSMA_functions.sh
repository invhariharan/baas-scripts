#!/bin/sh

scriptname=`basename $0`
cmd_awk=`which awk`

_print_to_stdout() {
	local entry=$1
	local date=`date  +'%m/%d/%Y %H:%M:%S'`
	echo "[$date] [$$] : $entry"
}

_local_script_parm_file_name() {
	local currfunc="_local_script_parm_file_name"
	local string=`echo 'local'$scriptname | cut -f1 -d"."`".param"
	echo $string
}

_script_parm_file_name() {
	local currfunc="_script_parm_file_name"
	local string=`echo $scriptname | cut -f1 -d"."`".param"
	echo $string
}

_append_to_file() {
	local currfunc="_append_to_file"
	local logfile=$1
	local entry=$2
	echo "$entry" >> $logfile
}

_append_to_log() {
	local currfunc="_append_to_log"
	local logfile=$1
	local entry=$2
	local date=`date +'%m/%d/%Y %H:%M:%S'`
	echo "[$date] [$$] : $entry" >> $logfile
}

_get_os_type() {
        local currfunc="get_os_type"
	[ "$DEBUG" -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."
        ostype=`uname`
	[ "$DEBUG" -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
        return
}

_set_path() {
	local currfunc="_set_path"
	[ "$DEBUG" -eq 1 ] && _print_to_stdout "[$currfunc] Entered function."

	if [ ! -e "$cmd_awk" ];
	then
		exit 1
	fi

	if [ -z ${HOME} ]; 
	then
		[ "$DEBUG" -eq 1 ] && _print_to_stdout "[$currfunc] The HOME variable isn't set."
		exit 1
	fi
	
	[ "$DEBUG" -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}

_get_script_parameter() {
	local $parameter=$1
	local index=$2
	$XTRACE && set -x
	echo "$parameter" | cut -f$1 -d";" | $cmd_awk '{sub(/^[ \t]+/,""); sub(/[ \t]+$/,""); print $index;}'
}

_extract_archive() {
	local currfunc="_extract_archive"
	_print_to_stdout "[$currfunc] Entered function."
	absolutepath=$1
	filename=`basename $absolutepath`
	extension=`echo $filename | sed 's/^.*\.//'`

	if [ $extension = "Z" ];
	then
		[ "$DEBUG" -eq 1 ] && _print_to_stdout "[$currfunc] uncompress $absolutepath"
		uncompress -f $absolutepath 2>&1
		newabpath=`echo $absolutepath | sed 's/.Z//'`
		[ "$DEBUG" -eq 1 ] && _print_to_stdout "[$currfunc] tar -xvf $newabpath"
		taroutput=`tar -xvf $newabpath 2>&1`
	fi

	if [ $extension = "tar" ];
	then
		[ "$DEBUG" -eq 1 ] && _print_to_stdout "[$currfunc] tar -xvf $absolutepath"
		taroutput=`tar -xvf $absolutepath 2>&1`
	fi

	[ "$DEBUG" -eq 1 ] && _print_to_stdout "[$currfunc] Exited function."
}
