---
layout: post
title: Earnstone Unique ID Generator
date: '2011-03-02T00:00:00-08:00'
banner_url: /assets/banner_unique.jpg
---

EID is a service for generating unique ID numbers at high scale with some 
simple guarantees (based on the work from https://github.com/twitter/snowflake). 
The service can be in-memory or run as a REST-ful web service using Jetty.

The main differences between Snowflake and EID are

* __Java vs Scala__ - Our company uses Java.

* __REST Server vs Thrift Server__ - With a simple REST-ful interface we can 
access the service from anywhere without the need to generate thrift 
bindings. We are willing to sacrifice raw speed for usability. We are still 
able to generate 4K ids/sec per machine on our development hardware. If speed 
is a concern then look at using the in-memory version of EID.

* __No Zookeeper dependency__ - Zookeeper is great, but someone can 
mis-configure the Zookeeper location generating the same unqiue ids. Removing 
the dependancy puts more responsibility on the person configuring the EID 
services. So be careful when configuring the data center and worker ids.

Downloads
---------

For more information checkout our github page at 
[https://github.com/coreyhulen/earnstone-id](https://github.com/coreyhulen/earnstone-id).
