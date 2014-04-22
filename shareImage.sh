#A little script to make it easier to transfer images around the team

echo Have you run an openrc.sh file to establish the necessary environment variables to
echo 'interact with the glance utility?(y/n)'
read confirmGlance

if [ $confirmGlance = "n" ]
then
	echo "Then do it!"
	exit 1
fi

echo Enter the id of the image you want to share:
read imageID

#Luke
glance member-create $imageID 3552e8fdc1914c5abca859aba6563691
#Hayden
glance member-create $imageID 7e76699705804cbc981a10a792d7ba20
#Mike
glance member-create $imageID 1575eb5f243c420ab932ad4f380d53c2
#Group
glance member-create $imageID 88dd0fc4955a4141b6ccc29fe14fd588
