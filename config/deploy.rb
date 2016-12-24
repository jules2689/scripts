require 'byebug'

lock '3.7.1'

set :application,     'scripts'
set :repo_url,        'git@github.com:jules2689/scripts.git'
set :user,            'root'
set :chruby_ruby,     'ruby-2.3.1'
set :linked_dirs,     %w(log)
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
      within current_path do
        cron_lines = []
        reboot_scripts = []

        yaml_config.each do |script|
          if script.key?('schedule')
            script_path = "#{current_path}/lib/scripts/#{script['name']}"
            cron_lines << "#{script['schedule']} /usr/local/bin/ruby #{script_path} 1> #{shared_path}/log/#{script['name']}.log 2>&1"
          elsif script.key?('background')
            reboot_scripts << [script, "#{current_path}/lib/scripts/#{script['name']}"]
          end
        end

        daemon = ["require 'daemons'"]
        daemon += reboot_scripts.map do |script, script_path|
          "Daemon.run('#{script_path}', { log_output: true, logfilename: '#{shared_path}/log/#{script['name']}.log' })"
        end
        upload! StringIO.new(daemon.join("\n")), "/etc/daemon"
        execute "/usr/local/bin/ruby /etc/daemon"

        new_crontab = cron_lines.join("\n") + "\n\n" + "@reboot /etc/daemon"
        upload! StringIO.new(new_crontab), "#{current_path}/config/crontab"
        execute "crontab < #{current_path}/config/crontab"
      end
    end
  end

  before :starting,  :check_revision
  before :starting,  'secrets:sync'
  before :finishing, :start_scripts
end
