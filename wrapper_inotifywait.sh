#!/bin/bash
print_usage() {
	echo "Usage: ${BASH_SOURCE}	-f <path of the file to watch> -c <command or script with arguments to execute> [-l loop or not ] [-s the command is a script name ] [-t <seconds> sleep time in seconds after a successful execution ]"
	exit 1
}
SEC=0
while getopts ":f:c:el:ost:" opt; do
	case $opt in
		f)
			FILE="$OPTARG"
			;;  
		c)
			SCRIPT_CMD="$OPTARG"
			;;
		e)
			LOOP=true
			;;
		l)
			LOG_FILE="$OPTARG"
			;;
		o)
			OVERWRITE=true
			;;
		s)
			SCRIPT=true
			;;
		t)
			SEC=$OPTARG
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			print_usage
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			print_usage
			;;
		esac
done

validate() {
	if [ -z "$FILE" ]; then
		echo "File to watch not given" >&2
		print_usage
	fi
	DIR="$(dirname "$FILE")"
	if [ ! -d "$DIR" ]; then
		echo "Directory of the given file path does not exist" >&2
		print_usage
	fi
	if [ -z "$SCRIPT_CMD" ]; then
		echo "The command is not given" >&2
		print_usage
	fi
}
if [ "${OVERWRITE}" = true ]; then
	> $LOG_FILE
fi
# predetermined var for logger function: LOG_FILE file to log to
# predetermined var for logger function: overwrite or append (default)
#
# $1 log level - INFO ERROR DEBUG
# $2 log message
# $3 shell line number
logger() {
	echo "$(date) $1 [${BASH_SOURCE}:$3] $2" >> $LOG_FILE
}
validate
eval FILE="$FILE"
#NOTE! I am not sure if the two boolean operations connected by && is atomic or not, if not this is a bug
while true; do
	if [ ! -f $FILE ] && inotifywait --format '%e %f : %w' $DIR || [ -f $FILE ] && inotifywait -e modify,delete_self,move_self --format '%e %f : %w' $FILE; then
		if [ -f $FILE ]; then 
			if [ "$SCRIPT" = true ]; then			
				/bin/bash ${SCRIPT_CMD}
				EXIT_CODE=$?
				LINE_NO=$(expr ${LINENO} - 2)
			else
				eval "${SCRIPT_CMD}"
				EXIT_CODE=$?
				LINE_NO=$(expr ${LINENO} - 2)
			fi
			if [ $EXIT_CODE -eq 0 ]; then
				logger INFO "COMMAND or SCRIPT - ${SCRIPT_CMD} - execution succeeded :)" $LINE_NO
			else
				logger ERROR "COMMAND or SCRIPT - ${SCRIPT_CMD} - execution failed :<" $LINE_NO
			fi
			sleep $SEC
		fi
		if [ "$LOOP" != true ]; then #This true is /bin/true
			exit $EXIT_CODE
		fi
	fi
done
