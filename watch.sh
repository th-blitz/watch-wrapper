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
		watch_interval=${watch_interval#+}
		# replace + or - with 0;
		if [[ $watch_interval =~ [-+]? ]]; then 
			watch_interval=0
		fi
		if [ $( echo "$watch_interval < 1" | bc -l ) -eq 1 ]; then
			print "less than 1"
			return 1
		fi
	fi
	return 0
}


