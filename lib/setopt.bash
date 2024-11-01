#!/bin/bash

# Author: James Taylor <jt+setopt@sent.com>
# Date: 2024-05-28

<<'DOCUMENTATION'

The setopt function defined in this bash shell library is designed to
replace the option parsing functionality of bash shell's builtin getopts
and GNU getopt. It is easier to use than either of those traditional
methods of option parsing. It can handle short options like -h as well as
long options like --help. Options that take a value are validated using
bash's builtin support for POSIX extended regular expressions. All of
setopt is written in pure bash and does not make any calls to external
commands so it should work anywhere that bash itself works.

Short options can be grouped in the standard way. If a short option expects
a value it will take whatever value is to the right of it regardless of
whether there is a space between that short option and the value, so for
example -n 5 and -n5 do the same thing. Long options that take a value can
be joined to their value with an equals sign or separated by a space, so
for example --size 5 and --size=5 do the same thing.

When writing large and complex scripts it is often helpful to split the
functionality into subcommands each with their own separate command line
options. The setopt function recognises subcommands, parses their options,
and dispatches to the appropriate handler function in your script.

To use setopt, you simply define the options (and any subcommands) for your
script in a global string variable called setopt_define and source this
library file in your script, then run setopt at the bottom of your script
with the name of the main entry function of your script, which is typically
called "main", and the script's arguments in the "$@" parameter array. So
that is just two lines of code:

    source setopt.bash
    setopt main "$@"

That "main" function will then see an associative array called opt[] which
has all the option settings already parsed out and validated for you and
any remaining non-option arguments in $@ as usual. If you are using
subcommands then, after any initialisation your main function might need to
do, it can pass control back to the dispatcher in setopt using:

    setopt "$@"

which will cause setopt to take the subcommand name it finds in the first
argument $1 and parse any options defined for that subcommand before
dispatching control to the appropriate hander function. Each subcommand can
pass control back to the setopt dispatcher in this way for the next
subcommand nested as many levels deep as you wish.

If setopt is called with something that is not a valid subcommand in $1
then an "Undefined subcommand" error will be the result. If you wish to
handle this situation more gracefully you can check that the value in $1 is
a valid subcommand before calling setopt using something like:

    [[ $1 =~ ^(create|read|update|delete)$ ]] && setopt "$@"

If the dispatcher does not find a handler function for a particular
subcommand then it will first try looking for a handler for the next deeper
subcommand, and so on recursively. This is a shortcut for the situation
where a particular subcommand does nothing by itself because it always
expects another subcommand name to come next. For example, a subcommand
called 'get' could expect the name of something it should get to come next,
'get data', 'get results', etc, and instead of writing a get function that
does nothing except call setopt "$@" again, you can skip writing a get
function and just write the functions for get_data and get_results.

If the special -- end of options mark is encountered on the command line
then setopt will stop processing options and leave whatever is after the --
mark in $@ as an ordinary argument. You can test opt[--] to see if this is
what happened. You will get an error if you call setopt "$@" to process any
more of the command line after opt[--] has been set.

Note that opt[] is dynamically scoped within each subcommand which means
that each deeper level of subcommand can see the opt[] settings set by the
main program or a higher up subcommand, but the higher up calling code's
version of opt[] is protected from changes made by the deeper subcommand.
Basically, dynamic scoping means that when a deeper handler function
returns, opt[] is restored to the way it was in the caller.

Internal to the setopt implementation it uses _opt[] to keep track of the
current state. Your script can modify opt[] but do not touch _opt[].

DEFINE OPTIONS
==============

setopt is controlled by the string variable called setopt_define which must
exist before running the setopt function. The recommended way to create
this setopt_define string is by using the builtin read -rd '' like this:

    read -rd '' setopt_define <<'END'
    ...
    END

Between the read command and the END token is where you can define the
options and subcommands you want the setopt function to handle. Blank lines
and comments starting with # are allowed anywhere in the definition.

There are two types of definition lines:

    1. Option definitions
    2. Subcommand definitions

Option lines define options for the previous subcommand, and options
defined before any subcommands are options for the main program.

Option definition lines can have between 1 and 4 parts separated by
whitespace as follows:

    1. Optional: short option letter (only 1 letter).
    2. REQUIRED: long option name (minimum 2 letters).
                By default this long name is used as the entry in opt[].
    3. Optional: alternative entry name in opt[] instead of long option.
                This can be useful to avoid option name clashes.
    4. Optional: regex pattern in (brackets) to match a valid value.
                Options that do not take values are just counted.

