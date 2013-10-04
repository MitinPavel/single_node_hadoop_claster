hduser = 'hduser'

# Create a user and a group
group "hadoop"

user hduser do
  supports :manage_home => true
  home "/home/#{hduser}"
  gid "hadoop"
  shell "/bin/bash"
end

# Setup SSH
execute "generate ssh keys for #{hduser}." do
  user hduser
  command <<-SHELL
    ssh-keygen -t rsa -q -f /home/#{hduser}/.ssh/id_rsa -P ""
    cat /home/#{hduser}/.ssh/id_rsa.pub >> /home/#{hduser}/.ssh/authorized_keys
  SHELL
end
