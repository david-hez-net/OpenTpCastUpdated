#!/bin/bash

echo "BEGIN INSTALL - DO NOT INTERRUPT"

set -e

echo "INSTALLING PACKAGES"
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install git build-essential linux-headers-$(uname -r) libjpeg9-dev make cmake bc git lighttpd php-cgi

echo "SETTING BOOT PARAMETERS"
sudo sed -i 's/dtparam=audio=on/dtparam=audio=off/g' /boot/firmware/config.txt
echo "dtoverlay=pi3-disable-bt" | sudo tee -a /boot/firmware/config.txt > /dev/null
sudo sed -i 's/rootwait/rootwait quiet/g' /boot/firmware/cmdline.txt

echo "INSTALLING WIFI DRIVER FOR REALTEK 8821AU"
git clone https://github.com/morrownr/8821au-20210708
cd 8821au-20210708
make
sudo cp 8821au.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless
sudo depmod -a
sudo modprobe 8821au
cd ..
rm -rf 8821au-20210708

echo "INSTALLING VIRTUALHERE TPCAST EDITION SERVER"
sudo wget -e check_certificate=off -q -O /usr/sbin/vhusbdtpcast https://www.virtualhere.com/sites/default/files/usbserver/vhusbdtpcast && sudo chmod +x /usr/sbin/vhusbdtpcast
sudo wget -e check_certificate=off -q -O /etc/init.d/vhusbdpin https://raw.githubusercontent.com/david-hez-net/OpenTpCastUpdatedScript/refs/heads/main/vhusbdpin && sudo chmod +x /etc/init.d/vhusbdpin
sudo sed -i 's/vhusbdarm/vhusbdtpcast/g' /etc/init.d/vhusbdpin
sudo update-rc.d vhusbdpin defaults > /dev/null 2>&1 || true
echo -e "ServerName=TPCast\nonDeviceIgnore=return 0\nonChangeNickname=return 1\nonReset.0bb4.2c87=\nonReset.28de.2000=\nDeviceNicknames=Vive Camera,0bb4,2c87,1122\nIgnoredDevices=424/ec00,bda/8194,bda/811" | sudo tee /root/config.ini > /dev/null

echo "INSTALLING OPENTPCAST WEB SERVER"
sudo wget -e check_certificate=off -q -O /boot/opentpcast.LICENSE https://rawgit.com/OpenTPCast/Docs/master/LICENSE
sudo wget -e check_certificate=off -q -O /boot/opentpcast.txt https://rawgit.com/OpenTPCast/Docs/master/files/prepareimage/opentpcast.txt
sudo wget -e check_certificate=off -q -O /boot/opentpcastversion.txt https://rawgit.com/OpenTPCast/Docs/master/files/prepareimage/opentpcastversion.txt
sudo touch /boot/initwlan

git clone https://github.com/OpenTPCast/mjpg-streamer
sudo make -C ./mjpg-streamer/mjpg-streamer-experimental && sudo make -C ./mjpg-streamer/mjpg-streamer-experimental install
sudo rm -rf mjpg-streamer

sudo lighty-enable-mod fastcgi fastcgi-php rewrite && sudo service lighttpd force-reload && sudo usermod -a -G www-data pi && sudo rm /var/www/html/index.lighttpd.html
echo "www-data ALL=(ALL) NOPASSWD: /usr/local/bin/opentpcast-ctrl" | sudo tee /etc/sudoers.d/100_opentpcast-ctrl && sudo chmod 0440 /etc/sudoers.d/100_opentpcast-ctrl
git clone https://github.com/OpenTPCast/opentpcast_ctrl
sudo cp opentpcast_ctrl/opentpcast-ctrl /usr/local/bin/opentpcast-ctrl && sudo chown root:www-data /usr/local/bin/opentpcast-ctrl && sudo chmod 750 /usr/local/bin/opentpcast-ctrl
sudo cp opentpcast_ctrl/opentpcast-camera /etc/init.d/opentpcast-camera && sudo chmod +x /etc/init.d/opentpcast-camera
sudo cp opentpcast_ctrl/controlpanel/* /var/www/html/
sudo cp opentpcast_ctrl/api/20-opentpcast.conf /etc/lighttpd/conf-available/20-opentpcast.conf
sudo cp opentpcast_ctrl/api/api.php /var/www/html/
sudo lighty-enable-mod opentpcast && sudo service lighttpd force-reload
sudo rm -rf opentpcast_ctrl
sudo chown -R www-data:www-data /var/www && sudo chmod -R g+rw /var/www

echo "SETTING HOSTNAME"
sudo hostname tpcast
sudo sed -i "s/$(cat /etc/hostname)/tpcast/g" /etc/hosts
sudo sed -i "s/$(cat /etc/hostname)/tpcast/g" /etc/hostname

echo "SETTING PASSWORD"
echo "pi:1qaz2wsx3edc4rfv" | sudo chpasswd

echo "INSTALL DONE - REBOOTING!"
sudo reboot
