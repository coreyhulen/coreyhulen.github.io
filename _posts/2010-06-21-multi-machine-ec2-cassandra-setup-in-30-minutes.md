---
layout: post
title: Multi-machine EC2 Cassandra Setup in 30 minutes
date: '2010-06-21T00:00:00-07:00'
---

In this post we will walk through setting up a production ready 3 node 
Cassandra cluster with Munin monitoring running on Amazon EC2 in under 30 
minutes. We will also walk through getting the sample Cassandra stress scripts 
running with a basic load on the 3 node cluster. This post builds on a 
previous post about how to setup and maintain an EC2 virtual instance with 
our supplied unattended install scripts. If you wish to know more about how 
our unattended install scripts works please review my previous post.

Setup The First Node
--------------------

###Step 1 - Create the Instance

We are going to setup the first box in the Cassandra cluster utilizing the 
supplied scripts in the download section. For testing we have included a 
basic storage-conf.xml file, which you will want to replace with your own. 
Make sure your storage-conf.xml settings for 
`<ListenAddress>localhost</ListenAddress>` are set to 
`<ListenAddress></ListenAddress>` which will use the output from hostname 
to properly configure the node. You should also must set 
`<ThriftAddress>localhost </ThriftAddress>` to `<ThriftAddress></ThriftAddress>` 
or `<ThriftAddress>0.0.0.0</ThriftAddress>` for all devices on this node. 
From a local command prompt issue the following command to launch and 
configure an Amazon EC2 virtual instance.

{% highlight bash %}
ubuntu@localmachine:~$./setup_box.sh -p YourPemKeyFile.pem -s \
     40 cassandra.sh storage-conf.xml
{% endhighlight %}

Notice, when the script completes you are logged into the remote instance. 
For a detailed description of what setup_box.sh script does please 
see my previous post located here.

###Step 2 - Modify storage-config.xml

On the remote machine First Node run the hostname command to grab the remote 
machines host name.

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-21:~$ hostname
domU-33-92-42-0B-22-21
{% endhighlight %}

Edit the LOCAL copy of the supplied storage-conf.xml and place the hostname 
in the seed section changing the seed line from `<Seed>127.0.0.1</Seed>` to 
`<Seed>domU-33-92-42-0B-22-21</Seed>`. This will be the config to use for all 
new nodes added to the cluster. For a more robust production enviroment you 
might map an elastic IP address to the seed node alleviating the need for 
using an internal private Amazon hostname.

###Step 3 - Start Cassandra

Start Cassandra by running the following command

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-21:~$ cd ~/apache-cassandra-0.6.2
ubuntu@domU-33-31-92-0B-22-21:~$ ./bin/cassandra -p pid.txt
{% endhighlight %}

Later, you can kill the process if needed by issuing the command 
`kill $(cat pid.txt)`.

You can verify Cassandra is up and running by issuing the following command

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-21:~$ ./bin/nodetool info -h localhost
{% endhighlight %}

###Step 4 - Install Munin Server (Optional Step)

We will setup the First Node to monitor the entire cluster. In a true 
production enviroment we would recommend running the Munin server on a 
sepeate box verus running it on an actual Cassandra node. We are running 
it here for convenience. To install the Munin server run the following command 
on the First Node.

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-21:~$ sudo -E apt-get install -y apache2 munin
{% endhighlight %}

verify that the Munin server is working correctly by navigating to 
http://public_dns/munin you should see the localdomain node along with a 
Cassandra hyperlink to the right. You can find the public accessible name by 
running ec2-describe-instances from a local command prompt (scaning for the 
hostname internal name to find the public name). Or you could use the AWS 
managemnt console to find the public accessible host name. Notice the setup 
script from step 1 also installed the munin plugins for monitoring the 
Cassandra node. You can find more information about how to monitor a Cassandra 
node here. For now the script only configured the basics, which, you can modify 
later to collect more metrics.

Setup The Second Node
---------------------

If you are adding a node to an existing cluster with data then you should 
modify the local storage-confg.xml file to set the bootstrap property 
from `<AutoBootstrap>false</AutoBootstrap>` to 
`<AutoBootstrap>true</AutoBootstrap>`. This is only necessary if the cluster 
already has data in it otherwise the default is fine.

###Step 1 - Create the Instance

From a local command prompt issue the following command with the modified 
storage-conf.xml from step 2 above.

{% highlight bash %}
ubuntu@localmachine:~$./setup_box.sh -p YourPemKeyFile.pem -s 40 \
   cassandra.sh storage-conf.xml
{% endhighlight %}

###Step 2 - Start Cassandra

