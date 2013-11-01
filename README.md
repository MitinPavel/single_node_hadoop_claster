Description
===========

Settings up a Single Node Hadoop Cluster 1.0.3

Requirements
============

Platform
--------

* Ubuntu
 
Tested on:

* Linux precise64 3.2.0-23-generic #36-Ubuntu SMP x86_64 GNU/Linux

Java
--------

* Hadoop requires Oracle 1.6 JDK/JRE (see http://wiki.apache.org/hadoop/HadoopJavaVersions). See the attirbute section below for `node['single_node_hadoop_claster']['java']['java_home']` attribute

Attributes
==========

* `node['single_node_hadoop_claster']['java']['java_home']` - path to JAVA_HOME (for example: "/usr/lib/jvm/jdk1.6.0_45").
* `node["single_node_hadoop_claster"]["user"]["name"]` - hdfs/hadoop user. Note, that the cookbook doesn't distinguish between these two roles (hdfs user and map/reduce user).
* `node["single_node_hadoop_claster"]["user"]["group"]` - hdfs/hadoop user group.

See the `attributes/default.rb` for more info.

Related cookbooks
=================

* See https://github.com/MitinPavel/single_node_hadoop_claster_wrapper It is a wrapper cookbook, which configures Apt and Java before starting this cookbook.

Resources
=========

* http://hadoop.apache.org/docs/current/

License and Author
==================

- Author:: Pavel Mitin (<mitin.pavel@gmail.com>)

Copyright 2013 Pavel Mitin

Licensed under the MIT License (MIT).

