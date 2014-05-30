---
layout: post
title: Polling for EC2 instance availability
date: '2010-04-03T00:00:00-07:00'
excerpt: "I often find myself writing scripts for Amazon EC2 that need to wait 
for the instance to become available.  Instance availability, for me, is dictated 
when the ssh service becomes available.  Lets create a simple script that 
will poll a ssh connection and wait until it can connect before letting the 
script continue."
banner_url: /assets/banner_pole.jpg
---

I often find myself writing scripts for Amazon EC2 that need to wait for the 
instance to become available.  Instance availability, for me, is dictated 
when the ssh service becomes available.  Lets create a simple script that 
will poll a ssh connection and wait until it can connect before letting the 
script continue.

{% highlight bash %}
~$ while ssh -o StrictHostKeyChecking=no -q -i myidentityfile.pem \
       ubuntu@amazonec2publicdnsname.com true && test; \
       do echo -n .; sleep 1; done
{% endhighlight %}

The above script tries to connect via ssh if it cannot connect it will echo 
a ‘.’ to the command line and sleep for 1 second before trying again. When 
you combine this with information from Eric Hammond’s EC2 blog 
(http://alestic.com) you will have a script that can launch an Amazon 
instance, wait for it to become available and connect to it.

{% highlight bash %}
# create the instance and capture the instance id echo "launching instance..."
instanceid=$(ec2-run-instances --key MyIdentityFile --availability-zone \
us-east-1c ami-bb709dd2 | egrep ^INSTANCE | cut -f2) echo " instanceid=$instanceid"

# wait for the instance to be fully operational
echo -n "waiting for instance to start running..." 
while host=$(ec2-describe-instances "$instanceid" | egrep ^INSTANCE | \ 
cut -f4) && test -z $host; do echo -n .; sleep 1; done echo "" echo " host=$host" 
echo -n "waiting for ssh connection to start..." 
while ssh -o StrictHostKeyChecking=no -q -i MyIdentityFile.pem \ 
ubuntu@$host true && test; do echo -n .; sleep 1; done echo ""
{% endhighlight %}

With little modification to the above script you can have the Amazon 
instance install upgrades and reboot then begin polling to re-connect to 
the instance once it becomes available again.  In the above script the 
ec2-describe-instances part is only used to get the host name of the 
machine.  Even though Amazon EC2 is reporting the instance as running I 
find it to be unreliable in determining if the instances ssh service 
is running.
