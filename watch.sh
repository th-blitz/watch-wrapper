#!/bin/bash


function print() {
	printf "%s " "$@"
	printf "%s\n" " "
}

function check_interval() {

	watch_interval=$1
	MIN_VALUE=$2
	# allow numbers : +n, -n, .n, +.n, -.n, +., -., ., +, - etc;
	if [[ $watch_interval =~ ^[-+]?(([0-9]*)?(\.)?([0-9]*)?)$ ]]; then
		# replace + or - with 0;
		if [[ $watch_interval =~ ^[-+]$ ]]; then 
			watch_interval=0
		fi
		watch_interval=${watch_interval#+}
		if [ $( echo "$watch_interval < 1" | bc -l ) -eq 1 ]; then
			# print "less than 1"
			return 0
		fi
	fi
	return 1
}

function parse_short_options() {

	options="$@"
	options_length=${#options}

	reconstructed_options=""
	options="$options "
	i=0
	while [ $i -lt $options_length ]; do

		print "$reconstructed_options"
		char="${options:i:1}"

		case $char in
			('n')
				# first_word="${options%% *}" ... works in case of -n 50 | will NOT work in case of -n50
				option_value=$(printf "%s " ${options:i+1} | awk '{print $1}') # ... works in case of -n50 | -n 50 | -n      50 | -n  50 -other -optionsi=0
				if  check_interval $option_value 1 ; then 
					option_value=1
				fi
				reconstructed_options="$reconstructed_options -n $option_value"
				break;
				;;
			('d')
				# -d=permanent | -dpermanent
				option_value=$(printf "%s " ${options:i} | awk '{print $1}') 
				if [[ ${option_value:1} =~ = ]]; then
					option_value=${option_value#*=}
				else
					option_value=${option_value:1}
				fi
				# print $option_value
				reconstructed_options="$reconstructed_options -d=$option_value"
				# print $reconstructed_options
				break;
				;;
			('e')
				# first_word="${options%% *}" ... works in case of -n 50 | will NOT work in case of -n50
				option_value=$(printf "%s " ${options:i+1} | awk '{print $1}') # ... works in case of -n50 | -n 50 | -n      50 | -n  50 -other -optionsi=0
				reconstructed_options="$reconstructed_options -e $option_value"
				break;
				;;
			(*)
				reconstructed_options="$reconstructed_options -$char "
				print "$reconstructed_options"
				((i++))
				;;
		esac
	done

	print "$reconstructed_options"
}





