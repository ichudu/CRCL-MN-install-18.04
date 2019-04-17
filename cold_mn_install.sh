#!/bin/bash
# mn_install.sh
# Version 0.2
# Date : 17.04.2019
# This script will install a CRCL Cold Wallet Masternode in the default folder location

if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS=Debian
    VER=$(cat /etc/debian_version)
elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    ...
elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    ...
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi

if [ "$OS" == "Ubuntu" ] && [ "$VER" == "18.04" ]; then
  echo "$OS $VER : OK"
else
  echo "This script should be run on Ubuntu 18.04 only"
  exit 1
fi


#ADD_SWAP=N
GITHUB_DL=https://github.com/ichudu/Crowdclassic/releases/download/v0.12.1.9-beta/CRowdCLassicCore-bin.0.12.1.9.x64.linux18.04.tar.gz
COIN_ZIP=CRowdCLassicCore-bin.0.12.1.9.x64.linux18.04.tar.gz
RPCPORT=11998
CRCLPORT=12875

clear
cd ~
echo $PWD
echo
echo "CRowdCLassic [CRCL]"
echo
echo "--------------------------------------------------------------"
echo "This script will setup a CRCL Masternode in a Cold Wallet Setup"
echo "--------------------------------------------------------------"
read -p "Do you want to continue ? (Y/N)? " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "End of the script, nothing has been change."
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

#Check if current user is allowd to sudo
sudo -v
A=$(sudo -n -v 2>&1);test -z "$A" || echo $A|grep -q asswor
if [[ "$A" == "" ]]; then
        echo "user allowed to run Sudo"
else
        echo "current user is not member of Sudo users"
        echo "correct the problem and restart the script"
        exit 1
fi

# Add swap if needed
read -p "Do you want to add 2GB memory swap file to your system (Y/n) ?" -n 1 -r -s ADD_SWAP
# ADD_SWAP="y"
if [[ ("$ADD_SWAP" == "y" || "$ADD_SWAP" == "Y" || "$ADD_SWAP" == "") ]]; then
        if [ ! -f /swapfile ]; then
            echo && echo "Adding swap space..."
            sleep 3
            sudo fallocate -l 2048000000 /swapfile
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile
            sudo swapon /swapfile
            echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
            sudo sysctl vm.swappiness=10
            sudo sysctl vm.vfs_cache_pressure=50
            echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
            echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
        else
            echo && echo "WARNING: Swap file detected, skipping add swap!"
            sleep 3
        fi
fi
echo
if [ ! -f /root/.crowdclassiccore/crowdclassic.conf ]; then
   echo 
else
   echo
   echo
echo "--------------------------------------------------------------"
echo "!!! Previous installation detected. It will be deleted. !!!"
echo "--------------------------------------------------------------"
read -p "Do you want to continue ? (Y/N)? " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "End of the script, nothing has been change."
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi
#   echo "!!!ATTENTION!!!"
#   echo "Previous installation detected. Deleting after 20s."
   echo "Deleting... Press Crl+C to abort!"
   sleep 20 
    # kill wallet daemon
    sudo killall -w crowdclassicd > /dev/null 2>&1
    #remove old ufw port allow
    sudo ufw delete allow 12875/tcp > /dev/null 2>&1
    #remove old files
    sudo rm -rf ~/Crowdclassic > /dev/null 2>&1
    sudo rm -rf ~/.crowdclassiccore > /dev/null 2>&1
    sudo rm -rf ~/sentinelLinux > /dev/null 2>&1
    sudo rm -rf ~/venv > /dev/null 2>&1
    sudo rm -rf CRowdCLassicCore*.gz CRowdCLassicCore*.gz.* > /dev/null 2>&1
    #remove binaries and CRowdCLassic utilities
    cd /usr/bin && sudo rm crowdclassic-cli crowdclassic-tx crowdclassicd > /dev/null 2>&1
    cd /usr/local/bin && sudo rm crowdclassic-cli crowdclassic-tx crowdclassicd > /dev/null 2>&1
