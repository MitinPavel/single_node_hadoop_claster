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
