#!/bin/bash
# Check if the script is run as root
if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Function to validate IP address
validate_ip() {
    local ip="$1"
    local valid_ip_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    if [[ $ip =~ $valid_ip_regex ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet < 0 || octet > 255)); then
                echo "Invalid IP address: $ip"
                exit 1
            fi
        done
    else
        echo "Invalid IP address format: $ip"
        exit 1
    fi
}

# Prompt for IP addresses and validate
read -p "Enter Wazuh Indexer IP: " INDEXER_IP
validate_ip "$INDEXER_IP"

read -p "Enter Wazuh Manager IP: " MANAGER_IP
validate_ip "$MANAGER_IP"

read -p "Enter Wazuh Dashboard IP: " DASHBOARD_IP
validate_ip "$DASHBOARD_IP"

# Download installation script and configuration file
curl -sO https://packages.wazuh.com/4.10/wazuh-install.sh
curl -sO https://packages.wazuh.com/4.10/config.yml

# Update configuration file with provided IPs
sed -i "s|<indexer-node-ip>|$INDEXER_IP|g" config.yml
sed -i "s|<wazuh-manager-ip>|$MANAGER_IP|g" config.yml
sed -i "s|<dashboard-node-ip>|$DASHBOARD_IP|g" config.yml

# Generate configuration files
bash wazuh-install.sh --generate-config-files -i

# Perform full installation and capture output
INSTALL_OUTPUT=$(bash ./wazuh-install.sh -a -i -o)

# Extract User and Password from the installation output using sed
CREDENTIALS_FILE="wazuh_admin_credentials.txt"
echo "$INSTALL_OUTPUT" | sed -n -e 's/^[[:space:]]*User: \(.*\)$/User=\1/p' \
                                 -e 's/^[[:space:]]*Password: \(.*\)$/Password=\1/p' > "$CREDENTIALS_FILE"

# Check if credentials were successfully extracted and saved
if [[ -s "$CREDENTIALS_FILE" ]]; then
    echo "Wazuh installation completed successfully!"
    echo "Admin credentials saved to $CREDENTIALS_FILE"
else
    echo "Failed to extract admin credentials from the installation output."
    exit 1
fi