fi
echo
echo "updating system, please wait..."
sudo apt-get -y -q update
sudo apt-get -y -q upgrade
sudo apt-get -y -q dist-upgrade
echo && echo "Installing Fail2Ban..."
apt-get -y -q install fail2ban -y
sleep 3
systemctl enable fail2ban
systemctl start fail2ban
if [ ! -f /etc/fail2ban/jail.local ]; then
   echo 
else
   echo
touch /etc/fail2ban/jail.local
cat << EOF >> /etc/fail2ban/jail.local
[DEFAULT]
ignoreip = 127.0.0.1/8
maxretry = 6
bantime = 3600
bantime.increment = true
bantime.rndtime = 10m
[sshd]
enabled = true
[ssh]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
EOF
sleep 3
systemctl restart fail2ban
fi
echo && echo "Installing UFW..."
sleep 3
sudo apt-get -y -q install ufw -y
echo && echo "Configuring UFW..."
sleep 3
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw limit ssh/tcp
sudo ufw allow $CRCLPORT/tcp
sudo ufw logging on
echo "y" | sudo ufw enable
echo && echo "Firewall installed and enabled!"
echo ""
sleep 3
echo "Installing sentinel"
# sudo apt-get update
sudo apt-get -y -q install git -y
sudo apt-get -y -q install python-virtualenv virtualenv
cd ~
git clone https://github.com/CRowdClassic/sentinelLinux.git && cd sentinelLinux
export LC_ALL=C
virtualenv ./venv
./venv/bin/pip install -r requirements.txt
#change line of sentinelconf with correct path
sed -i -e 's/dash_conf=\/home\/YOURUSERNAME\/\.crowdclassiccore\/crowdclassic\.conf/dash_conf=~\/\.crowdclassiccore\/crowdclassic.conf/g' sentinel.conf

cd ~
sudo apt-get -y -q install pwgen -y
sudo apt-get -y -q install curl tar wget -y 
sudo apt-get install unzip -y
sudo apt-get install libzmq3-dev libminiupnpc-dev libssl-dev libevent-dev -y
sudo apt-get install build-essential libtool autotools-dev automake pkg-config -y
sudo apt-get install libssl-dev libevent-dev bsdmainutils software-properties-common -y
sudo apt-get -y -q install libboost-all-dev -y
sudo add-apt-repository ppa:bitcoin/bitcoin -y
sudo apt-get update
sudo apt-get install libdb4.8-dev libdb4.8++-dev -y

mkdir $HOME/tempcrcl
chmod -R 777 $HOME/tempcrcl
cd $HOME/tempcrcl

sudo wget $GITHUB_DL
sudo tar -xvf $COIN_ZIP
cd ~

cd $HOME
mkdir $HOME/Crowdclassic
mkdir $HOME/.crowdclassiccore
cp $HOME/tempcrcl/CRowdCLassicCore-bin.0.12.1.9.x64.linux18.04/crowdclassicd $HOME/Crowdclassic
cp $HOME/tempcrcl/CRowdCLassicCore-bin.0.12.1.9.x64.linux18.04/crowdclassic-cli $HOME/Crowdclassic

ln -s $HOME/Crowdclassic/crowdclassic-cli /usr/local/bin/crowdclassic-cli
ln -s $HOME/Crowdclassic/crowdclassicd /usr/local/bin/crowdclassicd

chmod -R 777 $HOME/Crowdclassic
chmod -R 777 $HOME/.crowdclassiccore

cd $HOME/.crowdclassiccore
sudo wget https://github.com/ichudu/Crowdclassic/releases/download/v0.12.1.9-beta/blocks.zip
sudo unzip blocks.zip
sudo rm -rf blocks.zip
cd ~

