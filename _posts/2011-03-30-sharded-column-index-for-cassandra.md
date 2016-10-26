---
layout: post
title: Sharded Column Index for Cassandra
date: '2011-03-30T00:00:00-07:00'
---
Description
Eindex is a module for sharding column based indexes. With a similar schemeof 
how Cassandra shards row keys we decided to shard column keys. With this 
scheme you can still use the Cassandra Random Partitioner and get range queries 
for keys. Our goal is to support 100’s of millions of keys across a Cassandra 
cluster.

###How it Works

For the simple case lets consider the index keys to be uniquie (or mostly 
unique) and the value for each key is 1000 + key. Lets say we want to index 
the evens list2, 4, 6, 8, 10, … 100 plus lets throw in one odd 19. Lets set 
the shard boundries to 20, 40, 60, 80, 100. Theindexer will have the shard 
boundries loaded into memory (first constraint). Whenwe lookup the index ‘19’ 
we first lookup it’s shard boundry in this case it would be 20. given that 
boundry we then lookup the Cassandra row key ‘myIndex:20’ and column key ‘19’ 
which will yeild the value of ‘1019’. Since the shard boundries are cached this 
equates to only 1 Cassandra query. We can also range query. Lets say we are 
looking for the index ‘17’, which doesn’t exist and we want the next 5 indexes. 
We could callgetValueRangesForIndex with and index value of ‘17’ and a limit of 
5 will return[18, 1018], [19, 1019], [20, 1020], [22, 1022], [24, 1024] or all 
the evens plus the19 we added earlier. The indexer will look at the next shard 
to fulfill the requestedlimit if needed. So in this example it quiered Cassandra 
row key ‘myindex:20’ andretrieve 18, 19 then queries the next shard boundry 
key ‘myindex:40’ to retrieve thenext keys of 20, 22, 24. You can also reverse 
the range query so running the same querywill yeild [16, 1016], [14, 1014], 
[12, 1012], [10, 1010], [8, 1008]. Each of theserange queries translated into 
2 Cassrandra row reads. So when you query close to a broundryit might translate 
into 2 queries to Cassandra.

What happens when you store more than 1 value per index? It gets written into 
another Cassandra row key. So lets store the value ‘1000’ into the exiting key 
of [19, 1019].When more that one value is written to the same index key a 
special empty marker isplace at the Cassandra row key ‘myindex:20’ column ‘19’. 
The values are written intoa new Cassandra row key ‘myindex::19’ column values 
‘1019, 1000’ (Notice the ‘::’deferiantes the shard keys from actual index keys). 
So if we run the same range scanof ‘17’ and limit 5 we get [18, 1018], 
[19, [1000, 1019]] … Notice the value keyscome back sorted. This query will 
tranluate into 3 cassandra queries. Each index keythat has multiple values will 
transulate into another Cassandra query. There is anoptimization where if the 
index key has only 1 value (like a primary key) then thereisn’t any extra 
query to Cassandra.

###Notes and Limitations

* The automated sharding isn’t complete. You must prepopulate the shards by 
calling initializeShardBoundries.

* Currently the index keys and index values must be of the same type because 
they will be persisted into the same column family. With little modificationwe 
should be able to support things like Long indexes with UUIDs or Strings as 
values.  Or even String indexes to Long valuesm but mis-matching types will 
require 2column families. Currently multiple indexes of the same type can be 
stored in thesame column family.

* The index performs best if the keys are considered to be mostly unique. 
Things like geo-location data where it would be rare to have the exact same GPS 
coords wouldwork great. There is an optimization for keys that only have 1 
value where no extraquerying has to be performed. If a key contains multiple 
values then for each keyin your range scan that has multiple-values will 
translate into multiple queries.

* The shard boundries are currently constrainted by memory. A basic rule of 
thumb weuse is for every shard to have a capacity of 100,000 columns. So 1000 
boundries heldin memory X 100K columns is 100M indexes. Or a better way to say 
it is forevery 1K of boundries in memory = 100M indexes in Cassandra.

* To fulfill range query requests the algorithm only looks at 1 addition 
shard (this mightchange depending on needs). So if the current shard and the 
next shard have less thanthe limit you quieried for then you will not get back 
a full limit of keys.

Downloads
---------

For more information checkout our github page at 
[https://github.com/coreyhulen/earnstone-index](https://github.com/coreyhulen/earnstone-index).
