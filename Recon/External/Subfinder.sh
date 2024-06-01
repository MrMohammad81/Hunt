source ~/.profile

blue="\033[34m"
reset="\033[0m"

read -p "[+] - Enter your program name: " programName
bbrf new "$programName"
bbrf use "$programName"
bbrf enable "$programName"

read -p "[+] - Enter your scope : " domainScope
bbrf inscope add "$domainScope"

echo -e "${blue}[+] - Program add to BBRF Server ${reset}"

read -p "[+] - Enter your domain: " domain

#Run subfinder
echo -e "${blue}[+] - Runnig Subfinder...${reset}"
subfinder=$(subfinder -d "$domain" -all -silent | tee -a subfinder.txt)
clear

#Run Github-search
echo -e "${blue}[+] - Running Github Search...${reset}"
github-subdomains=$(github-subdomains -d "$domain" -q -o git.txt)
clear

#Web Archive search
echo -e "\e[32m[+] - WebArchive Search...\e[0m"
curl "https://web.archive.org/cdx/search/cdx?url=*.$domain&collaps=urlkey&fl=original" -s |cut -d "/" -f3 | cut -d ":" -f1 sort -u >> subfinder.txt
clear

#Crtsh Search
echo -e "\e[32m[+] - Crtsh Search...\e[0m"
curl -s "https://crt.sh/?q=$domain&output=json" | jq -r ".[].name_value" | sort -u >> subfinder.txt
clear

#Urlscan
echo -e "\e[32m[+] - URLSccan Search... \e[0m"
curl "https://urlscan.io/api/v1/search/?q=domain:$domain" -s | jq -r ".results[].task.domain" | sort -u >> subfinder.txt
clear

#rapiddns
echo -e "\e[32m[+] - Rapiddns Search... \e[0m"
curl -s "https://rapiddns.io/s/$domain?full=1&down=1#result" | grep "<td>.*\..*\..*</td>" | sed -E "s/<\/?td>//g" | sed -E "s/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}//g" >> subfinder.txt
clear

# Sequrity Trails 
echo -e "\e[32m[+] - Sequrity Trails  Search... \e[0m"
curl "https://api.securitytrails.com/v1/domain/$domain/subdomains?children_only=false&include_inactive=true" --header 'APIKEY: Z8nR4V50-qcRZrpcU5jume-Xg9WDMi6r' --header 'accept: application/json' -s | jq -r ".subdomains[]" | tee -a trails-subs.txt
python3 /usr/local/tools/subbrute/subbrute.py trails-subs.txt $domain >> subfinder.txt
rm trails-subs.txt
clear

#Merge subdomains
echo -e "\e[32m[+] - Merging Subdomains... \e[0m"
cat git.txt subfinder.txt| sort -u | tee -a all-subs.txt
rm subfinder.txt git.txt
clear

#DNS Resolve
echo -e "\e[32m[+] - Check Rescolve subdomains...\e[0m"
massdns -r /usr/local/resolver.txt -q -t A all-subs.txt -o S | cut -d " " -f1 | sed "s/\.$//g" | sort -u | tee -a sub-resolves1.txt
rm all-subs.txt
clear

#Run DNSGen
echo -e "\e[32m[+] - Run DNSGen...\e[0m"
cat sub-resolves1.txt | dnsgen -f - | sort -u | tee -a DNSGen.txt
clear

#DNS Resolve On DNSGen Output
# DNS 4.2.2.4 and 8.8.8.8
echo -e "\e[32m[+] - Check DNS Resolve On DNSGen Output...\e[0m"
massdns -r /usr/local/resolver.txt -q -t A DNSGen.txt -o S | cut -d " " -f1 | sed "s/\.$//g" | sort -u | tee -a sub-resolves-dnsgen.txt
rm DNSGen.txt
cat sub-resolves1.txt sub-resolves-dnsgen.txt | sort -u | tee -a all-sub-resolves.txt
rm sub-resolves1.txt sub-resolves-dnsgen.txt 
clear