Start Cassandra by running the following command

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-24:~$ cd ~/apache-cassandra-0.6.2
ubuntu@domU-33-31-92-0B-22-24:~$ ./bin/cassandra -p pid.txt
{% endhighlight %}

You can verify Cassandra is up and running and has successfully inserted itself 
into the cluster by issuing the following command

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-24:~$ ./bin/nodetool ring -h localhost
Address          Status  Load         Range        Ring
                                zei3CqkdtMVpZpRg
10.213.121.211  Up  566 bytes   bohcarw6KQRfZEvb   |<--|
10.213.233.212  Up  1.01 KB    zei3CqkdtMVpZpRg     |-->|
{% endhighlight %}

Notice both machine are in the cluster as evidence by the ring command.

###Step 4 - Install Munin Node Monitoring (Optional Step)

In this step we will show you how to configure the Second Node to report it’s 
monitoring data to the Munin server or in our case the First Node. Remember in 
our example we used the First Node as the Munin server, but this may be 
different in your enviroment. First you need to modify the remote instance to 
allow others to connect to this munin node. Run the following command to edit 
the munin node configuration

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-24:~$ sudo nano /etc/munin/munin-node.conf
{% endhighlight %}

Add a line after allow `^127\.0\.0\.1$` that looks like `cidr_allow 0.0.0.0/0` 
which will allow anyone in your Amazon security group to see this munin node.  
You will need to restart the Munin node with the following command

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-24:~$ sudo /etc/init.d/munin-node restart
{% endhighlight %}

You will need to modify the Munin server to allow it to monitor the newly 
created Cassandra node. From our example above you should recall that we 
installed our Munin server on the First Node in our cassandra cluster. On the 
First Node remote instance edit the munin config file by running the following 
command

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-21:~$ sudo nano /etc/munin/munin.conf
{% endhighlight %}

Under the entry

{% highlight bash %}
[localhost.localdomain]
    address 127.0.0.1
    use_node_name yes
{% endhighlight %}

Add a new entry, pointing to your newly created Cassandra node (you can use 
hostname on the 2nd node to get the address) It should look something like 
the following

{% highlight bash %}
[Node2.Cassandra]
    address domU-12-31-39-00-69-12
    use_node_name yes
{% endhighlight %}

For clarity you should change `[localhost.localdomain]` to `[Node1.Cassandra]`. 
The easiest thing to do is wait for the Munin server to refresh the charts and 
you should see something like the screen shot below. You may need to wait for 
a couple of minutes to see the changes.

![Munin Setup](/assets/munin1.png)

If you click on the day link you should see something like

![Munin Graph](/assets/munin2.png)

###Setup The Third Node

For the Third Node I repeated the steps from the Second Node. Once the First 
Node is completed and running you can repeat the Second Node steps as many 
time as necessary to spin up multiple nodes. Notice this process can be done 
in parallel meaning I can add the Forth Node and Fifth Node at the same time 
in parallel.  You are ready to Rock! Connect a client to any node and start 
inserting/reading data from your Cassandra cluster.

###Setup and Run the Basic Stress Test

To see some more interesting results lets run the Cassandra stress tool 
against the 3 node cluster. For simplicity I’ll run the stress script on the 
Third Node in the cluster. WARNING: For an accurate stress test you should 
run several client instances on non-cassandra boxes. Running the stress script 
on the Thrid Node will skew the results and isn’t a true measure of performance, 
but we want to demonstarte how it can be done without needing to spin up more 
instances. Go ahead and login to the Thrid Node remote instance.

###Step 4 - Install Thrift complier

First we need to download, build, and install the thrift complier because we 
need the python bindings. Run the following commands.

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-26:~$ wget -q http://www.apache.org/dist/incubator/ \
   thrift/0.2.0-incubating/thrift-0.2.0-incubating.tar.gz
ubuntu@domU-33-31-92-0B-22-26:~$ tar -zxf thrift-0.2.0-incubating.tar.gz
ubuntu@domU-33-31-92-0B-22-26:~$ cd ~/thrift-0.2.0
ubuntu@domU-33-31-92-0B-22-26:~$ sudo apt-get install -y libboost-dev \
   libevent-dev python-dev automake pkg-config libtool flex bison
ubuntu@domU-33-31-92-0B-22-26:~$ ./bootstrap.sh
ubuntu@domU-33-31-92-0B-22-26:~$ ./configure
ubuntu@domU-33-31-92-0B-22-26:~$ make
ubuntu@domU-33-31-92-0B-22-26:~$ sudo make install
ubuntu@domU-33-31-92-0B-22-26:~$ cd ./lib/py
ubuntu@domU-33-31-92-0B-22-26:~$ make
ubuntu@domU-33-31-92-0B-22-26:~$ sudo make install
ubuntu@domU-33-31-92-0B-22-26:~$ export PYTHONPATH=/usr/lib/python2.6/site-packages
{% endhighlight %}

