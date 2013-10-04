hduser = 'hduser'

# Create a user and a group ---------------------------------------------------

group "hadoop"

user hduser do
  supports :manage_home => true
  home "/home/#{hduser}"
  gid "hadoop"
  shell "/bin/bash"
end

# Setup SSH -------------------------------------------------------------------

execute "generate ssh keys for #{hduser}." do
  user hduser
  command <<-SHELL
    ssh-keygen -t rsa -q -f /home/#{hduser}/.ssh/id_rsa -P ""
    cat /home/#{hduser}/.ssh/id_rsa.pub >> /home/#{hduser}/.ssh/authorized_keys
  SHELL
  not_if { File.exist?("/home/#{hduser}/.ssh/id_rsa.pub") }
end

# Disable ipv6 ----------------------------------------------------------------

config_file = "/etc/sysctl.conf"

lines = <<-COMMANDS
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
COMMANDS

lines.each_line do |line|
  execute "add #{line} to #{config_file}" do
    command "echo '#{line}' >> #{config_file}"
    only_if { File.readlines(config_file).detect { |l| l.include?(line)}.nil? }
  end
end
