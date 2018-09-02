#curl -s --cookie file.txt url
#Cleanup
rm raw_out compare changes updates dl_links 2> /dev/null

curl -H "PRIVATE-TOKEN: $GITLAB_OAUTH_TOKEN_VE" 'https://gitlab.com/api/v4/projects/6520353/repository/files/zadcookies.txt/raw?ref=master' -o zadcookies.txt

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
	info=`wget -qq --load-cookies zadcookies.txt $subject -O page`
	name=$(cat page | grep title | head -1 | cut -d ':' -f2 | cut -d '<' -f1 | sed 's/ //1')
	sub=$(cat page | grep 'multilang' | tail -6 | head -1 | cut -d '>' -f2 | cut -d '<' -f1 | sed 's/ //g')
	lecture=$(cat page | grep "section img-text" | tr '"' '\n' | grep 'المحاضرة' |  head -1)
	num=$(echo $lecture | grep -Po '[0-9]*')
	sound=$(echo https://resources.zad-academy.com/Semester2/$sub/Audios/Lecture$num"_"$sub"_"Semester2.mp3)
	yt=$(cat page | grep "section img-text" | tr '"' '\n' | grep 'https://www.youtube.com/embed/' | tail -1)
	echo $name"="$lecture"="\"$sound\" \"$yt\" >> raw_out
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

#Telegram
cat dl_links | while read line; do
	subject=$(echo $line | cut -d = -f1)
	lecture=$(echo $line | cut -d = -f2)
	sound=$(echo $line | cut -d '"' -f2)
	size_sound=$(wget --spider $sound --server-response -O - 2>&1 | sed -ne '/Length:/{s/*. //;p}' | tail -1 | cut -d '(' -f2 | cut -d ')' -f1)
	yt=$(echo $line | cut -d '"' -f4)
	./telegram -t $BOTTOKEN -c -1001160410225 -M "محاضرة جديدة متوفرة!
	*المادة*: $subject
	$lecture
	*ملف صوتي*:
	*التحميل*: [هنا]($sound)
	*الحجم*: $size_sound
	*يوتيوب*:
	*المشاهدة*: [هنا]($yt)
	"
done

#Push
git add subjects_db; git -c "user.name=Travis CI" -c "user.email=builds@travis-ci.com" commit -m "Sync: $(date +%d.%m.%Y)"
git push -q https://$GIT_OAUTH_TOKEN@github.com/ninetrackers/zad.git HEAD:master
