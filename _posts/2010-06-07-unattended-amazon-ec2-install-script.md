---
layout: post
title: Unattended Amazon EC2 Install Script
date: '2010-06-07T00:00:00-07:00'
---

After maintaining several version of my own private AMI’s and, realizing what 
a pain maintenance was, I decided to find a better solution. There is a lot of 
great information on the net if your google-fu is good, but I decided to 
compile all the information I use into a couple scripts and describe each 
step in detail so others could understand, modify and use the scripts. The 
overriding goal is to allow the flexibility of launching and configuring 
remote Amazon EC2 instances in an non-interactive manner.

First lets make sure your Amazon tools are installed and configured correctly. 
You can verify they are installed correctly by running the command.

{% highlight bash %}
~$ ec2-describe-instances
{% endhighlight %}

If the amazon tools are install on your system correctly then it should output 
information describing your running instances. If you received any errors check 
your .bashrc file in your home directory and add the following lines to the 
end of the file (note: The install path and key values will be different on 
your system).

{% highlight bash %}
export PATH=$PATH:$HOME/AmazonEC2/ec2-api-tools-1.3-46266/bin
export JAVA_HOME=/usr/lib/jvm/java-6-sun
export EC2_PRIVATE_KEY=~/.ec2/pk-XXXX***CHANGETOYOURKEY***XXXX.pem
export EC2_CERT=~/.ec2/cert-XXXX***CHANGETOYOURKEY***XXXX.pem
export EC2_DEFAULT_PEM=~/.ec2/YourPemKeyFile.pem
export EC2_HOME=$HOME/AmazonEC2/ec2-api-tools-1.3-46266
{% endhighlight %}

Next download the zipped scripts at the end of this post and run the command 
below making sure you change the path to your .pem file. Also make sure 
your .pem file has it’s permissions set correctly otherwise the EC2 tools 
will barf with a message similar to ‘Permissions 0644 for ‘YourPemKeyFile.pem’ 
are too open. It is recommended that your private key files are NOT accessible 
by others.'' Usually a ''chmod a-r YourPemKeyFile.pem'' will do the trick. 
Notice if you set the EC2_DEFAULT_PEM variable in your .bashrc then you do 
not need to specify the ‘-p’ option.

{% highlight bash %}
./setup_box.sh -p ./YourPath/YourPemKeyFile.pem -s 10 basic.sh
{% endhighlight %}

We’ll examine the scripts in more detail, but first lets get a general 
overview of what’s happening. The setup_box.sh script file is running various 
EC2 commands from the Amazon tools to initialize and start a Amazon Machine 
Instance (AMI) along with creating a Elastic Block Storage (EBS) drive with 
10GB that will be attached later. Once the script verifies the instance is up 
and running it will upload the basic.sh script to the remote instance and 
execute it. The basic.sh script updates the remote system installing the 
latest patches along with installing some basic software like Sun Java 6. The 
basic.sh script will also attach, mount and format the EBS drive for future 
use by the remote instance.

setup_box.sh Described in Detail
--------------------------------

Lets get a quick overview of some of the boilerplate scripting parts. The 
‘while getopts’ loop is a nifty way of setting script variables based on 
options like ‘-p ARG’. You can have as many options as you like in any order 
plus the shift operation at the end of the loop will remove all the options 
so the standard $1 variable will be the first unmatched argument. We will use 
the $1 and $2 options later for assigning the scripts to run on the server. 
You can also look at the VERIFY_CMD_LINE() fuction which just sets some 
defaults for the different options.

{% highlight bash %}
#PROCESS ARGS
while getopts ":p:a:z:s:?" Option
do
    case $Option in
        p    ) pemkey=$OPTARG;;
        a    ) ami=$OPTARG;;
        z    ) avzone=$OPTARG;;
        s    ) ebssize=$OPTARG;;
        ?    ) USAGE
               exit 0;;
        *    ) echo ""
               echo "Unimplemented option chosen."
               USAGE   # DEFAULT
    esac
done

shift $(($OPTIND - 1))
{% endhighlight %}

The script will choose some basic defaults to make it easy. If you do not 
specify a AMI id with ‘-a’ then the script will default to ‘ami-bb709dd2’ 
which is Ubuntu 9.10 32 bit small instance. If you do not specify the 
availability zone option with ‘-z’ then the script will default to 
‘us-east-1c’. If you do not specify the ‘-s’ size option for EBS storage 
then no storage will be created.

Now onto the meat of the setup_box.sh script which is the LAUNCH_BOX() 
function. We will break down each individual piece with a description for 
better understanding.

The script below uses the Amazon tools ‘ec2-run-instances’ to launch 
the instance. Then we parse the output results extracting the instance-id 
as a script variable for later use.

