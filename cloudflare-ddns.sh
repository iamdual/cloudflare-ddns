#!/bin/bash
# Cloudflare Dynamic DNS is keeps server's IP address constantly being updated in the DNS records.
# Author  : Ekin Karadeniz (iamdual@icloud.com)
# Link    : https://github.com/iamdual/cloudflare-ddns
# Version : 2022-07-29

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
DEBUG=0

for arg in "$@"; do
  if [ "$arg" = "--ipv6" ]; then TYPE="AAAA"; fi
  if [ "$arg" = "--proxy" ]; then PROXY="true"; fi
  if [ "$arg" = "--debug" ]; then DEBUG=1; fi
done

services=(
  "https://checkip.amazonaws.com/"
  "https://icanhazip.com/"
  "https://ifconfig.me/ip"
)
for service in "${services[@]}"; do
  PUBLIC_IP=$(curl --silent --max-time 2 "$service" | xargs)
  if [ -n "$PUBLIC_IP" ]; then
    break
  fi
done

if [ "$DEBUG" -eq 1 ]; then
  printf "Public IP detected: %s\n\n" "$PUBLIC_IP"
fi

# List DNS records
dns_records=$(curl --silent --request GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN")

if [ "$DEBUG" -eq 1 ]; then
  printf "Response of DNS records: \n%s\n\n" "$dns_records"
fi

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

  # Create a DNS record if no record found

  output_to="/dev/null"
  if [ "$DEBUG" -eq 1 ]; then
    output_to="/tmp/.debug-createRecord"
  fi

  result=$(curl --silent --request POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    --header 'Content-Type: application/json' \
    --data-raw "{\"type\":\"$TYPE\",\"name\":\"$DOMAIN\",\"content\":\"$PUBLIC_IP\",\"ttl\":1,\"proxied\":$PROXY}" \
    --output "$output_to" --write-out "%{http_code}")

  if [ "$result" = "200" ]; then
    echo "Record created successfully."
    exit 0
  else
    echo "Record cannot be created!"
    if [ "$DEBUG" -eq 1 ]; then
      printf "\nResponse of the create DNS record: \n%s\n" "$(cat $output_to)"
    fi
  fi

else

  # Update the DNS record

  output_to="/dev/null"
  if [ "$DEBUG" -eq 1 ]; then
    output_to="/tmp/.debug-updateRecord"
  fi

  result=$(curl --silent --request PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    --header 'Content-Type: application/json' \
    --data-raw "{\"type\":\"$TYPE\",\"name\":\"$DOMAIN\",\"content\":\"$PUBLIC_IP\",\"ttl\":1,\"proxied\":$PROXY}" \
    --output "$output_to" --write-out "%{http_code}")

  if [ "$result" = "200" ]; then
    echo "Record updated successfully."
    exit 0
  else
    echo "Record cannot be updated!"
    if [ "$DEBUG" -eq 1 ]; then
      printf "\nResponse of the update DNS record: \n%s\n" "$(cat $output_to)"
    fi
  fi

fi

exit 1
