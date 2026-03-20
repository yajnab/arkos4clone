#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2024-present AmberELEC (https://github.com/AmberELEC)

if [[ $(tr -d '\r\n\t ' </boot/.console 2>/dev/null | tr 'A-Z' 'a-z') == "d007" ]]; then
    DEVICE_FILE="/dev/input/by-path/platform-d007-keys-event-joystick"
    PYTHON=/usr/bin/python3

    while true; do
        evtest --grab "$DEVICE_FILE" | while read -r line; do
            if [[ $line == *"BTN_BACK"* ]]; then
                if [[ $line == *"value 1"* ]]; then
                    $PYTHON /usr/local/bin/adckeys.py startselect_press
                elif [[ $line == *"value 0"* ]]; then
                    $PYTHON /usr/local/bin/adckeys.py startselect_release
                fi
            elif [[ $line == *"BTN_SELECT"* ]]; then
                if [[ $line == *"value 1"* ]]; then
                    $PYTHON /usr/local/bin/adckeys.py select_press
                elif [[ $line == *"value 0"* ]]; then
                    $PYTHON /usr/local/bin/adckeys.py select_release
                fi
            elif [[ $line == *"BTN_START"* ]]; then
                if [[ $line == *"value 1"* ]]; then
                    $PYTHON /usr/local/bin/adckeys.py start_press
                elif [[ $line == *"value 0"* ]]; then
                    $PYTHON /usr/local/bin/adckeys.py start_release
                fi
            fi
        done
    done
fi