#Add to bbrf server
echo -e "\e[32m[+] - Adding domains to BBRF Server...\e[0m"
cat all-sub-resolves.txt | dnsx -a -silent -resp -nc | sed 's/\s*\[A\]//g' | cut -d "]" -f1  | sed "s/\[//g"| awk '{print $1":"$2}' | bbrf -p $programName  domain add - --show-new | tee -a new-sub-resolves.txt
bbrf alert new-sub-resolves.txt
rm new-sub-resolves.txt
clear

#Run Httpx
echo -e "\e[32m[+] - Run HTTPX...\e[0m"
bbrf -p $programName domains --resolved | httpx -sc -follow-host-redirects -td -title -probe -cdn -tech-detect -random-agent -ip -no-color -p 80,443 | tee -a HTTPx-subs.txt
clear

# Add status code to domain in BBRF server
cat HTTPx-subs.txt | grep -E '\[([200]+)\]' | cut -d "/" -f3 | cut -d " " -f1 | bbrf -p $programName domain update - -t status:200 --show-new | tee -a new-200-subs.txt
bbrf alert new-200-subs.txt
clear

cat HTTPx-subs.txt | grep -E '\[([301]+)\]' | cut -d "/" -f3 | cut -d " " -f1 | bbrf -p $programName domain update - -t status:301 --show-new | tee -a new-301-subs.txt
bbrf alert new-301-subs.txt
clear

cat HTTPx-subs.txt | grep -E '\[([302]+)\]' | cut -d "/" -f3 | cut -d " " -f1 | bbrf -p $programName domain update - -t status:302 --show-new | tee -a new-302-subs.txt
bbrf alert new-302-subs.txt
clear

cat HTTPx-subs.txt | grep -E '\[([400]+)\]' | cut -d "/" -f3 | cut -d " " -f1 | bbrf -p $programName domain update - -t status:400 --show-new | tee -a new-400-subs.txt
bbrf alert new-400-subs.txt
clear

cat HTTPx-subs.txt | grep -E '\[([403]+)\]'| cut -d "/" -f3 | cut -d " " -f1 | bbrf -p $programName domain update - -t status:403 --show-new | tee -a new-403-subs.txt
bbrf alert new-403-subs.txt
clear

cat HTTPx-subs.txt | grep -E '\[([404]+)\]' | cut -d "/" -f3 | cut -d " " -f1 | bbrf -p $programName domain update - -t status:404 --show-new | tee -a new-404-subs.txt
bbrf alert new-404-subs.txt
clear

cat HTTPx-subs.txt | grep -E '\[([409]+)\]' | cut -d "/" -f3 | cut -d " " -f1 | bbrf -p $programName domain update - -t status:409 --show-new | tee -a new-409-subs.txt
bbrf alert new-409-subs.txt
clear

cat HTTPx-subs.txt | grep -E '\[([501]+)\]' | cut -d "/" -f3 | cut -d " " -f1 | bbrf -p $programName domain update - -t status:501 --show-new | tee -a new-501-subs.txt
bbrf alert new-501-subs.txt
clear

cat HTTPx-subs.txt | grep -E '\[([503]+)\]' | cut -d "/" -f3 | cut -d " " -f1 | bbrf -p $programName domain update - -t status:503 --show-new | tee -a new-503-subs.txt
bbrf alert new-503-subs.txt
clear


# Check file
echo -e "\e[32m[+] - ASN Check...\e[0m"
bbrf -p $programName domains --resolved | tee -a sub-resolves.txt
if [ -f sub-resolves.txt ]; then
  while IFS= read -r subdomain; do
    echo "Checking $subdomain"
  
    # Run dig on subdomains
    for OUTPUT in $(dig +short a "$subdomain"); do
      echo -e "\e[95mIP ADDRESS: $OUTPUT \e[0m"

			echo -e "\e[32mHost Info: "
      host "$OUTPUT" | grep "domain"
      echo -e "\e[0m"
    
      # Write in output
      whois -h whois.cymru.com "$OUTPUT" >> ASN-CHECK.txt

			host "$OUTPUT" | grep domain >> ASN-CHECK.txt
    done

    echo "---------------------------" >> ASN-CHECK.txt
  done < sub-resolves.txt

  echo -e "\e[32mSave results in ASN-CHECK.txt\e[0m"
else
  echo "The file all-subs.txt does not exist or was entered incorrectly."
fi