You also need to configure python to see the newly created thrift bindings. 
Run the following commands.

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-26:~$ python
Python 2.6.2 (release26-maint, Apr 19 2009, 01:56:41)
[GCC 4.3.3] on linux2
Type "help", "copyright", "credits" or "license" for more information.
>>> import sys
>>> sys.path
['''',
''/usr/lib/python2.6'',
''/usr/lib/python2.6/plat-linux2'',
''/usr/lib/python2.6/lib-tk'',
''/usr/lib/python2.6/lib-old'',
''/usr/lib/python2.6/lib-dynload'',
''/usr/lib/python2.6/dist-packages'',
''/usr/lib/python2.6/dist-packages/Numeric'',
''/usr/lib/python2.6/dist-packages/PIL'',
''/var/lib/python-support/python2.6'',
''/var/lib/python-support/python2.6/gtk-2.0'',
''/usr/local/lib/python2.6/dist-packages'']

>>> sys.path.append(''/usr/lib/python2.6/site-packages'')
>>> sys.path

{% endhighlight %}

Notice I am not a python expert and basically copied the commands by 
following the blog post located here. If the install was successful then 
typing thrift on the commnad line should output help.

Next download the Cassandra source to the client machine for testing by 
running the following commands on the Third Node.

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-26:~$ wget -q http://www.apache.org/dist/cassandra/ \
   0.6.2/apache-cassandra-0.6.2-src.tar.gz
ubuntu@domU-33-31-92-0B-22-26:~$ tar -zxf apache-cassandra-0.6.2-src.tar.gz
ubuntu@domU-33-31-92-0B-22-26:~$ cd ~/apache-cassandra-0.6.2-src
ubuntu@domU-33-31-92-0B-22-26:~$ ant gen-thrift-py
ubuntu@domU-33-31-92-0B-22-26:~$ cd contrib/py_stress
{% endhighlight %}

Run the ring command to get the nodes IP addresses to supply to the stress 
script. Now lets run the stress tool inserting 2 million keys.

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-26:~$ python stress.py --operation insert \
   --num-keys 2000000 --nodes 10.254.58.113,10.254.58.114,10.254.58.115 \
   --family-type regular
{% endhighlight %}

Now lets randomly read 2 million rows of data

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-26:~$ python stress.py --operation read --num-keys \
   2000000 --nodes 10.254.58.113,10.254.58.114,10.254.58.115
{% endhighlight %}

###Backing Up your Cluster

The install scripts configure the system with some basic backup and snapshot 
scripts. Look at the files created in ~/cron. You can also do a crontab -l to 
see the scripts scheduled to run. The snapshot script will run every day at 1 
am. The copy to EBS drive script will run everyday at 3 am. You should create 
another script that uses AWS to snapshot your EBS drives for backup to Amazon 
S3. You can run these commands manually if needed.

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-26:~$ ~/cron/cass_snapshot.sh
{% endhighlight %}

You can then navigate to /var/lib/cassandra (which is actually mapped to 
ephemeral drive /mnt/cassandra) and inspect the data folder and see the 
snapshot dirs with their appropriate files.

You can now backup the snapshots directories to the EBS drive by running the following command

{% highlight bash %}
ubuntu@domU-33-31-92-0B-22-26:~$ ~/cron/cass_move_to_ebs.sh
{% endhighlight %}

Navigate to /backupvol/cassandra on the EBS drive and see the snapshot 
directories are copied over to the non-epherimal storage drive.
Notice the cron job runs nightly snapshots so your epherimal drives must have 
3x the disk space of your expected data to handle the worst case. 1x for the 
data itself, 2x for the snapshoted data, and 3x if compaction occured at the 
most in-opportune time. For saving snapshots to the EBS drive the size of the 
EBS drive must be 2x the data size since we copy the data before deleting the 
older snapshots for consistency. If you are doing regular AWS EBS snapshots 
(don’t confuse this with Cassandra snapshots) then you can modify the script 
to remove the directory before copying so you will only need 1x the disk space 
since the previous data will have already been backed up into Amazon S3.

Conclusion
----------

I hope people can use these scripts as a starting point for setting up a 
Cassandra clusters. Please feel free to modify and re-use these scripts as 
you see fit. In a future post I’ll describe how the cassandra.sh script works 
and what it does.

Downloads
---------
Amazon EC2 remote install script - [ec2-cassandra-setup.zip](https://github.com/coreyhulen/blog/raw/master/ec2-cassandra-setup.zip)
