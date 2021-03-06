#!/usr/bin/env bash

set -e

: ${AZURE_APPLICATION_SECURITY_GROUP_TESTS_ENABLED:?}

if [ "${AZURE_APPLICATION_SECURITY_GROUP_TESTS_ENABLED}" == "false" ]; then
  echo "Azure Application Security Group related tests are disabled. Exit 0."
  exit 0
fi

: ${AZURE_ENVIRONMENT:?}
: ${AZURE_SUBSCRIPTION_ID:?}
: ${AZURE_CLIENT_ID:?}
: ${AZURE_CLIENT_SECRET:?}
: ${AZURE_TENANT_ID:?}
: ${AZURE_APPLICATION_SECURITY_GROUP_NAME:?}

: ${METADATA_FILE:=environment/metadata}

metadata=$(cat ${METADATA_FILE})

az cloud set --name ${AZURE_ENVIRONMENT}
az login --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
az account set -s ${AZURE_SUBSCRIPTION_ID}

default_resource_group_name=$(echo ${metadata} | jq -e --raw-output ".default_resource_group_name")
az network asg delete --resource-group ${default_resource_group_name} --name ${AZURE_APPLICATION_SECURITY_GROUP_NAME}
