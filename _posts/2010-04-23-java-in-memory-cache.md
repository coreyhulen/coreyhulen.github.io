---
layout: post
title: Java in Memory Cache
date: '2010-04-23T00:00:00-07:00'
---

Lets look at creating and using a simple thread-safe Java in-memory cache. It 
would be nice to have a cache that can expire items from the cache based on a 
time to live as well as keep the most recently used items. Luckily the apache 
common collections has a LRUMap, which, removes the least used entries from a 
fixed sized map. Great, one piece of the puzzle is complete. For the expiration 
of items we can timestamp the last access and in a separate thread remove the 
items when the time to live limit is reached. This is nice for reducing memory 
pressure for applications that have long idle time in between accessing the 
cached objects. There is also some debate weather the cache items should return 
a cloned object or the original. I prefer to keep it simple and fast by 
returning the original object. So the onus is on the user of the cache to 
understand modifying the underlying object will modify the object in the cache 
as well. Notice this is also an in-memory cache so objects are not serialized 
to disk.

Lets review the Cache implementation below.

{% highlight java %}
package com.earnstone.utils;

import java.util.ArrayList;

import org.apache.commons.collections.MapIterator;
import org.apache.commons.collections.map.LRUMap;

public class Cache <K, T> {

   private long timeToLiveInMillis;

   private LRUMap cacheMap;

   protected class CachedObject {
      public long lastAccessed = System.currentTimeMillis();
      public T value;

      protected CachedObject(T value) {
         this.value = value;
      }
   }

   public Cache(long timeToLiveInSeconds, final long timerIntervalInSeconds, 
     int maxItems) {
      this.timeToLiveInMillis = timeToLiveInSeconds * 1000;

      cacheMap = new LRUMap(maxItems);

      if (timeToLiveInMillis > 0 && timerIntervalInSeconds > 0) {

         Thread t = new Thread(new Runnable() {
            public void run() {
               while (true) {
                  try {
                     Thread.sleep(timerIntervalInSeconds * 1000);
                  }
                  catch (InterruptedException ex) {
                  }

                  cleanup();
               }
            }
         });

         t.setDaemon(true);
         t.start();
      }
   }

   public void put(K key, T value) {
      synchronized (cacheMap) {
         cacheMap.put(key, new CachedObject(value));
      }
   }

   public T get(K key) {
      synchronized (cacheMap) {
         CachedObject c = (CachedObject) cacheMap.get(key);

         if (c == null)
            return null;
         else {
            c.lastAccessed = System.currentTimeMillis();
            return c.value;
         }
      }
   }

   public void remove(K key) {
      synchronized (cacheMap) {
         cacheMap.remove(key);
      }
   }

   public int size() {
      synchronized (cacheMap) {
         return cacheMap.size();
      }
   }

   @SuppressWarnings("unchecked")
   public void cleanup() {

      long now = System.currentTimeMillis();
      ArrayList<K> keysToDelete = null;

      synchronized (cacheMap) {
         MapIterator itr = cacheMap.mapIterator();

         keysToDelete = new ArrayList<K>((cacheMap.size() / 2) + 1);
         K key = null;
         CachedObject c = null;

         while (itr.hasNext()) {
            key = (K) itr.next();
            c = (CachedObject) itr.getValue();

            if (c != null && (now > (timeToLiveInMillis + c.lastAccessed))) {
               keysToDelete.add(key);
            }
         }
      }

      for (K key : keysToDelete) {
         synchronized (cacheMap) {
            cacheMap.remove(key);
         }

         Thread.yield();
      }
   }
}

{% endhighlight %}

The cache object has a protected inner class CachedObject which tacks on a 
timestamp to the object that will be used later for expiring objects from the 
cache. The class is actually pretty simple with the exception of the internal 
cleanup thread. The thread for cleaning up items sleeps for the preset time 
supplied to the constructor and wakes and processes the cache expirations 
synchronously. This is important because if you have a large cache it may take 
some time before the cleanup method is called again because it’s total cleanup 
time + timer interval. I prefer this method vs. a timer callback because the 
cleanup thread will not add extra load to the system if it is behind. Notice 
the cleanup code synchronizes on the map and copies all the keys to another 
list to delete. This will allow the map to keep processing requests on 
different threads for adding to the map while the cleanup thread removes 
objects form the cache. But the user also needs to be aware that for each 
cleanup call we must lock the cache and iterate over the entire set, which, 
might cause a noticeable pause when under high load. Then we loop through all 
the keys expiring objects from the cache as well as yielding the thread for 
others processing in between expiring individual objects.

Conclusion
----------

I hope people find the Java in-memory cache useful. There are a lot of 
different caching modules out in the wild, but I wanted to introduce a simple 
thread-safe in-memory cache without the overhead of having to implement 
Serializable or Cloneable.

Downloads
---------
Utils - [earnstone-utils-0.1-all.zip](https://github.com/coreyhulen/blog/raw/master/earnstone-utils-0.1-all.zip)
