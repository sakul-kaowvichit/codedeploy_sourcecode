#!/bin/bash

hostname=$(hostname)

if [[ ${hostname} =~ 'brain' ]]; then
    echo 'INFO: this is a brain.  start killing queue workers..'
    ps aux | pgrep -f "artisan queue:listen" | xargs -r kill

    echo 'INFO: checking to see if queue worker are still running'
    if ps aux | pgrep -f "artisan queue:listen" ; then
        echo 'ERROR: queue workers are running.  look like we have problem stopping the queue workers' >&2
        exit 1
    else
        echo 'INFO: we are good...no queue workers running'
    fi
else
    echo 'INFO: this is a not a brain.  there is nothing to do in this step..'
fi

