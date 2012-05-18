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
set :branch, "master"
set :repository_cache, "git_cache"
set :deploy_via, :remote_cache
set :normalize_asset_timestamps, false
set :keep_releases, 3

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
  host = "23.20.144.232"
  role :app, host
  role :web, host
  role :db,  host, :primary => true
end

task :staging do
  set :node_env, "staging"
  host = "staging.learni.st"
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
    # copy config.js file to remore repository
    top.upload("config.js", "#{release_path}/config.js", :via=> :scp)
  end

  desc "Restart EVERYTHING (...aka just forever)"
  task :restart, :roles => :app, :except => { :no_release => true } do
    npm.install
    forever.stop
    forever.start
  end
end

namespace :npm do
  task :install, :roles => :app do
    run "cd #{current_path} && npm install"
  end
end

set :forever_params, ""
#set :forever_params, "-o log/whistlepunk_stdout.log -e log/whistlepunk_stderr.log"

namespace :forever do
  desc "Start forever on whistlepunk"
  task :start, :roles => :app do
    run "cd #{current_path} && TZ=US/Pacific NODE_ENV=#{node_env} forever #{forever_params} start whistlepunk.js"
  end
  
  desc "Stop forever on whistlepunk"
  task :stop, :roles => :app do
    run "cd #{current_path} && TZ=US/Pacific NODE_ENV=#{node_env} forever stop whistlepunk.js; true"
    run "while cd #{current_path} && forever list 2>&1 | egrep -q 'whistlepunk.js'; do echo waiting for forever to stop whistlepunk; sleep 1; done"
  end

  desc "Print status of forever process and its monitored jobs"
  task :status, :roles => :app do
    run "cd #{current_path} && TZ=US/Pacific NODE_ENV=#{node_env} forever list"
  end
end

before 'deploy:update_code', 'deploy:setup'     # built-in recipe to set up basic directory paths for a first-time deployment
after  'deploy:update_code', 'deploy:finalize'  # runs our custom setup after the release path has been created
after  'deploy:update_code', 'deploy:cleanup'   # built-in recipe to remove old releases
# after  'deploy', 'newrelic:notice_deployment'   # record the deployment in New Relic
