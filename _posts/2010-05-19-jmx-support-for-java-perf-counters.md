---
layout: post
title: JMX Support for Java Perf Counters
date: '2010-05-19T00:00:00-07:00'
---

I have added JMX support to the Simple Java Performance Counters. For a 
detailed description on the Java Performance Counters please check out my 
previous post located.

We expose JMX support by implementing a custom DynamicMBean known as JmxPerf. 
Currently, we only expose the display value, but it might makes sense to expose 
the raw value as well. This will allow JMX tools to sample the counter(s) and 
chart progress. The JMX bean is exposed by calling the 
PerfRegisty.registerJmxBeans(int jmxServerPort, int jmxRegistryPort) method. 
Lets examine this method below located in PerfRegisty.java.

{% highlight java %}
public static boolean registerJmxBeans(int jmxServerPort, int jmxRegistryPort) {

      try {

         if (!registeredJmx) {
            registeredJmx = true;
            LocateRegistry.createRegistry(jmxRegistryPort);
            HashMap<String, Object> env = new HashMap<String, Object>();
            MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();
            JMXServiceURL url = new JMXServiceURL("service:jmx:rmi://127.0.0.1:" 
              + jmxServerPort + "/jndi/rmi://127.0.0.1:" 
              + jmxRegistryPort + "/jmxrmi");
            JMXConnectorServer cs = JMXConnectorServerFactory.
              newJMXConnectorServer(url, env, mbs);
            cs.start();

            for (String category : PerfRegistry.listCategories()) {
               JmxPerf perf = new JmxPerf(category);
               ObjectName objectName = new ObjectName(perf.getObjectTypeName());
               mbs.registerMBean(perf, objectName);
            }
         }

         return true;
      }
      catch (Exception ex) {
         return false;
      }
   }

{% endhighlight %}

The JMX bean can only be registered once so calling the method multiple times 
is safe and has no effect. Notice you can specific the jndi port to run the 
registry at as well as the port of the actual bean, which are different.
Next, lets examine the methods that does the work in JmxPerf.java that 
implements the dynamic bean interface.  The getAttributes method uses the 
PerfRegisty to enumerate the counters and return their results using 
the display value method.

{% highlight java %}
   @Override
   public AttributeList getAttributes(String[] names) {

      AttributeList list = new AttributeList();
      String value = null;

      for (String name : names) {

         PerfCounter counter = PerfRegistry.getCounter(category, name);

         if (counter != null)
            value = counter.getDisplayValue();
         else
            value = PerfUtils.NA;

         list.add(new Attribute(name, value));
      }

      return list;
   }
{% endhighlight %}

Conclusion
----------

I hope this is was a helpful addition to the Simple Java Performance Counters.

Downloads
---------

[Simple Java Performance Counters](https://github.com/coreyhulen/earnstone-perf)
