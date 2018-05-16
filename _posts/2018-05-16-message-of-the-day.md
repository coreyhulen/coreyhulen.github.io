---
layout: post
title: Hacking the Message of the Day
date: '2018-05-16T00:00:00-07:00'
---

While fooling around with creating an experimental Mattermost template for Packer I figured it would be nice to override the message of the day to display the various versions of the software running Mattermost.

On Ubuntu 16.04 a cron job updates the MOTD by calling various scripts inside `/etc/update-motd.d`.  To create a simple custom message I ended up tweaking those scripts a little. The job runs all the scripts in the directory, captures the standard out, and concatenates the output into the MOTD.  I ended up removing most of the scripts to clean it up a bit.

I ended up removing the following files

{% highlight bash %}
sudo rm /etc/update-motd.d/51-cloudguest
sudo rm /etc/update-motd.d/00-header
{% endhighlight %}

and modifying `/etc/update-motd.d/10-help-text` to look like the following, which borrows a little from the `00-header` file.

{% highlight bash %}
#!/bin/sh

[ -r /etc/lsb-release ] && . /etc/lsb-release

if [ -z "$DISTRIB_DESCRIPTION" ] && [ -x /usr/bin/lsb_release ]; then
    # Fall back to using the very slow lsb_release utility
    DISTRIB_DESCRIPTION=$(lsb_release -s -d)
fi

MM_DESCRIPTION=$(cd /opt/mattermost/bin && sudo -u mattermost /opt/mattermost/bin/platform version)
MYSQL_DESCRIPTION=$(mysql -h 127.0.0.1 -V)
NGINX_DESCRIPTION="$(nginx -v  2>&1)"

printf "\n"
printf "Welcome to Mattermost!"
printf "\n\n"
printf "%s\n" "$MM_DESCRIPTION"
printf "\n"
printf "Other Version Information:\n"
printf "  %s (%s %s %s)\n" "$DISTRIB_DESCRIPTION" "$(uname -o)" "$(uname -r)" "$(uname -m)"
printf "  %s\n" "$MYSQL_DESCRIPTION"
printf "  %s\n" "$NGINX_DESCRIPTION"
printf "\n"
{% endhighlight %}

The script ends up printing the Mattermost Server version, OS version, MySQL version, and Nginx version when logging into the instance for quick at a glance reference of what version is running.  The output looks like the following:

{% highlight bash %}

Welcome to Mattermost!

Version: 4.9.0
Build Number: 4.9.1
Build Date: Fri Apr 27 03:49:57 UTC 2018
Build Hash: 30b5547a57bd348b04ab587a6b4a22274fed3808
Build Enterprise Ready: true
DB Version: 4.9.0

Other Version Information:
  Ubuntu 16.04.4 LTS (GNU/Linux 4.4.0-1055-aws x86_64)
  mysql  Ver 14.14 Distrib 5.7.22, for Linux (x86_64) using  EditLine wrapper
  nginx version: nginx/1.10.3 (Ubuntu)

{% endhighlight %}

