#Cleanup
rm raw_out compare changes updates dl_links 2> /dev/null


#Check if db exist
if [ -e subjects_db ]
then
    mv subjects_db subjects_db_old
else
    echo "DB not found!"
fi

#Fetch
echo Fetching updates:
cat subjects.txt | while read subject; do
	info=`curl -s $subject | grep 'pl-video yt-uix-tile' | tail -1`
	name=$(echo $info | awk -F 'data-title="' '{print $2}' | cut -d '"' -f1 | awk -F ' - ' '{print $2}')
	lecture=$(echo $info | awk -F 'data-title="' '{print $2}' | cut -d '"' -f1 | awk -F ' - ' '{print $1}')
	id=$(echo $info | awk -F 'data-video-id="' '{print $2}' | cut -d '"' -f1)
	link=$(echo https://www.youtube.com/watch?v=$id)
	echo $name"="$lecture"="\"$link\" >> raw_out
done
cat raw_out | sort | cut -d = -f1,2 > subjects_db
#Compare
echo Comparing:
cat subjects_db | while read lecture; do
	name=$(echo $lecture | cut -d = -f1 | head -1)
	new=`cat subjects_db | grep "$name"`
	old=`cat subjects_db_old | grep "$name"`
	diff <(echo "$old") <(echo "$new") | grep ^"<\|>" >> compare
done
awk '!seen[$0]++' compare > changes

#Info
if [ -s changes ]
then
	echo "Here's the new lectures!"
	cat changes | grep ">" | cut -d ">" -f2 | sed 's/ //1' | tee updates
else
    echo "No changes found!"
fi

#Downloads
if [ -s updates ]
then
    echo "Download Links!"
    cat updates | while read lecture; do cat raw_out | grep "$lecture" ; done 2>&1 | tee dl_links
else
    echo "No new lectures!"
fi

if [ -s dl_links ]
then
#YT
cat dl_links | while read line; do url=$(echo $line | cut -d '"' -f2); youtube-dl -f 17 $url --ignore-errors; done

#Telegram
cat dl_links | while read line; do
	subject=$(echo $line | cut -d = -f1)
	lecture=$(echo $line | cut -d = -f2)
	link=$(echo $line | cut -d '"' -f2)
	./telegram -t $BOTTOKEN -c -1001160410225 -M "محاضرة جديدة متوفرة!
	*المادة*: $subject
	$lecture
	*يوتيوب*:
	*المشاهدة*: [هنا]($link)
	"
done
for file in *.3gp; do ./telegram -t $BOTTOKEN -c -1001160410225 -f $file; done

#Push
git add subjects_db; git -c "user.name=Travis CI" -c "user.email=builds@travis-ci.com" commit -m "Sync: $(date +%d.%m.%Y)"
git push -q https://$GIT_OAUTH_TOKEN@github.com/ninetrackers/zad.git HEAD:yt

else
    echo "Nothing to do!"
fi
