#!/bin/bash

if  [[ $1 == "drastic-kk" ]]; then
    /usr/local/bin/drastic_kk.sh "$2"
else
    /usr/local/bin/drastic.sh "$2"
fi