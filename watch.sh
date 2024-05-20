#!/bin/bash

MIN_VALUE=1; # The minimum value an interval option can be set. 
DEFAULT_VALUE=2; # The default value to swap interval with in case of less than the MIN_VALUE.

# print() function to print statements AND to return strings from bash functions. 
# here using printf because echo does not print strings that seem like it's own optional arguments. 
# for example `echo -n 0.3` ; only prints `0.3`; fails to print `-n 0.3` 
function print() {
    printf "%s " "$@"
    printf "%s\n" " "
}

# check_interval() function to check if `a` is less than `b`.
# check_interval a b ; returns 0 if a < b else returns 1;
function check_interval() {

    watch_interval=$1
    # the following are parsed by watch as valid interval values : 
    # The bellow regex matches integers and floats like : 1, 32, 3.2, 0.4 etc
    # to match improper floats like : .1, .42, 21., 3., +.32, -.32 etc
    # and also to match special chars like : -., +., ., +, -, . 
    if [[ $watch_interval =~ ^[-+]?(([0-9]*)?((\.)|(,))?([0-9]*)?)$ ]]; then
        # replace + or - with 0;
        # because bc throws an error for + or -; 
        if [[ $watch_interval =~ ^[-+]$ ]]; then 
            watch_interval=0
        fi
        # replace any occurance of `,` with `.` as bc throws an error for `,`.
        watch_interval="${watch_interval//,/.}" 
        # remove `+` prefix from numbers because bc throws an error if not : +43 => 43, +.32 => .32, +0. => 0. ;
        watch_interval=${watch_interval#+}
        # bc does not throw any errors for `-` prefix, they are parsed as negative integers/floats; 
        # compare the parsed float/int with MIN_VALUE;
        if [ $( echo "$watch_interval < $MIN_VALUE" | bc -l ) -eq 1 ]; then
            return 0
        fi
    fi
    # return 1 if regex does not match strings that are not numbers or numbers that are greater than MIN_VALUE;
    # in this case we let watch handle the strings as it is so that it may throw errors. 
    return 1
}

# parse_short_options() function to parse short options for a single word:
# for example a word like ` -cvhn 0.4 ` will be parsed as ` -c -v -h -n 0.4 `;
# also can parse words like ` -cv--h-n0.4 ` as ` -c -v -h -n 0.4 ` because such words are parsed as \
# valid short arguments by watch. 
function parse_short_options() {

    options="$@"
    options_length=${#options}

    # a variable to collect interpreted options:
    reconstructed_options=""

    # A white_space flag to determine whether the next word is either a value for the current option OR NOT:
    # for example : a word can be -cvh which will be parsed as -c -v -h  OR -cvn0.3 will be parsed as -c -v -n 0.3
    # for example : -cvn 0.4 ... a white space exists between n and 0.4, the next word 0.4 belongs to the current word that is being processed. therefore white_space is flagged as true;
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

                # get the -n's value however it has been declared ( -n 0.4 | -n0.4 | -n    0.4 etc )
                option_value=$(printf "%s " ${options:i+1} | awk '{print $1}') # ... works in case of -n50 | -n 50 | -n      50 | -n  50 -other -optionsi=0
                if [[ ${options:i+1:1} = " " ]]; then
                    white_space=true # flag the existence of whitespace.
                fi

                # check whether the given -n value is less than the MIN_VALUE
                if  check_interval $option_value $MIN_VALUE ; then 
                    # If the current value given by the user is less than MIN_VALUE then swap it with a default value.
                    option_value=$DEFAULT_VALUE
                fi
                # reconstruct options after swaping n as needed. 
                reconstructed_options="$reconstructed_options -n $option_value"
                break;
                ;;
            ('d') # parsing the differences option:
                # -d=permanent | -dpermanent - are the only allowed possibilities.
                # -d permanent is not allowed. This will be parsed separately as `-d` and `permanent`, where `permanent` is considered as the next positional argument. 
                
                option_value=$(printf "%s " ${options:i} | awk '{print $1}') # get the option as it is : d=permanent or d=anything_else

                # check whether an `=` exists for the -d option : like -d=  or -d=permanent or -d=per etc
                if [[ ${option_value:1} =~ = ]]; then
                    option_value=${option_value#*=} # if `=` exists then strip the d's value (i.e. get `permanent` from -d=permanent). the value can also be empty in case of `-d=` 
                else
                    option_value=${option_value:1} # if `=` does not exist (i.e. -d or -dpermanent ), then get the value `permanent` from -dpermanent.  
                fi
                
                # reconstruct options as is. 
                reconstructed_options="$reconstructed_options -d=$option_value"
                break;
                ;;
            ([a-zA-Z]) # in case of options that do not require optional values are appended as is: 
                # print "any char short option"
                reconstructed_options="$reconstructed_options -$char "
                # print "* : $reconstructed_options"
                ((i++))
                ;;
            (*) # MAY REQUIURE WORK HERE : 
                if [[ $char = " " ]]; then
                    break;
                fi
                ((i++))
        esac
    done
    
    # return the reconstructed short options 
    print "$reconstructed_options"
    # return the white_space flag to indicate whether the next word is a value of the current word OR is a next positional argument. 
    [[ $white_space = true ]] && return 1 || return 0
}

# A function to parse all the options including long options. 
function parse_options() {

    # take all the arguments as an array.
    options=("$@")

    # indicate which options among the arguments requires a value to be passed. 
    long_options=("interval")
    reconstructed_options=""

    i=0
    while [ $i -lt ${#options[@]} ]; do

        case "${options[$i]}" in 
            --*)    
                # extract the given option : i.e. get the word `interval` from `--interval=value`.
                given_option=${options[$i]#--}
                given_option="${given_option%%=*}"  
            
                # a flag to indicate whether the given option can have a value OR not. 
                can_have_value=false

                # iterate through the long options to match with the regex, this is because : 
                for long_option in ${long_options[@]}; do
                    # The following regex pattern is parsed by watch as `--interval`:
                    # --i=0.3 | --in=0.3 | --int=0.3 | --interv=0.3 | --interval=0.3 etc
                    # The following regex pattern is not parsed by watch:
                    # --intervals=0.3 ( an extra character `s` in the end ).
                    if [[ $long_option =~ ^"$given_option".*$ ]]; then
                        # print "long option : $long_option"
                        can_have_value=true
                        reconstructed_options="$reconstructed_options --$long_option"
                        # check for existence of `=` in case of : --interval=0.3
                        if [[ "${options[$i]}" =~ =.+ ]]; then
                            given_value="${options[$i]#*=}"
                        # OR in case of --interval 0.3
                        else
                            given_value="${options[$i+1]}"
                            ((i++))
                        fi
                        
                        # if the long option is an interval then validate it's value and swap as needed. 
                        if [[ $long_option = 'interval' ]]; then
                            if [[ -n $given_value && $(check_interval $given_value $MIN_VALUE; echo $?) -eq 0 ]]; then
                                given_value=$DEFAULT_VALUE
                            fi
                        fi
                        # append the swapped long option. 
                        reconstructed_options="$reconstructed_options $given_value"
                        break
                    fi
                done
                
                # append the long option as it is. 
                if [ $can_have_value = false ] ; then
                    reconstructed_options="$reconstructed_options ${options[$i]}" 
                fi
                
                # append a space in the end to handle the next arguments. 
                reconstructed_options="$reconstructed_options "
                ((i++))
                ;;
            -*)
                # print "options : ${options[$i]}"
                # parse the short options in a given word.
                reconstructed_options="$reconstructed_options $(parse_short_options ${options[$i]#-} ${options[$i+1]})" 
                # based on the white_space flag, keep/skip the next work in the arguments. 
                ((i=i+$?+1))    
                # print $reconstructed_options
                ;;
            *)
                # In case of an argument that is neither a long option or short option, then the rest of the arguments are considered as \
                # positional arguments by watch. 
                reconstructed_options="$reconstructed_options ${options[@]:i} "
                break;
                ;;
        esac
    done
    
    # return the reconstructed arguments. 
    print $reconstructed_options
}

parse_options "$@"
