#
# Cookbook Name:: activemq
# Recipe:: default
#
# Copyright 2009, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "java"

tmp = Chef::Config[:file_cache_path]
version = node['activemq']['version']
mirror = node['activemq']['mirror']
activemq_home = "#{node['activemq']['home']}/apache-activemq-#{version}"
activemq_user = node['activemq']['user']
activemq_group = node['activemq']['group']

user activemq_user do
  comment "activemq user"
  shell "/bin/bash"
  home activemq_home
end

unless File.exists?("#{activemq_home}/bin/activemq")
  remote_file "#{tmp}/apache-activemq-#{version}-bin.tar.gz" do
    source "#{mirror}/activemq/apache-activemq/#{version}/apache-activemq-#{version}-bin.tar.gz"
    mode "0644"
  end

  execute "tar zxf #{tmp}/apache-activemq-#{version}-bin.tar.gz" do
    cwd "/opt"
  end

  execute "chown -R #{activemq_user}:#{activemq_group} /opt/apache-activemq-#{version}"
end

file "#{activemq_home}/bin/activemq" do
  mode "0755"
end

# TODO: make this more robust
arch = (node['kernel']['machine'] == "x86_64") ? "x86-64" : "x86-32"

link "/etc/init.d/activemq" do
  to "#{activemq_home}/bin/linux-#{arch}/activemq"
end

execute "sed -i 's/^#RUN_AS_USER=/RUN_AS_USER=#{activemq_user}/' /opt/apache-activemq-5.5.0/bin/linux-x86-64/activemq"

service "activemq" do
  supports  :restart => true, :status => true
  action [:enable, :start]
end

# symlink so the default wrapper.conf can find the native wrapper library
link "#{activemq_home}/bin/linux" do
  to "#{activemq_home}/bin/linux-#{arch}"
  owner activemq_user
  group activemq_group
end

# symlink the wrapper's pidfile location into /var/run
link "/var/run/activemq.pid" do
  to "#{activemq_home}/bin/linux/ActiveMQ.pid"
  not_if "test -f /var/run/activemq.pid"
end

template "#{activemq_home}/bin/linux/wrapper.conf" do
  source "wrapper.conf.erb"
  owner activemq_user
  group activemq_group
  mode 0644
  variables(
    :pidfile => "/var/run/activemq.pid",
    :user => activemq_user
  )
  notifies :restart, 'service[activemq]'
end
