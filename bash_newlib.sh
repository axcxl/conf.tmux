#   Defines that should be set before using the library
# DEF_SERIAL - serial interface
# DEF_SPEED - speed for serial interface
# DEF_USER - user for ssh commands
# DEF_PASS - password for ssh command (NOT SECURE!, use for devices with default passwords)
# DEF_PS1=$PS1 - useful for git repo info change

###########
#### COLORS
#################
black='\033[30;148m'
blue='\033[34;148m'
magenta='\033[35;148m'
cyan='\033[36;148m'
white='\033[37;148m'

yellow='\033[0;33m'
red='\033[1;31m'
green='\033[0;32m'
colorStop='\033[0m'

#Black/white fonts with (color) background
yellowB='\e[0;30;43m'
greenB='\e[0;30;42m'
redB='\e[0;37;41m'
blueB='\e[0;37;44m'
blackB='\e[0;37;40m'


# Send command to device via ssh
# Arg1: device IP
# Arg2: commands to send (can be multiple lines)
#
# Example: see sshReboot below
function sshSend
{
    sshpass -p $DEF_PASS ssh $DEF_USER@$1 << EOF
enable
$2
EOF
}

# Reboot device via SSH. Does not save config!
# Arg1: device IP
function sshReboot
{
    sshSend $1 "reboot
    yn"
}

# Open serial connection based on ser2net config file. Errors out if the serial:speed
# combo is not found in the file.
# Arg1(optional): serial name(without tty)
# Arg2(optional): serial speed
#
# Example: serial usb0 115200 -> opens ttyUSB0:115200 on local PC
function serial
{
    serial=${1:-$DEF_SERIAL}
    speed=${2:-$DEF_SPEED}
     
    port=$(cat /etc/ser2net.conf | grep -i tty$serial:$speed | awk -F":" '{print $1}')

    echo "Port for tty$serial:$speed=$port"
    if [ "$port" == "" ]; then
        echo -e "$red Serial not found, check ser2net.conf!"
        return
    fi

    telnet localhost $port
}

# Send a serial command via local ser2net
# Arg1(optional): serial name(without tty)
# Arg2(optional): serial speed
# Arg1/3: commands to send
# NOTE: you can give serial,speed,cmd or just cmd
#
# Example: "serialSend usb0 115200 login" or "serialSend login"
function serialSend
{
    if [ "$#" -eq 3 ]; then
        serial=$1
        speed=$2
        cmd=$3
    else
        serial=""
        speed=""
        cmd=$1
    fi

    serial $serial $speed << EOF
$cmd
EOF

sleep 1
}

# Create cscope database for folder in .cs_<folder name> in current path
# Uses global paths for files!
# Arg1: folder on which to work
#
function cscope_update
{
    f=$1
    csf=$(echo $f | tr \/ _)
    repo=$(pwd)
    ignore_dirs=$2

    echo "Ignoring $ignore_dirs"
    echo "Working on $f. Putting results in $csf"
    mkdir -p .cs_$csf
    rm -rf .cs_$csf/*
    
    echo "Finding files in $f"
    cmd="ag --cc -l $ignore_dirs \"\" $repo/$f >> .cs_$csf/cscope.files "
    #echo $cmd
    eval $cmd
    
    echo "Cscope db in $f (folder=$csf)"
    cd .cs_$csf
    cscope -b -q

    echo "Done in $f (folder=$csf)"
    cd -
}

# Run command in loop with a small sleep in between
# Args: what to run, concatenetes everything
function loop
{
    cmd="$@"
    echo "Looping command $cmd"
    while true; do
        $cmd
        sleep 1
    done
}

# Run command in all folders in current path
# Args: what to run, can be multiple command (see example)
#
# WARNING: HIGHLY UNSAFE, use with care!
#
# Example: foreachfolder "git status
# uname -a"
function foreachfolder
{
    cmd=$@
    # Just a little precaution
    if [[ $cmd == *"rm "* ]]; then
        echo "NO RM LIKE THIS! TOO DANGEROUS!"
        return
    fi

    echo "Running $cmd for each folder"
    for d in */ ; do
        echo ""
        cd $d
        pwd
        eval "$cmd" | while read line; do
            echo -e "$d: $line"
        done
        cd ..
    done
}

# Special prompt for git repos - exported as PROMPT_COMMAND
# NEEDS: DEF_PS1 set to PS1 in .bashrc before sourcing this
function git_info
{
    CURR_PS1=$DEF_PS1
    CURR_BRANCH=`git rev-parse --abbrev-ref HEAD 2>/dev/null`
    if [[ $? != 0 ]]
    then
        export PS1=$CURR_PS1
    else
        #LAST_COMMIT=`git show -s --format=%ci | awk '{print $1 " " $2}'` - show also HH:MM:SS
        LAST_COMMIT=`git show -s --format=%ci | awk '{print $1}'`
        NO_STASHES=`git stash list 2>/dev/null | wc -l`
        #Kinda time consuming on large repos, but fast enough on SSD :)
        CURR_FCHANGED=`git diff --stat | awk {'print $1'} 2> /dev/null | tail -n1`
        if [[ "$CURR_FCHANGED" == "" ]]
        then
            CURR_FCHANGED=0
        fi
        export PS1='<\w>\[\033[01;31m\]\[\033[01;32m\][$CURR_BRANCH]\[\033[01;34m\][LAST:$LAST_COMMIT]\[\033[01;31m\][CH:$CURR_FCHANGED]\[\033[00m\][ST:$NO_STASHES]\$ '
    fi
}
#Run command before each bash command
export PROMPT_COMMAND=git_info