{% highlight bash %}
    # create the instance and capture the instance id
    echo "Launching instance..."
    instanceid=$(ec2-run-instances --key $pemkeypair --availability-zone \
        $avzone $ami | egrep ^INSTANCE | cut -f2)
    if [ -z "$instanceid" ]; then
        echo "ERROR: could not create instance";
        exit;
    else
        echo "Launched with instanceid=$instanceid"
    fi
{% endhighlight %}

If the EBS size option was set with the ‘-s’ option then we will create a 
EBS volume instance utilizing the same technique as above. Then we parse 
the output results extracting the volume-id as a script variable for later use.

{% highlight bash %}
    if [ -n "$ebssize" ]; then
        echo "Creating EBS volume instance..."
        volid=$(ec2-create-volume --availability-zone $avzone -s $ebssize \
            | egrep ^VOLUME | cut -f2)
        if [ -z "$instanceid" ]; then
            echo "ERROR: could nt create EBS volume";
            exit;
        else
            echo "Created volume with volid=$volid"
        fi
    fi
{% endhighlight %}

We will need to use the Amazon tools ec2-describe-instances command to verify 
the instance is up and running and to get the public DNS host as a script 
variable for later use. Notice we use a similar method as above, capturing the 
output for later use as a script variable, but with a slight modification. The 
script repeats in a loop polling the Amazon services. This is a nifty little 
trick I ran across on Eric Hammond’s http://alestic.com blog where you can 
poll for instance availability. Once the instance is up and running and we 
have the host name then the script will continue.

{% highlight bash %}
    # wait for the instance to be fully operational
    echo -n "Waiting for instance to start running..."
    while host=$(ec2-describe-instances "$instanceid" | egrep ^INSTANCE \
       | cut -f4) && test -z $host; do echo -n .; sleep 1; done
    echo ""
    echo "Running with host=$host"
{% endhighlight %}

Using the ec2-describe-instances command to verify if an instance is up and 
running tends to be non-deterministic when deciding if the ssh process of 
the remote server is running. So we use the same scripting technique polling 
every 1 second until we can connect to the remote host using ssh.
 
{% highlight bash %}
    echo -n "Verifying ssh connection to box..."
    while ssh -o StrictHostKeyChecking=no -q -i $pemkey ubuntu@$host \
       true && test; do echo -n .; sleep 1; done
    echo ""
{% endhighlight %}

Next we sleep for 3 seconds as a precaution before connection and running 
scripts. Also if the ‘-s’ option was set we attach the EBS volume to the 
running instance under /dev/sdh. Later, the basic.sh script will mount and 
format the EBS drive.

{% highlight bash %}
    echo "Sleeping for 3s before accessing server"
    sleep 3

    if [ -n "$ebssize" ]; then
        echo "Attaching EBS $volid to $instanceid"
        attached=$(ec2-attach-volume -d /dev/sdh -i $instanceid $volid)
    fi
{% endhighlight %}

Once the remote instance is up and running and we have all the necessary 
information stored in script variables we can jump down to the end of the 
setup_box.sh script and describe how we upload and execute scripts on the 
remote server.

You can specify a data file on the command line after the action script. 
This is a convenience method for uploading addition scripts or data files 
needed to configure your box. Notice you can do some nifty stuff by specifying 
a .zip file that will get extracted on the remote server via your custom 
action script later. This command uses the host variable from before in 
conjunction with secure copy (scp command) to upload the file over an ssh 
connection. We will also upload the action script using the same method if it 
was specified on the command line.

{% highlight bash %}
if [ -n "$datafile" ]; then
    echo "uploading $datafile data file..."
    scp -o StrictHostKeyChecking=no -i $pemkey $datafile ubuntu@$host:~
fi
{% endhighlight %}

Once the action script and data file are uploaded and sitting on the remote 
server we will execute them using the ssh command. First we change the action 
script to make sure it is executable then we execute the remote script.

{% highlight bash %}
    echo "connecting and running $actionscript script..."
    ssh -o StrictHostKeyChecking=no -i $pemkey ubuntu@$host "chmod u+x ./$actionscript"
    ssh -o StrictHostKeyChecking=no -i $pemkey ubuntu@$host "./$actionscript"
{% endhighlight %}

Once the remote script finishes executing we reboot the remote instance. 
You may remove or modify this line depending on your needs, but our basic.sh 
script will run an upgrade to make sure the latest security patches are 
installed, which usually requires a reboot.

{% highlight bash %}
    echo "rebooting instance..."
    ec2-reboot-instances $instanceid
    sleep 7
{% endhighlight %}

As a final option we wait for the instance to become available polling via 
ssh. Then we auto login so you may complete any manual steps if necessary.

