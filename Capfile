##############################################################################
# Load general capistrano libraries

load 'deploy'
Dir['vendor/gems/*/recipes/*.rb','vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }

# require 'new_relic/recipes'

##############################################################################
# RVM support

$:.unshift(File.expand_path('./lib', ENV['rvm_path']))
require "rvm/capistrano"
set :rvm_type, :user
set :rvm_ruby_string, '1.9.3'

##############################################################################
# Internal capistrano options

default_run_options[:pty] = true
set :use_sudo, false

##############################################################################
# General deployment configuration

set :user, 'grockit'
set :application, 'whistlepunk'
set :deploy_to, "/opt/grockit/#{application}"
set :scm, :git
set :repository, "git@github.com:lotze/whistlepunk.git"
set :repository_cache, "git_cache"
set :deploy_via, :remote_cache
set :normalize_asset_timestamps, false
set :keep_releases, 3

set :branch, ENV['TAG'] || raise("TAG must be set; refusing to deploy from head of git repository")

##############################################################################
# Rails environments

task :virtual do
  set :node_env, "production"
  host = ENV['VIP']
  role :app, host
  role :web, host
  role :db,  host, :primary => true
end

task :production do
  set :node_env, "production"
  host = "metricizer"
  role :app, host
  role :web, host
  role :db,  host, :primary => true
end

task :staging do
  set :node_env, "staging"
  host = "staging-app-1"
  role :app, host
  role :web, host
  role :db,  host, :primary => true
end

task :stress do
  set :node_env, "production"
  host = "23.20.38.97"
  role :app, host
  role :web, host
  role :db,  host, :primary => true
end



########################################################################################
# Deployment recipes.  A few words about capistrano's built-in recipe structure: the
# default capistrano 'deploy' task works in several phases, some of which are built into
# capistrano and some of which capistrano expects us to define for ourselves.  Here's
# the overall structure:
#
#  deploy ->
#    deploy:update ->
#      transaction ->
#        deploy:update_code
#        deploy:create_symlink
#    deploy:restart
#
# Here are the significant steps:
#
#  1. deploy:update_code task checks out the new release directory and does
#     post-processing steps such as symlinking various paths within the release directory
#     into shared.
#  2. If deploy:update_code succeeds without rolling back, then and only then does
#     deploy:create_symlink switch the "current" symlink to point to the new release
#     directory.
#  3. If all goes well, capistrano invokes deploy:restart, which is OUR OWN task.
#
# This breakdown suggests some guidelines for developing capistrano tasks:
#
#  - Define one task to hook in 'before deploy:update_code'.  This task should contain
#    anything that needs to be run before the new release is checked out (e.g. ensuring
#    system dependencies are present, ensuring directory layout is correct).
#  - Define one task to hook in 'after deploy:update_code'.  This task should contain
#    anything and everything that should be run after the new code is in place, but before
#    restarting any processes (e.g. installing gems, running db migrations).
#  - Don't hook into any other task.  Confusing dependencies arise very quickly between
#    tasks, and these two hook points should be all you need.
#  - Anything else, apart from standalone utility tasks, must surely fit into
#    deploy:restart.


namespace :deploy do
  # internal task, no description string
  task :finalize, :roles => :app do
    # Set up custom directory layout in addition to capistrano's defaults
    run "mkdir -p #{shared_path}/tmp/pids"
    run "mkdir -p #{shared_path}/node_modules && ln -s #{shared_path}/node_modules #{release_path}/node_modules"
    # copy config.local.js file to shared remote repository; only replace it if it doesn't exist -- you will have to manually update if you change it
    if File.exists?("config.local.js")
      top.upload("config.local.js", "#{shared_path}/config.local.latest.js", :via => :scp)
    end
    run "[ -f '#{shared_path}/config.local.js' ] || cp '#{shared_path}/config.local.latest.js' '#{shared_path}/config.local.js'"
    # always copy from the shared version
    run "cp -f #{shared_path}/config.local.js #{release_path}/config.local.js"
    # Install new logrotate config, if any
    sudo "ln -sf #{current_path}/script/logrotate.conf /etc/logrotate.d/#{application}.conf"
    npm.install
    write_upstart_script
  end

  task :start, :roles => :app, :except => { :no_release => true } do
    run "sudo start #{application}_#{node_env}"
    run "sudo start preprocessor_#{node_env}"
  end

  task :stop, :roles => :app, :except => { :no_release => true } do
    run "sudo stop #{application}_#{node_env}"
    run "sudo stop preprocessor_#{node_env}"
  end

  desc "Restart ALL THE THINGS"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "sudo restart #{application}_#{node_env} || sudo start #{application}_#{node_env}"
    run "sudo restart preprocessor_#{node_env} || sudo start preprocessor_#{node_env}"
  end

  task :write_upstart_script, :roles => :app do
    write_upstart_template(self, application, "#{application}.coffee")
    write_upstart_template(self, 'preprocessor', "bin/preprocessor")
  end
  
  def write_upstart_template(cap, process, command)
    upstart_script = <<-UPSTART
description "#{process}"

start on startup
stop on shutdown

script
# We found $HOME is needed. Without it, we ran into problems
export HOME="/home/#{user}"
export NODE_ENV="#{node_env}"

cd #{current_path}
exec sudo -u #{user} sh -c "TZ=US/Pacific NODE_ENV=#{node_env} #{current_path}/node_modules/.bin/coffee #{current_path}/#{command} >> #{shared_path}/log/#{process}_#{node_env}.log 2>&1"
end script
respawn
UPSTART
    cap.put upstart_script, "/tmp/#{process}_upstart.conf"
    cap.run "sudo mv /tmp/#{process}_upstart.conf /etc/init/#{process}_#{node_env}.conf"
  end
end

namespace :npm do
  task :install, :roles => :app do
    run "cd #{release_path} && npm install"
  end
end

before 'deploy:update_code', 'deploy:setup'     # built-in recipe to set up basic directory paths for a first-time deployment
after  'deploy:update_code', 'deploy:finalize'  # runs our custom setup after the release path has been created
after  'deploy:update_code', 'deploy:cleanup'   # built-in recipe to remove old releases
# after  'deploy', 'newrelic:notice_deployment'   # record the deployment in New Relic
