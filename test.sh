#!/usr/bin/env bash

## author: A. Krupicka (2015)
## You should make sure that the time is as synchronized as possible on the 'source' and 'target' machines
## It might even make sense to use the same node as source and target to avoid this completely

# Configuration variables.
source=l4
target=l5
target_port=5678
cluster=(virtual-228 virtual-229 virtual-230)
cluster_port=5600

local_tmpfile=/tmp/ebalancer_streamdata
target_outfile=/tmp/ebalancer_out


# Called with the data file to stream as the argument.
go ()
{
    read len _ <<< $(wc -l $1)
    cluster_len=${#cluster[@]}
    remote_datafile=/tmp/${1}


    ssh $source "$(typeset -f); check_datafile $remote_datafile"
    has_data=$?
    if [ $has_data -ne 0 ]; then
        echo "deploying stream data file... "
        scp $1 $source:$remote_datafile
        echo "done"
    fi

    ssh $target "$(typeset -f); await $(( $len * $cluster_len - $cluster_len)) $target_outfile" >$local_tmpfile &
    waitpid=$!

    # 16:17 < osse> entity: that's not how declare -p is meant to be used
    cluster_decl=$( declare -p hosts=(${cluster[@]}) )
    start_time=$(ssh $source "$cluster_decl; $(typeset -f); stream $remote_datafile $cluster_port")
    echo "stream finished, waiting for output (start_time=${start_time})"

    wait $waitpid
    end_time=$(cat $local_tmpfile)
    if [[ $end_time =~ [0-9]+$ ]]; then # See if we got a number back
        diff_time=$(( $end_time - $start_time ))
        echo "streamed $(( $len*$cluster_len )) messages in $(awk "BEGIN {printf \"%.2f\", $diff_time/1000}") seconds"
    else
        echo "target node says: $end_time"
    fi
}

# These functions will be called over ssh.

# Called with a filaname to check as the argument.
check_datafile ()
{
    if [ -e $1 ]; then
        return 0
    else
        return 1
    fi
}

# Called with a filename to stream from, the port cluster listens on
# and a filename containing array of cluster hosts that has been copied over.
stream ()
{
    echo `date +%s%3N`
    ncpids=()
    for host in ${hosts[@]}; do
        cat $1 | nc $host $2 &
        ncpids+=($!)
    done

    for pid in ${ncpids}; do wait $pid; done
    return 0
}

# Called with a port and out file arguments.
await_init ()
{
    command -v ncat >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Please install 'ncat' (*not* just nc) on the 'source' host (part of the nmap package, perhaps)"
    else
        nohup ncat -l -k $1 >$2 & >/dev/null
    fi
}

# Called with out file argument.
await_stop ()
{
    kill $(pidof ncat)
    rm $1
}

# Called with the amount of messages to wait for and the output file as the argument.
await ()
{
    echo -n "" >$2 # Reset the message output file
    max_time=$(( $(date +%s%3N) + $1/10 ))
    while true; do
        read len _ <<< $(wc -l $2)
        if [ $len -ge $1 ]; then
            echo -n $(date +%s%3N)
            break
        elif [ $(date +%s%3N) -gt $max_time ]; then
            echo "time limit reached, got only $len messages"
            break
        else
            sleep 0.01
        fi
    done
}


case $1 in
    "init")
    echo -n $(ssh $target "$(typeset -f); await_init $target_port $target_outfile")
    ;;
    "stop")
    ssh $target "$(typeset -f); await_stop $target_outfile"
    ;;
    "go")
    if [ "$2" != "" ]; then
        go $2
    else
        echo "missing argument: file with messages to stream"
    fi
    ;;
    *)
    echo "Usage:"
    echo "$0 init | stop | go <filename>"
    ;;
esac