systemctl stop snap.kafka.kafka
umount /dev/vdb
umount /dev/vdc
dd if=/dev/zero of=/dev/vdb count=128K
dd if=/dev/zero of=/dev/vdc count=128K
systemctl start snap.kafka.kafka

