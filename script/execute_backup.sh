#!/bin/bash
. /etc/profile
. /home/grockit/.profile

export PATH=/usr/local/bin:$PATH

NODE_ENV=production TZ=US/Pacific /opt/grockit/whistlepunk/shared/node_modules/.bin/coffee /opt/grockit/whistlepunk/current/script/stop_whistlepunk_and_dump_status.coffee