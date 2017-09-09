#!/bin/bash
pushd . >/dev/null
pushd `dirname $0` > /dev/null
export SCRIPTDIR=`pwd`
popd > /dev/null

cd "$SCRIPTDIR"
export LGREEN='\033[1;32m'
export RED='\033[0;31m'
export NC='\033[0m' # No Color

which apt >/dev/null
if [ $? -eq 1 ]
then
echo -e "${LGREEN}If compilation fails, please, do make sure you have${NC}"
echo -e "${LGREEN}the packages git libncurses5-dev build-essential gawk zlib1g-dev${NC}"
echo -e "${LGREEN}or their equivalents for your distro installed.${NC}"
sleep 10
else
echo -e "${LGREEN}Checking for required dependencies...${NC}"
for x in "git libncurses5-dev build-essential gawk zlib1g-dev"
do
dpkg -s $x >/dev/null 2>/dev/null
if [ $? -eq 1 ]
then
echo -e "${LGREEN}Installing $x...${NC}"
sudo apt -y install $x
fi
done
if [ $? -eq 1 ]
then
echo -e "${RED}Error installing dependencies, exiting!${NC}"
exit 1
fi
fi

git config --get user.email >/dev/null
if [ $? -eq 1 ]
then
echo
echo -e "${LGREEN}Git insists on certain variables to be set and we need git${NC}"
echo -e "${LGREEN}working, in order to build LEDE. If you don't intend to use${NC}"
echo -e "${LGREEN}git for your own development, you can set the variables to${NC}"
echo -e "${LGREEN}bogus values with the following two lines:${NC}"
echo -e "${LGREEN}git config --global user.email bogus${NC}"
echo -e "${LGREEN}git config --global user.name bogus${NC}"
echo
echo -e "${LGREEN}Once set, run this script again in order to continue.${NC}"
exit 1
fi

git config --get user.name >/dev/null
if [ $? -eq 1 ]
then
echo
echo -e "${LGREEN}Git insists on certain variables to be set and we need git${NC}"
echo -e "${LGREEN}working, in order to build LEDE. If you don't intend to use${NC}"
echo -e "${LGREEN}git for your own development, you can set the variables to${NC}"
echo -e "${LGREEN}bogus values with the following two lines:${NC}"
echo -e "${LGREEN}git config --global user.email bogus${NC}"
echo -e "${LGREEN}git config --global user.name bogus${NC}"
echo
echo -e "${LGREEN}Once set, run this script again in order to continue.${NC}"
exit
fi

git remote|grep "upstream" >/dev/null
if [ $? -eq 1 ]
then
git remote add upstream https://github.com/lede-project/source.git
fi

git fetch upstream
git merge upstream/master --no-edit
if [ $? -eq 1 ]
then
echo -e "${LGREEN}Merging from upstream failed, please, fix the problem and re-run the script.${NC}"
exit 1
fi
grep "src-git onion https://github.com/OnionIoT/OpenWRT-Packages.git" feeds.conf.default > /dev/null
if [ $? -eq 1 ]
then
echo "src-git onion https://github.com/OnionIoT/OpenWRT-Packages.git" >> feeds.conf.default
fi

scripts/feeds update -a
scripts/feeds install -a

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

if [ $onionNeedCommit -eq 1 ]
then
pushd .
cd feeds/onion
git add -A
git commit -m "Stop using SSH in Makefiles"
popd
fi

NUM_CORES=$(cat /proc/cpuinfo|grep -c1 "cpu cores")
let NUM_CORES++

echo
echo
echo -e "${LGREEN}Now we have to visit menuconfig, just choose exit${NC}"
echo -e "${LGREEN}and accept to saving changes.${NC}"
sleep 8
cp DefaultConfig .config
make defconfig
make -j$NUM_CORES menuconfig

echo -e "${LGREEN}Now you can proceed with the compile with:${NC}"
echo -e "${LGREEN}make -j$NUM_CORES${NC}"
echo
echo -e "${LGREEN}After compilation has finished, you'll find${NC}"
echo -e "${LGREEN}the images in:${NC}"
echo -e "${LGREEN}$SCRIPTDIR/bin/targets/ramips/mt76x8/${NC}"
echo
echo -e "${LGREEN}In the future, use the update.sh-script to${NC}"
echo -e "${LGREEN}merge updates from LEDE-upstream.${NC}"
