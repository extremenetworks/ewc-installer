#! /bin/bash

set -eu

BROCADE_INSTALL_DIR="/opt/brocade"
BWC_SVC_NAME="bwc-topology"
BWC_INSTALL_DIR="${BROCADE_INSTALL_DIR}/${BWC_SVC_NAME}"
BWC_LOG_DIR="/var/log/brocade/bwc"
BWC_CONFIG_DIR="/etc/brocade/bwc"
BWC_CONFIG_FILE="${BWC_CONFIG_DIR}/bwc-topology-service.conf"
BWC_DB_SETUP_SCRIPT="${BWC_INSTALL_DIR}/bin/bwc_topology_db_setup.sh"
BWC_DB_PASSWORD=""
ST2_API_KEY=""


setup_args() {
  for i in "$@"
    do
      case $i in
          --bwc-db-password=*)
          BWC_DB_PASSWORD="${i#*=}"
          shift
          ;;
          --st2-api-key=*)
          ST2_API_KEY="${i#*=}"
          shift
          ;;
          *)
          # unknown option
          ;;
      esac
    done

    if [[ -z "${BWC_DB_PASSWORD}" ]]; then
        >&2 echo "ERROR: The --bwc-db-password option is not provided. Please provide a password to set for db access."
        exit 1
    fi

    if [[ -z "${ST2_API_KEY}" ]]; then
        echo "INFO: The --st2-api-key option is not provided. A new st2 API key will be created for bwc-topology."

        if [[ -z "${ST2_AUTH_TOKEN}" ]]; then
            >&2 echo "ERROR: Environment variable ST2_AUTH_TOKEN must be set to create new st2 API key."
            exit 1
        fi

        echo "INFO: Creating new st2 API key for ${BWC_SVC_NAME}..."
        ST2_API_KEY_DESC="{\"used_by\": \"${BWC_SVC_NAME}\"}"
        ST2_API_KEY=`st2 apikey create -k -m "${ST2_API_KEY_DESC}"`
    fi
}

echo "INFO: Parsing script input args..."
setup_args $@

echo "INFO: Ensuring ${BWC_SVC_NAME} service is not running..."
sudo service ${BWC_SVC_NAME} stop || true

if [ ! -e "${BWC_CONFIG_FILE}" ]; then
    >&2 echo "ERROR: The config file \"${BWC_CONFIG_FILE}\" does not exists."
    exit 1
fi

echo "INFO: Replacing the DB password in the connection string at the config file \"${BWC_CONFIG_FILE}\"..."
sudo sed -i -e "s/\(^connection\s*=\s*['\"]\?postgresql:\/\/.*:\).*\(@.*\)/\1${BWC_DB_PASSWORD}\2/" ${BWC_CONFIG_FILE}

echo "INFO: Replacing the StackStorm API key at the config file \"${BWC_CONFIG_FILE}\"..."
sudo sed -i -e "s/\(^st2_api_key\s*=\s*['\"]\).*\(['\"]\)/\1${ST2_API_KEY}\2/" ${BWC_CONFIG_FILE}

echo "INFO: Configuring BWC topology database..."
sudo ${BWC_DB_SETUP_SCRIPT}

echo "INFO: Updating ownership of log files generated by the DB setup script..."
sudo chown -R bwc:root ${BWC_LOG_DIR}

echo "INFO: Starting ${BWC_SVC_NAME} service..."
sudo service ${BWC_SVC_NAME} start
