#!/bin/bash
# Auth dysj4099_AT_gmail.com
# Mar 30, 2015

. ./deploy_timesync.cfg

echo $NTP_SERVER
echo $LOG_FILE
apt-get update
apt-get install ntpdate -y

cat > /tmp/timesync_sample.sh << _wrtend_
#!/bin/bash

echo 'TimeSync at:' >> /var/log/timesync.log
date >> /var/log/timesync.log
/usr/sbin/ntpdate $NTP_SERVER >> $LOG_FILE

_wrtend_

chmod a+x /tmp/timesync_sample.sh
mv /tmp/timesync_sample.sh /usr/bin/timesync
cp ./timesync.cron /etc/cron.d/timesync
/etc/init.d/cron restart
