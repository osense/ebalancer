#!/bin/bash

if [ "$1" == 'balancer' ]; then
    erl -pa ebin -boot start_sasl -sname ebalancer -s ebalancer_app start balancer
else
    erl -pa ebin -boot start_sasl -sname w -s ebalancer_app start worker
fi
