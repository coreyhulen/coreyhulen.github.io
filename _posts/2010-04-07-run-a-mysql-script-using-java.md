---
layout: post
title: Run a MySQL Script using Java
date: '2010-04-07T00:00:00-07:00'
excerpt: "Sometimes it is nice to programmatically run .sql scripts 
on a MySQL database using Java.  This is easily accomplished using the 
allowMultiQueries configuration property for the MySQL Connector/J driver.  
When set to true it allows the use of ‘;’ to delimit multiple queries."
banner_url: /assets/banner_run.jpg
---

Sometimes it is nice to programmatically run .sql scripts on a MySQL 
database using Java.  This is easily accomplished using the allowMultiQueries 
configuration property for the MySQL Connector/J driver.  When set to true 
it allows the use of ‘;’ to delimit multiple queries.

In the below code snippet line 1 ensures the MySQL driver is loaded. Line 
2 creates a connection that allows multiple queries per statement. The 
root login is used for brevity, but in a production system the user account 
should have limited access. Notice the default catalog (or database) was 
not specified on the connection URL.

{% highlight java %}
Class.forName("com.mysql.jdbc.Driver");
Connection conn = DriverManager.getConnection("jdbc:mysql://localhost/? \
   user=root&password=rootpassword&allowMultiQueries=true");
{% endhighlight %}

The code snippet below creates a database and sets the connections 
catalog to the newly created database.

{% highlight java %}
PreparedStatement stmt = conn.prepareStatement("CREATE DATABASE IF NOT \
   EXISTS MultilineMySqlTest");
stmt.execute();
stmt.close();

conn.setCatalog("MultilineMySqlTest");
{% endhighlight %}

Now we want to run the follow test.sql script against the newly created database.

{% highlight sql %}
CREATE TABLE IF NOT EXISTS Product (
	ID int(11) NOT NULL auto_increment,
	Data varchar(512) NOT NULL,
	PRIMARY KEY (ID)
);

INSERT INTO Product (Data) VALUES ('data test 1');

INSERT INTO Product (Data) VALUES ('data test 2');

INSERT INTO Product (Data) VALUES ('data test 3');
{% endhighlight %}

The code below loads the entire script using the Apache common IOUtils 
into a string variable then executes the script.

{% highlight java %}
String query = IOUtils.toString(new FileReader("./scripts/test.sql"));

stmt = conn.prepareStatement(query);
stmt.execute();
stmt.close();

conn.close();
{% endhighlight %}

CONCLUSION
----------

This makes running .sql scripts from Java a breeze.  In the real world I’ve 
used this technique to run some pretty complicated scripts.  There are a few 
exceptions with running scripts in this manner, mainly, the DELIMITER keyword isn’t 
recognized or understood by the Connector/J driver.  If you want to run a more 
complicated script in the SQL Browser you would need to include DELIMITER $$ at 
the top of the file and $$ at the end.  I’ve also noticed sql comments tend to 
confuse the parser and are best avoided.
