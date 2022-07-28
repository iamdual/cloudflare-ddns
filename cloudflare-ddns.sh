#!/bin/bash
# Cloudflare Dynamic DNS is keeps server's IP address constantly being updated in the DNS records.
# Author: Ekin Karadeniz (iamdual@icloud.com)
# Link  : https://github.com/iamdual/cloudflare-ddns

which curl &>/dev/null
if [ $? -ne 0 ]; then
  echo "Please make sure that cURL is installed on the system."
  exit 1
fi

if [ $# -lt 2 ]; then
  echo "Usage: cloudflare-ddns.sh {zone-id} {domain-name}"
  exit 1
fi

if [ "$CLOUDFLARE_API_TOKEN" = "" ]; then
  echo "Please set CLOUDFLARE_API_TOKEN environment value."
  exit 1
fi

ZONE_ID=$1
DOMAIN=$2

TYPE="A"
PROXY="false"

for arg in "$@"; do
  if [ "$arg" = "--ipv6" ]; then TYPE="AAAA"; fi
  if [ "$arg" = "--proxy" ]; then PROXY="true"; fi
done

PUBLIC_IP=$(curl --silent "https://checkip.amazonaws.comm/" | xargs)
if [ "$PUBLIC_IP" = "" ]; then
  PUBLIC_IP=$(curl --silent "https://ifconfig.me/" | xargs)
fi

# List DNS records
dns_records=$(curl --silent --request GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN")

# Obtain the DNS record ID from the API response
RECORD_ID=""
dns_records_regex='"id":"([^"]+)","zone_id":"[^"]+","zone_name":"[^"]+","name":"([^"]+)","type":"([^"]+)"'
dns_records_matches=$(echo "$dns_records" | grep -oE "$dns_records_regex")
while IFS= read -r match; do
  [[ $match =~ $dns_records_regex ]]
  if [ "$DOMAIN" = "${BASH_REMATCH[2]}" ] && [ "$TYPE" = "${BASH_REMATCH[3]}" ]; then
    RECORD_ID=${BASH_REMATCH[1]}
  fi
done < <(echo "$dns_records_matches")

if [ "$RECORD_ID" = "" ]; then
  echo "No DNS record ID found. Make sure the domain name is correct."
  exit 1
fi

# Update the DNS record
curl --silent --request PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  --header 'Content-Type: application/json' \
  --data-raw "{\"type\":\"$TYPE\",\"name\":\"$DOMAIN\",\"content\":\"$PUBLIC_IP\",\"ttl\":1,\"proxied\":$PROXY}"
