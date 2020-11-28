#!/bin/bash
export HYPERCLOUD4_CA_CERT=$(openssl base64 -A <"${HPCD_HOME}/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/pki/ca.crt")

AUDIT_CONFIG_FILE=06_audit-webhook-config
if [ -f "$AUDIT_CONFIG_FILE" ]; then
   echo "Remove existed audit config file."
   rm $AUDIT_CONFIG_FILE
fi

echo "Generate audit config file."
envsubst < ${HPCD_HOME}/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/"$AUDIT_CONFIG_FILE".template  > "$AUDIT_CONFIG_FILE"