For more information on POSIX extended regex patterns see: man 7 regex
Simple examples are:

    (.*)        to match any value including the '' empty string.
    (.+)        to match any value but NOT the '' empty string.
    ([0-9]+)                to match a non-negative integer.
    (-?[0-9]+(\.[0-9]+)?)   to match a possibly negative fractional number.

Subcommand lines look a bit like absolute file paths as they must start
with a / and each deeper level of subcommand is separated by a / too.
By default a subcommand like /create/storage/block will dispatch to the
function create_storage_block with / slashes replaced by _ underscores.

The name of an alternative handler function can be given after the
subcommand path, separated by whitespace, which allows you to avoid
a clash with a bash keyword, external command, or other function, etc.
The alternative handler function name applies only to that subcommand and
does not affect the names of deeper subcommands, so for example:

    /help          show_main_help
    /help/formats

will result in the show_main_help handler function being called when a user
types the 'help' subcommand, but when the user types 'help formats' then
the handler function will be help_formats not show_main_help_formats.

EXAMPLES
========

Some example definitions should help clarify how it works.

v verbose       This defines -v and --verbose options and they do not take
                a value but they set opt[verbose] initially to 1, then 2,
                3, 4, etc, if the option appears more than once like -vvv

version         This defines a long option called --version with no -v
                short equivalent. It does not take a value. It sets
                opt[version] to 1 (or 2, 3, etc but you probably don't
                care how many times --version appeared).

reset x         This defines a long option --reset with no short option and
                when --reset is used opt[x] will be set to 1 (2, 3, etc).

max ([0-9]+)    The option --max expects a value, an non-negative integer,
                and will store that in opt[max].

format (json|yaml)
                The option --format expects a value of "json" or "yaml"
                only, nothing else allowed, and stores it in opt[format].

n name obj-name (.+)
                The options -n or --name expect a value, any non-empty
                string will be accepted, and stores it in opt[obj-name].

ram        ([0-9]+[KkMmGg])
memory ram ([0-9]+[KkMmGg])
                Both --ram and --memory will store a value in opt[ram]
                so --memory is effectively an alas for --ram. The value
                must match a number followed by units K, M, or G, or the
                lower case versions k, m, or g.

/read  read_obj
                This defines a subcommand call 'read' on the command line
                but which actually dispatches to the 'read_obj' handler
                function (thus avoiding a clash with the read builtin).

DOCUMENTATION

