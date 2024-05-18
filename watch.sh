#!/bin/bash


# To print statements AND also to return strings from bash functions. 
# here using printf because echo does not print strings that seem like it's own optional arguments. 
# for example `echo -n 0.3` ; only prints 0.3; fails to print -n 0.3 
function print() {
	printf "%s " "$@"
	printf "%s\n" " "
}

# A function to check if a is less than b.
# check_interval a b ; returns 0 if a < b else returns 1;
function check_interval() {

	watch_interval=$1
	MIN_VALUE=$2
	# the following are parsed by watch as valid interval values : 
	# regex to match integers and proper floats like : 1, 32, 3.2, 0.4 etc
	# to match improper floats like : .1, .42, 21., 3., +.32, -.32 etc
	# and also to match special chars like : -., +., ., +, - . 
	if [[ $watch_interval =~ ^[-+]?(([0-9]*)?(\.)?([0-9]*)?)$ ]]; then
		# replace + or - with 0;
		# because bc throws an error for + or -; 
		if [[ $watch_interval =~ ^[-+]$ ]]; then 
			watch_interval=0
		fi
		# remove + prefix from numbers because bc throws an error if not : +43 => 43, +.32 => .32, +0. => +0. ;
		# bc does not throw any errors for - prefix, they are parsed as negative integers or floats; 
		watch_interval=${watch_interval#+}
		# compare the matched or parsed , float or int with MIN_VALUE;
		if [ $( echo "$watch_interval < $MIN_VALUE" | bc -l ) -eq 1 ]; then
			# print "less than 1"
			return 0
		fi
	fi
	# return 1 if regex does not match; in this case any string that was not matched with the above \
	# regex is left for watch so that it can throw an error. 
	return 1
}

# A function to parse short options, for a single word:
# for example a word like -cvhn 0.4 will be parsed as -c -v -h -n 0.4;
# also can parse words like -cv--h-n0.4 as -c -v -h -n 0.4 because such words are parsed as \
# valid short arguments by watch. 
function parse_short_options() {

	options="$@"
	options_length=${#options}

	# a variable to collect interpreted options:
	reconstructed_options=""

	# a flag to determine whether the next word is either a value for the current option OR NOT:
	# for example : a word can be -cvh which will be parsed as -c -v -h  OR -cvn0.3 will be parsed as -c -v -n 0.3
	# for example : -cvn 0.4 ... a white space exists between n and 0.4, the next word 0.4 belongs to the current word that is being processed. therefore white_space = true;
	# for example : -cvn0.4 ... white_space remains false.
	# for example : -cvh -n 0.4 ... only one word is parsed i.e. -cvh => -c -v -h  ( the pair -n 0.4 is considered as a next word. ) therefore white_space = false. 
	white_space=false
	options="$options " # add a white space at the end of the word to handle loop terminations.
	i=0
	while [ $i -lt $options_length ]; do

		# print "$reconstructed_options"
		char="${options:i:1}" # go through the word one character at a time. 

		case $char in
			('n') # if the char is n then parse it's value. 

				# get the -n's value however it is declared ( -n 0.4 | -n0.4 | -n    0.4 etc )
				option_value=$(printf "%s " ${options:i+1} | awk '{print $1}') # ... works in case of -n50 | -n 50 | -n      50 | -n  50 -other -optionsi=0
				if [[ ${options:i+1:1} = " " ]]; then
					white_space=true # flag the existence of whitespace.
				fi

				# check whether the given -n value is less than the MIN_VALUE
				if  check_interval $option_value 1 ; then 
					# If the current value given by the user is less than MIN_VALUE then swap it with a default value.
					option_value=1
				fi
				# reconstruct options after checking and swaping as needed. 
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
			([a-zA-Z])
				# print "any char short option"
				reconstructed_options="$reconstructed_options -$char "
				# print "* : $reconstructed_options"
				((i++))
				;;
			(*)
				((i++))
		esac
	done

	print "$reconstructed_options"
	# print $white_space
	[[ $white_space = true ]] && return 1 || return 0
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
				# print "options : ${options[$i]}"
				reconstructed_options="$reconstructed_options $(parse_short_options ${options[$i]#-} ${options[$i+1]})" 
				# print $reconstructed_options
				((i=i+$?+1))	
				;;
			*)
				reconstructed_options="$reconstructed_options ${options[@]:i} "
				break;
				;;
		esac
	done

	print $reconstructed_options
}


