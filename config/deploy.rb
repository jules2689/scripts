require 'byebug'

lock '3.7.1'

set :application,     'scripts'
set :repo_url,        'git@github.com:jules2689/scripts.git'
set :user,            'root'
set :linked_dirs,     %w(log pids)
set :environment,     'production'
set :linked_files,    %w(config/secrets.production.ejson)

namespace :secrets do
  desc 'Sync local secrets to production'
  task :sync do
    on roles(:app) do
      within shared_path do
        if File.exist?('config/secrets.production.ejson')
          secrets = File.read('config/secrets.production.ejson')
          upload! StringIO.new(secrets), "#{shared_path}/config/secrets.production.ejson"
          execute "/opt/rubies/ruby-2.3.3/bin/ejson decrypt #{shared_path}/config/secrets.production.ejson > #{shared_path}/config/secrets.json"
        end
      end
    end
  end
end

namespace :deploy do
  desc 'Make sure local git is in sync with remote.'
  task :check_revision do
    on roles(:app) do
      unless `git rev-parse HEAD` == `git rev-parse origin/master`
        puts 'WARNING: HEAD is not the same as origin/master'
        puts 'Run `git push` to sync changes.'
        exit
      end
    end
  end

  desc "Start Scripts"
  task :start_scripts do
    yaml_config = YAML.load_file('config/config.yml')
    on roles(:app) do
      cron_lines = []
      reboot_scripts = []

      # Parse config file into scripts
      yaml_config.each do |script|
        if script.key?('schedule')
          script_path = "#{current_path}/lib/scripts/#{script['name']}"
          cron_lines << "#{script['schedule']} /usr/local/bin/ruby #{script_path} 1> #{shared_path}/log/#{script['name']}.log 2>&1"
        elsif script.key?('background')
          reboot_scripts << [script, "#{current_path}/lib/scripts/#{script['name']}"]
        end
      end

      # Setup daemon file
      if reboot_scripts.empty?
        execute "/usr/local/bin/ruby /etc/daemon stop"
        upload! StringIO.new("require 'daemons'", "/etc/daemon")
      else
        daemon = ["require 'daemons'"]
        daemon += reboot_scripts.map do |script, script_path|
          hash_options = {
            keep_pid_files: true,
            dir_mode: :normal,
            dir: "#{shared_path}/pids",
            log_output: true,
            logfilename: "#{shared_path}/log/#{script['name']}.log"
          }.inspect
          "Daemons.run('#{script_path}', #{hash_options})"
        end
        upload! StringIO.new(daemon.join("\n")), "/etc/daemon"

        # Restart Daemon
        execute "/usr/local/bin/ruby /etc/daemon restart"
      end

      # Update/Setup Crontab
      new_crontab = cron_lines.join("\n") + "\n\n" + "@reboot /usr/local/bin/ruby /etc/daemon restart" + "\n"
      upload! StringIO.new(new_crontab), "#{current_path}/config/crontab"
      execute "crontab < #{current_path}/config/crontab"
    end
  end

  before :starting,  :check_revision
  after  :starting,  'bundler:install'
  before :finishing, 'secrets:sync'
  before :finishing, :start_scripts
end