{% highlight bash %}
    echo -n "waiting for ssh connection to start..."
    while ssh -o StrictHostKeyChecking=no -q -i $pemkey ubuntu@$host \
       true && test; do echo -n .; sleep 1; done
    echo ""

    echo "sleeping for 3s before accessing server..."
    sleep 3

    echo "Connection to host $host..."
    ssh -o StrictHostKeyChecking=no -q -i $pemkey ubuntu@$host
{% endhighlight %}

Thats the basics of the setup_box.sh script which uses the Amazon tool 
commands to remotely (and unattended) create, run, and connect to a EC2 
remote instance.

basic.sh Described in Detail
----------------------------

The basic.sh script was upload and executed via the setup_box.sh script. The 
idea is you should have different scripts depending on what type of box you 
wish to setup. I have examples for configuring a MySQL box, Cassandra box, 
Tomcat6, etc. If there is interest I’ll post the different scripts with 
explanations. The basic.sh scripts shows how to install different applications 
while un-attended or in non-interactive mode.

The first export command sets the DEBIAN_FRONTEND property to noninteractive. 
The following echo commands add the ubuntu ec2 archives locations for 
updating and upgrading the remote instance. The command appends the “deb …” 
string to the end of the sources.list file, which is used by apt-get. Next 
we run update and upgrade to make sure we have the most up to date and secure 
system. This step is also required for refreshing the archive locations so 
later applications like Java 6 can be installed correctly.

{% highlight bash %}
export DEBIAN_FRONTEND=noninteractive

echo "deb http://us.ec2.archive.ubuntu.com/ubuntu/ karmic multiverse" \
   | sudo -E tee -a /etc/apt/sources.list
echo "deb-src http://us.ec2.archive.ubuntu.com/ubuntu/ karmic multiverse" \
   | sudo -E tee -a /etc/apt/sources.list
echo "deb http://us.ec2.archive.ubuntu.com/ubuntu/ karmic-updates multiverse" \
   | sudo -E tee -a /etc/apt/sources.list
echo "deb-src http://us.ec2.archive.ubuntu.com/ubuntu/ karmic-updates multiverse" \
   | sudo -E tee -a /etc/apt/sources.list

# run an update and upgarde
sudo -E apt-get update	-y
sudo -E apt-get upgrade -y
{% endhighlight %}

Next we install the munin node software to help monitor the instance (note: 
you will still need to modify the main master munin server). We also make 
sure to install the munin plugin allowing us to track the “steal” CPU cycles 
for virtual instances.

{% highlight bash %}
# Install munin node to monitor this instance
sudo -E apt-get install -y munin-node
# Replace the Munin cpu plugin with one that recognizes "steal" CPU cycles
sudo -E curl -o /usr/share/munin/plugins/cpu \
   https://anvilon.s3.amazonaws.com/web/20081117-munin/cpu
sudo -E curl -o /usr/share/munin/plugins/plugin.sh \
   https://anvilon.s3.amazonaws.com/web/20081117-munin/plugin.sh
sudo -E /etc/init.d/munin-node restart
{% endhighlight %}

The Sun Java 6 install is a lot more tricky because we need to accept the 
license in non-interactive mode. This is performed by setting the debconf 
selection for the license to true. We then run the Sun java 6 install along 
with making sure we append the Java home location to our path.

{% highlight bash %}
# install java 6 runtime
echo "sun-java6-jdk shared/accepted-sun-dlj-v1-1 boolean true" \
   | sudo -E debconf-set-selections
sudo -E apt-get install -y sun-java6-jdk
echo "export JAVA_HOME=/usr/lib/jvm/java-6-sun" | sudo -E tee -a ~/.bashrc
{% endhighlight %}

Last if the EBS drive /dev/sdh device was attached then we need to mount and 
format the drive. Here we format the drive using the xfs file system and mount 
it at the location /backupvol. This is useful for instances that have 
applications like MySQL and need a place storage that’s more robust than the 
free ephemeral drives.

{% highlight bash %}
# configure and mount the EBS drive if one was created.
if [ -e /dev/sdh ]; then
    sudo -E apt-get install -y xfsprogs
    sudo -E mkfs.xfs /dev/sdh
    echo "/dev/sdh /backupvol xfs noatime 0 0" | sudo -E tee -a /etc/fstab
    sudo -E mkdir -m 000 /backupvol
    sudo -E mount /backupvol
fi
{% endhighlight %}

Conclusion
----------

I hope people find this post helpful. We use variations of these scripts in 
production at Earnstone.com and find them extremely useful compared to 
creating and maintaining private AMI’s. The idea is that users will create 
their own variations of the basic.sh script to configure their remote boxes, 
while setup_box.sh should remain relatively unchanged. In a future post I’ll 
try to get our Cassandra script annotated so people can see how we easily 
create Cassandra clusters or add new nodes into existing clusters.

Downloads
---------

Amazon EC2 remote install script - [ec2-basic-setup.zip](https://github.com/coreyhulen/blog/raw/master/ec2-basic-setup.zip)
