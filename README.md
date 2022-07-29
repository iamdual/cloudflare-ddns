# Cloudflare Dynamic DNS
Cloudflare Dynamic DNS is keeps server's IP address constantly being updated in the DNS records.

## Usage
```bash
export CLOUDFLARE_API_TOKEN="CLOUDFLARE-API-TOKEN"

./cloudflare-ddns.sh "ZONE-ID" "DOMAIN-NAME"
./cloudflare-ddns.sh "ZONE-ID" "DOMAIN-NAME"
...
```

### Parameters
* `--ipv6`: Set IP address format IPv6
* `--proxy`: Enable proxy for DNS record
* `--debug`: Enable debug
```bash
./cloudflare-ddns.sh "ZONE-ID" "DOMAIN-NAME" --ipv6
```

## Sources
- API documentation: https://api.cloudflare.com/