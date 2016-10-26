---
layout: post
title: Raid Level 0 Setup on Amazon EC2 EBS drives
date: '2010-07-28T00:00:00-07:00'
---

This will be a short post describing how we configure a raid level 0 drive on 
an EC2 instance using the EBS drives. For a lot of our functionality we 
typically use the ephemeral drives and periodically backup content using the 
EBS drives and snapshots. We mainly use raided EBS drives to get the maximum 
performance out of an Amazon EC2 small instances. For example we have seen 
nearly double the performance out of our Cassandra cluster on small instances 
using raided EBS drives. 

Some might say “EEEEKKKHH” raid 0 isn’t safe, but for 
us we get persisted backups using the amazon EBS snapshot feature (daily, 
weekly, etc) and our data is fault-tolerant when stored in Cassandra because 
data is automatically replicated to multiple nodes. Depending on your 
reliability needs this may not be something you want to do with say MySQL. 
For example in the MySQL case if you snapshot your EBS drive daily then you 
would loose at most 1 days worth of data. Utilizing a 2 node Cassandra cluster 
and assuming you have the replication factor set to 2, 1 of the 2 nodes can go 
down and you still have 100% of the data. If both nodes went down then you 
would lose at most 1 days worth of data.

Configuration
-------------
First fire up the Amazon Management Console and create two volumes of 10 GB 
each and attached them to an instance as `/dev/sdm` and `/dev/sdn`.

Install the raid driver and the xfs file system with the following command.

{% highlight bash %}
~$ sudo apt-get install -y mdadm xfsprogs
{% endhighlight %}

Now lets create the drive as `/dev/md0` using the two disks `/dev/sdm` and 
`/dev/sdn`. There are some great articles floating around about the best 
settings for an EBS drive so utilizing that knowledge we set the chunk size 
to 256.

{% highlight bash %}
~$ sudo mdadm --create /dev/md0 --level 0 --chunk=256 --metadata=1.1 \
      --raid-devices=2 /dev/sdm /dev/sdn
{% endhighlight %}

Next we need to add the devices into the mdadm.conf file so the drive 
configuration is persisted.

{% highlight bash %}
~$ echo DEVICE /dev/sdm /dev/sdn | sudo tee /etc/mdadm/mdadm.conf
~$ sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
{% endhighlight %}

Next lets construct the xfs file system on the `/dev/md0` drive.

{% highlight bash %}
~$ sudo mkfs.xfs /dev/md0
{% endhighlight %}

Next lets add the `/dev/md0` drive to the file systems table for auto-mounting 
on reboot.

{% highlight bash %}
~$ echo "/dev/md0 /raiddrive xfs noatime 0 0" | sudo tee -a /etc/fstab
{% endhighlight %}

Now lets mount and format the drive.

{% highlight bash %}
~$ sudo mkdir /raiddrive
~$ sudo mount /raiddrive
{% endhighlight %}

Lets set the block device read ahead have to 64k which seems to really smooth 
out and improve the EBS drives.

{% highlight bash %}
~$ sudo blockdev --setra 65536 /dev/md0
{% endhighlight %}

Next lets verify the drive is operation

{% highlight bash %}
~$ df -h /raiddrive
{% endhighlight %}

###Drive removal

If you wish to remove the drive run the follow commands

{% highlight bash %}
~$ sudo umount /raiddrive
~$ sudo mdadm --stop /dev/md0
~$ sudo mdadm --remove /dev/md0
{% endhighlight %}

Also, make sure to modify your `/etc/fstab` file and remove the `/dev/md0` 
line. Now, using the AWS management Console you can detach the volumes 
from the instance.

Conclusion
----------

Short, sweet and easy to configure. I hope now you can get the most out of your 
EC2 IO bound small instances. For some of our IO bound map reduce jobs against 
our Cassandra cluster we have seen nearly a 2x performance boost.

Downloads
---------

None for this post.
