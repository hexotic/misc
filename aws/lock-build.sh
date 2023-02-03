#!/bin/bash -ex

# arg 1: 1 -> lock, 0 -> unlock
# arg 2: build number (or something to identify where the lock has been taken)

export build="$2"

if [ x"$build" = x"" ]; then
    echo "Please provide build number"
    exit 1
fi

item="$(jq -c --arg buildN $build -n '{"build": {"N": "1"}, "LockID": {"S": "datanode"}, "BuildNumber": {"N": $buildN}}')"
export item

function get_lock {
    set -x
    aws dynamodb put-item --table-name datanode-lock --item "${item}" --condition-expression 'attribute_not_exists(build)'
}

export -f get_lock

if [ x"$1" = x"1" ]; then
    #timeout 300 bash -c 'until get_lock; do sleep 5; done' && echo "Lock taken"
    bash -c 'until get_lock; do sleep 5; done' && echo "Lock taken"
elif [ x"$1" = x"0" ]; then
    cond="$(jq -c --arg buildN $build -n '{ ":bn": {"N": $buildN}}')"
    aws dynamodb delete-item --table-name datanode-lock --key '{"LockID": { "S": "datanode" }}' \
        --condition-expression 'BuildNumber = :bn' \
        --expression-attribute-values "$cond"    \
        && echo "Lock released" || echo "Error occured or item might not exist"
else
    echo "Please provide 0 or 1 for lock/unlock"
    exit 1
fi
