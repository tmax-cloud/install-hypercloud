#!/bin/bash

export HYPERCLOUD4_CA_CERT=$(openssl base64 -A <"${HPCD_HOME}/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/pki/ca.crt")

WEBHOOK_CONFIG_FILE=03_webhook-configuration.yaml
if [ -f "$WEBHOOK_CONFIG_FILE" ]; then
   echo "Remove existed webhook config file."
   rm $WEBHOOK_CONFIG_FILE
fi

echo "Generate webhook config file."
envsubst < ${HPCD_HOME}/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/"$WEBHOOK_CONFIG_FILE".template  > "$WEBHOOK_CONFIG_FILE"
