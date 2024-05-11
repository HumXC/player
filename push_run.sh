#!/usr/bin/env sh
adb push ./app-debug.apk /data/local/tmp/yuka && ./run.sh "$@"
