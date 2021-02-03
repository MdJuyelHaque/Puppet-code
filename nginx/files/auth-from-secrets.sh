#!/bin/sh
AWS_SECRETS_COMMAND=/var/local/aws-get-secret.sh
AWS_CLI_SECRETS_PROFILE=$1
AWS_SECRETS_PATH=$2
AUTH_USERNAME=$3
AUTH_FILE_LOCATION=$4

# Get the secret key from the store
AUTH_PASSWORD=`${AWS_SECRETS_COMMAND} ${AWS_CLI_SECRETS_PROFILE} ${AWS_SECRETS_PATH} | jq ".\"${AUTH_USERNAME}\"" | sed 's/^"\(.*\)"$/\1/'`
if [ $? -ne 0 ] ; then
	echo "Error attempting to get key ${AWS_SECRETS_PATH}.${AUTH_USERNAME}" >&2
	exit 100
fi

if [ -e "${AUTH_FILE_LOCATION}" ]; then
	htpasswd -b ${AUTH_FILE_LOCATION} ${AUTH_USERNAME} ${AUTH_PASSWORD}
else
	htpasswd -b -c ${AUTH_FILE_LOCATION} ${AUTH_USERNAME} ${AUTH_PASSWORD}
fi