echo ""
echo "==============================================="
echo " Installation finished, starting configuration"
echo "==============================================="
echo "" 
if pgrep -x "crowdclassicd" > /dev/null
then
    cd ~/Crowdclassic
    echo "Found crowdclassicd is running, stopping it..."
    sudo crowdclassic-cli stop
    echo "Waiting 60 seconds before continuing..." 
    sleep 60
fi
echo ""
echo "-----------------------------------------------"
echo "Setting up crowdclassic.conf RPC user and password"
echo "-----------------------------------------------"
echo ""
cd ~
cd .crowdclassiccore
rpcuser=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
rpcpass=`pwgen -1 20 -n`
echo "rpcuser=${rpcuser}
rpcpassword=${rpcpass}" >> crowdclassic.conf
echo -e "${YELLOW}Enter your ${RED}$COIN_NAME masternode genkey${NC}:"
read -e COINKEY
masternodeGenKey=$COINKEY
echo "----------------------------------------------------------------------"
echo "masternodeGenKey : $masternodeGenKey"
echo "----------------------------------------------------------------------"
echo ""
echo "Update configuration file..."
NODEIP=$(curl -s4 icanhazip.com)
# write all data into ../crowdclassicd
locateCRowdCLassicConf=~/.crowdclassiccore/crowdclassic.conf
cat >> $locateCRowdCLassicConf <<EOF
disablewallet=1
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
rpcport=$RPCPORT
rpcthreads=8
listen=1
server=1
daemon=1
staking=0
discover=1
masternode=1
logintimestamps=1
maxconnections=256
externalip=$NODEIP:$CRCLPORT
masternodeprivkey=$masternodeGenKey
addnode=212.237.55.250
addnode=80.211.87.193 
EOF

echo "Configuration $locateCRowdCLassicConf updated."
echo "Starting CRowdCLassic daemon from $PWD"
echo " Waiting 20 seconds after starting..."
sudo crowdclassicd -daemon
sleep 20
crowdclassicGetInfoOutput=$(sudo crowdclassic-cli getinfo)
while [[ ! ($crowdclassicGetInfoOutput = *"version"*) ]]; do
	sleep 10
	$crowdclassicGetInfoOutput
done	

echo "-----------------------------------------------"
echo "Now waiting Masternode Sync"
echo "Checking every 2 seconds ..."
echo "-----------------------------------------------"
spin='-\|/'
masternodeStartOutput=$(sudo crowdclassic-cli mnsync status | grep IsSynced | tr -d ,)
#echo $masternodeStartOutput
while [[ ! ($masternodeStartOutput = *"true"*) ]]; do
        i=$(( (i+1) %4 ))
        block=`sudo crowdclassic-cli getinfo | grep block | tr -d ,`
#        sync=`sudo crowdclassic-cli mnsync status | grep IsSynced | tr -d ,`
#        masternodeStartOutput=$(sudo crowdclassic-cli masternode start)
        masternodeStartOutput=$(sudo crowdclassic-cli mnsync status | grep IsSynced | tr -d ,)
        printf "\r$block | ${spin:$i:1} : $masternodeStartOutput                "
        sleep 2
done
echo ""
echo "Add sentinelLinux in crontab"
(crontab -l 2>/dev/null; echo "* * * * * cd ~/sentinelLinux && ./venv/bin/python bin/sentinel.py 2>&1 >> sentinel-cron.log") | crontab -
echo ""
# echo "Add check MN Status in crontab"
# (crontab -l 2>/dev/null; echo "* * * * * cd ~/masternode-install &  bash check_status.sh 2>&1 >> mn-check-cron.log") | crontab -
sudo service cron reload
masternodeStartedOutput=$(sudo crowdclassic-cli masternode status)
echo ""
echo "$masternodeStartedOutput"
sleep 3
cd ~
sudo rm -rf tempcrcl
sudo apt-get autoremove -y
sudo apt-get clean -y