# if you do not have a die() function defined then this one is used
if ! declare -F die &>/dev/null; then
    die() {
        [[ -t 2 ]] && printf '\e[31;1m'
        printf '%s\n' "$1" >&2
        [[ -t 2 ]] && printf '\e[m'
        (($#>1)) && printf '%s\n' "${@:2}" >&2
        exit 1
    }
fi

setopt() {
    if ((!$#)); then
        return
    elif [[ -z ${!_opt[*]} ]]; then
        [[ -v setopt_define ]] || die "Set setopt_define before calling setopt"
        local -A _opt
        # _opt[set]=$-; set +e
        while read -r _opt[line]; do
            [[ ${_opt[line]} =~ ^# ]] && continue
            read -r _opt[line] <<<"${_opt[line]%% #*}"
            [[ -n ${_opt[line]} ]] || continue
            if [[ ${_opt[line]} =~ ^/ ]]; then
                read -r _opt[path] _opt[func] <<<"${_opt[line]}"
                if [[ -z ${_opt[func]} ]]; then
                    _opt[func]=${_opt[path]//\//_}
                    _opt[func]=${_opt[func]#_}
                fi
                _opt[${_opt[path]}]=${_opt[func]}
                _opt[trail]=${_opt[path]}
                while [[ -n ${_opt[trail]} ]]; do
                    _opt[${_opt[trail]}]=${_opt[${_opt[trail]}]:-1}
                    _opt[trail]=${_opt[trail]%/*}
                done
            else
                _opt[re]=''
                if [[ ${_opt[line]} =~ \( ]]; then
                    IFS='(' read -r _opt[line] _opt[re] <<<"${_opt[line]}"
                    _opt[re]="(${_opt[re]}"
                fi
                read -r _opt[short] _opt[long] _opt[name] <<<"${_opt[line]}"
                if ((${#_opt[short]}>1)); then
                    read -r _opt[long] _opt[name] <<<"${_opt[short]} ${_opt[long]}"
                    _opt[short]=""
                fi
                [[ -n ${_opt[name]} ]] || _opt[name]=${_opt[long]}
                _opt[${_opt[path]}:${_opt[long]}]=${_opt[name]}
                [[ -n ${_opt[short]} ]] && _opt[${_opt[path]}:${_opt[short]}]=${_opt[long]}
                if [[ -n ${_opt[re]} ]]; then
                    _opt[${_opt[path]}:${_opt[long]}=]=${_opt[re]}
                    [[ check_valid_regex =~ ${_opt[re]} ]] || { (($?==2)) && \
                        die "Bad regex in definition of ${_opt[path]:-main} option ${_opt[long]}"
                    }
                fi
            fi
        done <<<"$setopt_define"
        unset _opt[line] _opt[trail] _opt[short] _opt[long] _opt[name] _opt[re]
        _opt[cmd]="main"
        _opt[path]=""
        _opt[func]=$1
        # set -"${_opt[set]}"
    elif ((opt[--])); then
        die "Cannot go beyond -- end of options mark, check opt[--] before calling setopt"
    else
        _opt[cmd]=$1
        _opt[path]+="/$1"
        _opt[func]=${_opt[${_opt[path]}]}
        [[ -n ${_opt[func]} ]] || die "Undefined subcommand ${_opt[path]#/}"
    fi
    shift
    local -A opt
    # _opt[set]=$-; set +e
    while (($#)); do
        if [[ $1 == -- ]]; then     # end of options mark, go no further
            shift
            opt[--]=1
            break
        elif [[ $1 == - ]]; then    # typically means stdin or stdout
            break
        elif [[ $1 =~ ^-- ]]; then
            _opt[long]=${1#--}
            _opt[key]="${_opt[path]}:${_opt[long]}"
            if [[ ${_opt[long]} =~ = ]]; then
                _opt[val]=${_opt[long]#*=}
                _opt[long]=${_opt[long]%%=*}
                _opt[key]="${_opt[path]}:${_opt[long]}"
                [[ -n ${_opt[${_opt[key]}]} ]] || \
                    die "Unknown ${_opt[cmd]} option --${_opt[long]}"
                [[ -n ${_opt[${_opt[key]}=]} ]] || \
                    die "The ${_opt[cmd]} option --${_opt[long]} does not expect a value"
                opt[${_opt[${_opt[key]}]}]=${_opt[val]}
            elif [[ -z ${_opt[${_opt[key]}]} ]]; then
                die "Unknown ${_opt[cmd]} option --${_opt[long]}"
            elif [[ -n ${_opt[${_opt[key]}=]} ]]; then
                shift
                (($#)) || die "The ${_opt[cmd]} option --${_opt[long]} expects a value"
                opt[${_opt[${_opt[key]}]}]=$1
            else
                ((opt[${_opt[${_opt[key]}]}]+=1))
            fi
            if  [[ -n ${_opt[${_opt[key]}=]} ]] && \
                [[ ! ${opt[${_opt[${_opt[key]}]}]} =~ ^${_opt[${_opt[key]}=]}$ ]]
            then
                die "Value for ${_opt[cmd]} option --${_opt[long]} must match ${_opt[${_opt[key]}=]}"
            fi
        elif [[ $1 =~ ^- ]]; then
            _opt[rest]=${1#-}
            while ((${#_opt[rest]})); do
                _opt[short]=${_opt[rest]:0:1}
                _opt[rest]=${_opt[rest]#?}
                _opt[long]=${_opt[${_opt[path]}:${_opt[short]}]}
                [[ -n ${_opt[long]} ]] || die "Unknown ${_opt[cmd]} option -${_opt[short]}"
                _opt[key]="${_opt[path]}:${_opt[long]}"
                if [[ -n ${_opt[${_opt[key]}=]} ]]; then
                    if ((${#_opt[rest]})); then
                        opt[${_opt[${_opt[key]}]}]=${_opt[rest]}
                    else
                        shift
                        (($#)) || die "The ${_opt[cmd]} option -${_opt[short]} expects a value"
                        opt[${_opt[${_opt[key]}]}]=$1
                    fi
                    if [[ ! ${opt[${_opt[${_opt[key]}]}]} =~ ^${_opt[${_opt[key]}=]}$ ]]
                    then
                        die "Value for ${_opt[cmd]} option -${_opt[short]} must match ${_opt[${_opt[key]}=]}"
                    fi
                    break
                else
                    ((opt[${_opt[${_opt[key]}]}]+=1))
                fi
            done
        else
            break
        fi
        shift
    done
    unset _opt[short] _opt[long] _opt[key] _opt[val] _opt[rest]
    # set -"${_opt[set]}"
    if declare -F "${_opt[func]}" &>/dev/null; then
        "${_opt[func]}" "$@"
    elif [[ -n ${_opt[${_opt[path]}/$1]} ]]; then
        setopt "$@"
    else
        die "Undefined subcommand handler function ${_opt[func]}"
    fi
}

