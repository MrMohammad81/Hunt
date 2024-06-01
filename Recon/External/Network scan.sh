source ~/.profile

read -p "Enter your program name: " programName

read -p "Enter your Comapny Name: {Exaple: Dell} " domain

#Take ASN from BGP.he.net
echo -e "\e[32m[+]-Find ASNs from BGP.he\e[0m"
curl -s "https://bgp.he.net/search?search%5Bsearch%5D=$domain+inc&commit=Search" -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/118.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H "Referer: https://bgp.he.net/dns/$domain.com" -H 'Connection: keep-alive' -H 'Cookie: _gcl_au=1.1.68502336.1698219733; __utma=83743493.2038759511.1698219734.1698219734.1698219734.1; __utmb=83743493.4.10.1698219734; __utmc=83743493; __utmz=83743493.1698219734.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)' -H 'Upgrade-Insecure-Requests: 1' -H 'Sec-Fetch-Dest: document' -H 'Sec-Fetch-Mode: navigate' -H 'Sec-Fetch-Site: same-origin' -H 'Sec-Fetch-User: ?1' -H 'Pragma: no-cache' -H 'Cache-Control: no-cache' | grep -o -P '<td><a href="/AS[0-9]{5}">AS[0-9]{5}</a></td><td>ASN</td>' | awk -F'AS' '{print "AS" $2}' | cut -d '"' -f1 | tee -a ASN-$domain.txt
clear

#  take asn from bgpviwe
echo -e "\e[32m[+]-Find ASNs from bgpview \e[0m"
curl -s "https://api.bgpview.io/search?query_term=$domain" | jq ".data.asns[].asn" | sed 's/^/AS/' >> ASN-$domain.txt
clear

# Take IPv4 from BGP.he.net
echo -e "\e[32m[+]-Find IPs BGP.he\e[0m"
curl -s "https://bgp.he.net/search?search%5Bsearch%5D=$domain+inc&commit=Search" -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/118.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H "Referer: https://bgp.he.net/dns/$domain.com" -H 'Connection: keep-alive' -H 'Cookie: _gcl_au=1.1.68502336.1698219733; __utma=83743493.2038759511.1698219734.1698219734.1698219734.1; __utmb=83743493.4.10.1698219734; __utmc=83743493; __utmz=83743493.1698219734.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)' -H 'Upgrade-Insecure-Requests: 1' -H 'Sec-Fetch-Dest: document' -H 'Sec-Fetch-Mode: navigate' -H 'Sec-Fetch-Site: same-origin' -H 'Sec-Fetch-User: ?1' -H 'Pragma: no-cache' -H 'Cache-Control: no-cache' | grep -o -P '\d+\.\d+\.\d+\.\d+/\d+' | tee -a IPv4.txt
clear

#take IPv4 from bgpview
echo -e "\e[32m[+]-Find IPs from bgpview\e[0m"
curl "https://api.bgpview.io/search?query_term=$domain" -s -H 'Cookie: _ga=GA1.2.2003716020.1698244730; _ga_7YFHLCZHVM=GS1.2.1698244736.1.1.1698244770.26.0.0'  | jq ".data.ipv4_prefixes[].prefix"  | cut -d '"' -f2 >> IPv4.txt
clear

# Take IPs from ASN
echo -e "\e[32m[+]-Find IPs from ASNs\e[0m"
cat ASN-$domain.txt | sort -u | tee -a ASNs.txt
rm ASN-$domain.txt
clear

# Save IPs in Database
cat ASNs.txt | while read line; do curl -s "https://bgp.he.net/$line#_prefixes" -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/118.0' | sed "s/\t//g" | cut -d ">" -f2 | grep "^[0-9].*[</a>]$" | cut -d "<" -f1; done | tee -a IP-ASN.txt
cat IPv4.txt IP-ASN.txt | sort -u | tee -a $domain-CIDRs.txt
rm IPv4.txt IP-ASN.txt
cat $domain-CIDRs.txt | cut -d "/" -f1 | bbrf -p $programName ip add - --show-new | tee -a new-IP.txt
clear

# Revers whois of ORGId
for ip in $(cat $domain-CIDRs.txt | sort -u | cut -d "/" -f1); do whois  $ip | awk -F': ' '/OrgId/ {print $2}' | tee -a org-id.txt ; done

# Revers whois of netnames
for orgId in $(cat org-id.txt | sort -u); do curl -s "https://rdap.arin.net/registry/entity/$orgId" | jq -r ".networks[].handle" | tee -a netNames.txt; done

# Find CIDRs
for netName in $(cat netNames.txt | sort -u); do whois -h whois.arin.net -- "n ! $netName" | awk -F ': ' '/CIDR/ {print $2 }' | tee -a $domain-CIDRs.txt; done
cat $domain-CIDRs.txt | sort -u | tee -a CIDRs.txt
rm org-id.txt netNames.txt $domain-CIDRs.txt

# Port scan
awk -F'[/,]' '{for (i=2; i<=NF; i+=2) if ($i >= 19) print $1"/"$i}' CIDRs.txt | awk -F'[/,]' '{for (i=2; i<=NF; i+=2) print $1"/"$i}' | mapcidr -f4 -o IPs.txt
rm CIDRs.txt
smap -sV -iL IPs.txt -oP passed-IPs.txt
cat passed-IPs.txt | bbrf -p $programName ip add - --show-new >> new-IP.txt

# Run HTTPX 
httpx -l passed-IPs.txt -sc -follow-host-redirects -td -title -probe -tech-detect -random-agent -no-color | tee -a Passed-IPs-Httpx.txt

  for ip in $(cat IPs.txt); do
    	echo -e "\e[32mHost Info: $ip "
      	host  "$ip" | grep domain
      	echo -e "\e[0m"
        echo "---------------------------" >> $domain-Host-Check.txt
  	done
clear
