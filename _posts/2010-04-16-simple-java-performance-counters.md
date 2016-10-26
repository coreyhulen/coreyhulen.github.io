---
layout: post
title: Simple Java Performance Counters
date: '2010-04-16T00:00:00-07:00'
---
There doesn’t seem to be a whole lot of open source options for 
Java performance counters.  Since I found it frustrating and 
rolled my own I decided to share my work so others could just 
ditto it.  The overarching principal is Simplicity or more 
importantly KISS.  I wanted something fast, simple, easy to use, 
fast, simple and thread-safe (did I mention fast and simple).  
After working with windows C++ performance counters (yuck!) talk 
about warts and .NET performance counters (nice band-aid, but 
still didn’t cover the warts) I opted for a simple 
under-engineered design.  Before we dive into some samples 
lets briefly explain the included Java performance counters.

Standard Java Performance Counters
----------------------------------

The following list describes each of the included performance 
counters and some example scenarios that they solve.

* __PerfAvg__: A performance counter for averaging over a sample. 
This is usually a base class for other more detailed counters, 
but it could be used to average anything.  Sample display 
would be '4.34'

* __PerfAvgCallsPerSec__: A performance counter for calls per 
second over a time sample. Makes calculating things like 
transactions per second or transactions per hour a breeze. 
Sample display would be '4.34 per sec'.

* __PerfAvgTime__: A performance counter for averaging over a time 
sample.  Great for things like average time in a method call or 
average time to process items. Sample display would be 
'1 hr 33 m 46 s'.

* __PerfIncrement__: A performance counter that counts.  You may 
use simple atomic operations to increment and decrement the count 
value. Sample display would be '78 items processed'.

* __PerfLastAccessTime__: A performance counter for displaying 
last access time.  Great for counters like last access time or 
up time. Sample display would be '3 days 22 hrs 4 m 13 s'.

* __PerfPercent__: A performance counter that calculates percent. 
Great for hit cache performance counters. Sample display 
would be '75.4%'.

Now that we have a basic idea of the supplied Java performance 
counters let look at a few examples.

Running Count
-------------

In this example we will use the __PerfIncrement__ performance counter 
as a running count for items we have processed, lets say from a 
message queue. This counter can do thread-safe actions like increment, 
decrement, incrementBy, decrementBy, etc.

{% highlight java %}
// typically should be held as a static
PerfIncrement itemsProcessed = new PerfIncrement();

itemsProcessed.setCategory("My Category");
itemsProcessed.setName("Render Queue");
itemsProcessed.setFormatter("#,### items processed");

// Registered so other components can access the counter
PerfRegistry.register(itemsProcessed);

while (true) {
   Message m = Queue.getMessage();
   processMessage(m);
   itemsProcessed.increment();
}

// From another part of the code we could call
System.out.println(PerfRegistry.printPerfs(PerfRegistry.listAllCounters()));
{% endhighlight %}

Which would print the following

{% highlight bash %}
~$ My Category
~$     Render Queue 1,287 items processed
{% endhighlight %}

Average Process Time
--------------------

In this next example we will use the __PerfAvgTime__ performance counter 
to sample an average time taken to complete an action. Lets say we are 
compressing documents from a queue and we want to keep track of the 
average time to compress a document.

{% highlight java %}
// typically should be held as a static
PerfAvgTime avgTime = new PerfAvgTime();

avgTime.setCategory("My Category");
avgTime.setName("Avg Compress Time");

// Registered so other components can access the counter
PerfRegistry.register(avgTime);

while (true) {
   Document doc = Queue.getNextDocument();

   long startTime = System.currentTimeMillis();
   compress(doc);
   avgTime.addTime(startTime, System.currentTimeMillis());
}

// From another part of the code we could call
System.out.println(PerfRegistry.printPerfs(PerfRegistry.listAllCounters()));
{% endhighlight %}

Which would print the following

{% highlight bash %}
~$ My Category
~$     Avg Compress Time 1 min 34 sec
{% endhighlight %}

Transactions Per Second
-----------------------

In this next example we will use the __PerfAvgCallsPerSec__ performance counter 
to compute transactions per second. Lets say we are reading documents from 
a queue and submitting them for processing and we want to track the 
number of documents per second.  The counter can also calculate the avg 
calls per minute, hour, etc.

{% highlight java %}
// typically should be held as a static
PerfAvgCallsPerSec tps = new PerfAvgCallsPerSec();

tps.setCategory("My Category");
tps.setName("Documents Processed");
tps.setPerTime(PerTime.Sec);  // Signifies we want values in seconds

// Registered so other components can access the counter
PerfRegistry.register(tps);

while (true) {
   Document doc = Queue.getNextDocument();
   process(doc);
   tps.incrementCall();
}

// From another part of the code we could call
System.out.println(PerfRegistry.printPerfs(PerfRegistry.listAllCounters()));
{% endhighlight %}

Which would print the following

{% highlight bash %}
~$ My Category
~$     Documents Processed   44.34 per sec
{% endhighlight %}

Conclusion
----------

I hope this is helpful for people who want to make some 
simple measurements of their system using the supplied Java 
performance counters.  Eventually I will include source code 
and examples to expose the performance counters through a JMX 
(Java Management Extensions) as well as a simple REST web 
service.  We have code in production that accomplishes 
these tasks, but currently it needs to be re-factored to 
remove our internal software dependencies.

Downloads
---------
[Simple Java Performance Counters Source](https://github.com/coreyhulen/earnstone-perf)

I have added JMX support. [See my later post](/2010/05/19/jmx-support-for-java-perf-counters/).

