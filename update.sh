#!/bin/bash
pushd . >/dev/null
pushd `dirname $0` > /dev/null
export SCRIPTDIR=`pwd`
popd > /dev/null

cd "$SCRIPTDIR"
export LGREEN='\033[1;32m'
export RED='\033[0;31m'
export NC='\033[0m' # No Color

git remote -v|grep "upstream" >/dev/null 2>/dev/null
if [ $? -eq 1 ]
then
echo -e "${RED}ERROR${NC}: You must run first_time_setup.sh first to set everything up correctly!"
exit 1
fi

git fetch upstream
if [ $? -eq 1 ]
then
echo -e "${RED}ERROR${NC}: Couldn't update upstream-git, is Internet-connection working?"
exit 1
fi

git merge upstream/master --no-edit
if [ $? -eq 1 ]
then
echo -e "${RED}ERROR${NC}: Couldn't merge changes from upstream-git!"
exit 1
fi

scripts/feeds update -a
if [ $? -eq 1 ]
then
echo -e "${RED}ERROR${NC}: Couldn't update package-list, is Internet-connection working?"
exit 1
fi

#Ugly fix for several packages
#Onion-devs don't give a fuck
onionNeedCommit=0
find feeds/onion -iname "Makefile" | while read filename
do
githubUrl=$(grep "git@github.com" "$SCRIPTDIR/$filename")
if [ $? -eq 0 ]
then
githubUrl=$(echo "$githubUrl"|sed 's/git@github.com:/https:\/\/github.com\//'|sed 's/\.git//'|cut -d '=' -f 2-)
curl --output /dev/null --silent --head --fail "$githubUrl"
if [ $? -eq 0 ]
then
echo "Patching $filename..."
sed -i 's/git@github.com:/https:\/\/github.com\//' "$SCRIPTDIR/$filename"
onionNeedCommit=1
fi
fi
done

scripts/feeds install -a
make defconfig
