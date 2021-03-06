hduser = node['single_node_hadoop_claster']['user']['name']
hdgroup = node['single_node_hadoop_claster']['user']['group']

# Create a user and a group ---------------------------------------------------

user hduser do
  supports :manage_home => true
  home "/home/#{hduser}"
  shell "/bin/bash"
end

group hdgroup do
  members hduser
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

known_hosts_file = "/home/#{hduser}/.ssh/known_hosts"
execute "add localhost to known_hosts" do
  user hduser
  cwd "/home/#{hduser}"
  command <<-SHELL
    ssh-keyscan localhost >> #{known_hosts_file}
    chown #{hduser} #{known_hosts_file}
  SHELL
  not_if "grep -q \"`ssh-keyscan localhost`\" #{known_hosts_file}"
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

# Set permissions for hadoop group --------------------------------------------

%w(
  /etc/hadoop

  /usr/bin/hadoop

  /usr/etc/hadoop

  /usr/sbin/hadoop-daemon.sh
  /usr/sbin/hadoop-setup-applications.sh
  /usr/sbin/hadoop-daemons.sh
  /usr/sbin/hadoop-setup-hdfs.sh
  /usr/sbin/hadoop-setup-single-node.sh
  /usr/sbin/update-hadoop-env.sh
  /usr/sbin/hadoop-validate-setup.sh
  /usr/sbin/hadoop-create-user.sh
  /usr/sbin/hadoop-setup-conf.sh

  /usr/sbin/start-all.sh
  /usr/sbin/start-balancer.sh
  /usr/sbin/start-dfs.sh
  /usr/sbin/start-jobhistoryserver.sh
  /usr/sbin/start-mapred.sh

  /usr/sbin/stop-all.sh
  /usr/sbin/stop-balancer.sh
  /usr/sbin/stop-dfs.sh
  /usr/sbin/stop-jobhistoryserver.sh
  /usr/sbin/stop-mapred.sh

  /usr/include/hadoop

  /usr/libexec/hadoop-config.sh

  /usr/share/hadoop/
  /usr/share/doc/hadoop
).each do |name|
  execute "change group to #{hdgroup} for #{name}" do
    user "root"
    command "chown :#{hdgroup} -R #{name.strip}"
  end
end

execute "change permissions for /usr/share/hadoop" do
  user "root"
  command "chmod -R g+rwx /usr/share/hadoop"
end

# Create hadoop dir for hdfs --------------------------------------------------

directory "/var/hadoop" do
  owner hduser
  group hdgroup
  mode 0770
  recursive true
  action :create
end

# Setup hadoop config files ---------------------------------------------------

["hadoop-env.sh", "core-site.xml", "hdfs-site.xml", "mapred-site.xml"].each do |file|
  template "/etc/hadoop/#{file}" do
    source file
    mode 0644
    owner "root"
    group hdgroup
  end
end

# Set JAVA_HOME ---------------------------------------------------------------

bash "append JAVA_HOME to /home/#{hduser}/.bashrc" do
  user hduser
  code <<-EOS
      echo "export JAVA_HOME=#{node['single_node_hadoop_claster']['java']['java_home']}" >> /home/#{hduser}/.bashrc
      source /home/#{hduser}/.bashrc
  EOS
  not_if "grep -q JAVA_HOME /home/#{hduser}/.bashrc"
end

bash "append JAVA_HOME to /etc/hadoop/hadoop-env.sh" do
  user "root"
  code <<-EOS
      echo "export JAVA_HOME=#{node['single_node_hadoop_claster']['java']['java_home']}" >> /etc/hadoop/hadoop-env.sh
  EOS
  not_if "grep -q JAVA_HOME /etc/hadoop/hadoop-env.sh"
end

# Format namenode -------------------------------------------------------------

execute "format namenode" do
  command "hadoop namenode -format"
  user hduser
  action :run
  not_if { ::File.exists?("/var/hadoop/tmp/dfs/name/") }
end
