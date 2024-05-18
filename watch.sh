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


function parse_options() {

	options=("$@")

	long_options=("interval")
	reconstructed_options=""

	i=0
	while [ $i -lt ${#options[@]} ]; do

		case "${options[$i]}" in 
			--*)
				given_option=${options[$i]#--}
				given_option="${given_option%%=*}"	
				
				can_have_value=false

				for long_option in ${long_options[@]}; do
					if [[ $long_option =~ ^"$given_option".*$ ]]; then
						# print "long option : $long_option"
						can_have_value=true
						reconstructed_options="$reconstructed_options --$long_option"

						if [[ "${options[$i]}" =~ =.+ ]]; then
							given_value="${options[$i]#*=}"
						else
							given_value="${options[$i+1]}"
							((i++))
						fi

						if [[ $long_option = 'interval' ]]; then
							if [[ -n $given_value && $(check_interval $given_value 1; echo $?) -eq 0 ]]; then
                        		given_value=1
                    		fi
						fi
						reconstructed_options="$reconstructed_options $given_value"
						break
					fi
				done

				if [ $can_have_value = false ] ; then
					reconstructed_options="$reconstructed_options ${options[$i]}" 
				fi

				reconstructed_options="$reconstructed_options "
				((i++))
				;;
			-*)
				given_option=${options[$i]#-}
				;;
			*)
				reconstructed_options="$reconstructed_options ${options[@]:i} "
				break;
				;;
		esac
	done

	print $reconstructed_options
}

#
# i=0
# 24     while [ $i -lt ${#options[@]} ]; do
# 23
# 22         # print "${options[$i]} ${options[$i+1]}"
# 21
# 20         case "${options[$i]}" in
# 19             --*)
# 18                 # NEEDS FIXING WITH --difference=permanent
# 17                 given_option=${options[$i]#--}
# 16                 given_option="${given_option%%=*}"
# 15                 if [[ "${options[$i]}" =~ =.+ ]]; then
# 14                     given_value="${options[$i]#*=}"
# 13                 else
# 12                     given_value="${options[$i+1]}"
# 11                     ((i++))
# 10                 fi
#  9
#  8                 if [[ "interval" =~ ^"$given_option".*$ ]]; then
#  7                     # print "$given_option matches with interval and its value is $given_value"
#  6                     if [[ -n $given_value && $(validate_watch_interval_value $given_value 1; echo $?) -eq 0 ]];
#  5                         given_value=1
#  4                     fi
#  3                     reconstructed_options="$reconstructed_options --$given_option $given_value "
#  2                 else
#  1                     reconstructed_options="$reconstructed_options ${options[$i]}"
#
#
#
