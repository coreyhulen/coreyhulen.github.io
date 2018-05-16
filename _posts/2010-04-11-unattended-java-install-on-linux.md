---
layout: post
title: Unattended Java Install on Linux
date: '2010-04-11T00:00:00-07:00'
---

When building and configuring Amazon EC2 instances I find myself
needing to install the Sun Java 6 runtime and/or the JDK unattended. 
This is sometimes referred to as non-interactive or headless install. 
The script below is what I typically use to install Java on my
Ubuntu 9.10 instances running on Amazon EC2.

Lets examine and breakdown the installjava.sh script below.

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

sudo -E apt-get update	-y
sudo -E apt-get upgrade -y

echo "sun-java6-jdk shared/accepted-sun-dlj-v1-1 boolean true" \
   | sudo -E debconf-set-selections

sudo -E apt-get install -y sun-java6-jdk

echo "export JAVA_HOME=/usr/lib/jvm/java-6-sun" | sudo -E tee -a ~/.bashrc
{% endhighlight %}

Line 1 tells the operating system that the follow script is non-interactive.

Lines 3-6 append the needed archive locations for the java installer to
the sources.lst file.  This will later allow us to install Java 6 on
an Amazon EC2 instance.

Lines 8-9 update the archive repository and upgrade the system.  It is always good
practice to upgrade your system to get the latest security updates.

Line 11 is where the magic happens.  This sets a variable that allows
you to accept the Java 6 license without physically typing yes.  This 
overcomes the pain hurdle of installing the Java 6 JDK unattended.

Line 13 installs the Sun Java 6 JDK.

Line 15 sets the Java home location in the users environment for later use.

CONCLUSION
----------

That’s it.  Now you can easily install the Sun Java 6 JDK unattended. Most
of the concepts can be applied to other installers that require a license accept
step or another blocking “user input” required step.
