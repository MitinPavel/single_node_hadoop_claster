hduser = "hduser"
hdgroup = "hadoop"

# Create a user and a group ---------------------------------------------------

group "hadoop"

user hduser do
  supports :manage_home => true
  home "/home/#{hduser}"
  gid hdgroup
  shell "/bin/bash"
end

# Setup SSH -------------------------------------------------------------------

execute "generate ssh keys for #{hduser}" do
  user hduser
  command <<-SHELL
    ssh-keygen -t rsa -q -f /home/#{hduser}/.ssh/id_rsa -P ""
    cat /home/#{hduser}/.ssh/id_rsa.pub >> /home/#{hduser}/.ssh/authorized_keys
  SHELL
  not_if { File.exist?("/home/#{hduser}/.ssh/id_rsa.pub") }
end

# Disable ipv6 ----------------------------------------------------------------

config_file = "/etc/sysctl.conf"

["net.ipv6.conf.all.disable_ipv6 = 1",
 "net.ipv6.conf.default.disable_ipv6 = 1",
 "net.ipv6.conf.lo.disable_ipv6 = 1"].each do |line|
  execute "add #{line} to #{config_file}" do
    command "echo '#{line}' >> #{config_file}"
    only_if { File.readlines(config_file).detect { |l| l.include?(line) }.nil? }
  end
end

# Install hadoop deb package --------------------------------------------------

deb_file_name = "hadoop_1.0.3-1_x86_64.deb"

remote_file "/tmp/#{deb_file_name}" do
  source "http://archive.apache.org/dist/hadoop/core/hadoop-1.0.3/#{deb_file_name}"
  action :create_if_missing
end

dpkg_package 'install hadoop deb package' do
  source "/tmp/#{deb_file_name}"
  action :install
end

# Set JAVA_HOME to config files -----------------------------------------------

["/home/#{hduser}/.bashrc", "/etc/hadoop/hadoop-env.sh"].each do |file|
  bash "append JAVA_HOME to #{file}" do
    user hduser
    code <<-EOS
      echo "export JAVA_HOME=#{ENV['JAVA_HOME']}" >> /home/#{hduser}/.bashrc
    EOS
    not_if "grep -q JAVA_HOME /home/#{hduser}/.bashrc"
  end
end

# Hadoop dir for hdfs ---------------------------------------------------------

directory "/var/hadoop/tmp" do
  owner hduser
  group hdgroup
  mode 750
  recursive true
  action :create
end

# Hadoop config files ---------------------------------------------------------

["core-site.xml", "hdfs-site.xml", "mapred-site.xml"].each do |file|
  template "#{ENV['HADOOP_CONF_DIR']}/#{file}" do
    source file
    mode 0644
    owner "root"
    group "root"
  end
end

# Format namenode -------------------------------------------------------------

execute "format namenode" do
  command "hadoop namenode -format"
  user hduser
  action :run
  not_if { ::File.exists?("/var/hadoop/tmp/dfs/name/") }
end

# Start hadoop demons ---------------------------------------------------------

execute "start all Hadoop services" do
  command "/usr/sbin/start-all.sh"
  user hduser
  action :run
  not_if { %w(NameNode SecondaryNameNode DataNode JobTracker TaskTracker).any? { |d| `jps`.match(/#{d}/) }}
end

#hduser@precise64:~$ /usr/sbin/start-all.sh
#starting namenode, logging to /var/log/hadoop/hduser/hadoop-hduser-namenode-precise64.out
#The authenticity of host 'localhost (127.0.0.1)' can't be established.
#ECDSA key fingerprint is c7:91:15:37:d6:af:84:63:66:0f:42:e4:2b:48:7b:dc.
#Are you sure you want to continue connecting (yes/no)? yes
#localhost: Warning: Permanently added 'localhost' (ECDSA) to the list of known hosts.
#localhost: starting datanode, logging to /var/log/hadoop/hduser/hadoop-hduser-datanode-precise64.out
#localhost: starting secondarynamenode, logging to /var/log/hadoop/hduser/hadoop-hduser-secondarynamenode-precise64.out
#starting jobtracker, logging to /var/log/hadoop/hduser/hadoop-hduser-jobtracker-precise64.out
#localhost: starting tasktracker, logging to /var/log/hadoop/hduser/hadoop-hduser-tasktracker-precise64.out
