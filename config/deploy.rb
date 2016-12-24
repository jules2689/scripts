# config valid only for current version of Capistrano
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
        yaml_config.each do |script|
          if script.key?('schedule')
            cron_line = "#{script['schedule']} #{current_path}/lib/scripts/#{script['name']}"
            crontab_add(cron_line)
          elsif script.key?('background')
            execute :ruby, "#{current_path}/lib/scripts/#{script['name']} &"
          end
        end
      end
    end
  end

  def crontab_add(line)
    config = capture(%(crontab -l).split("\n"))
    return if config.include?(line)
    run %((crontab -l; echo "#{line}") | crontab -)
  end

  # desc "Start Job"
  # task :start do
  #   on roles(:app) do
  #     within current_path do
  #       with RACK_ENV: fetch(:environment) do
  #         latest_release = capture("ls #{fetch(:deploy_to)}/releases | sort").split("\n").last
  #         puts "Latest Release was #{latest_release}"
  #         execute :bundle, :exec, '/opt/rubies/ruby-2.3.1/bin/ruby',
  #           "#{fetch(:deploy_to)}/releases/#{latest_release}/slack_eyes_daemon.rb", 'start'
  #       end
  #     end
  #   end
  # end

  # desc "Kill the old Job"
  # task :kill_old_app do
  #   on roles(:app) do
  #     within current_path do
  #       with RACK_ENV: fetch(:environment) do
  #         latest_release = capture("ls #{fetch(:deploy_to)}/releases | sort").split("\n").last
  #         puts "Latest Release was #{latest_release}"
  #         execute "kill -9 $(cat #{fetch(:deploy_to)}/releases/#{latest_release}/config.ru.pid) || true"
  #       end
  #     end
  #   end
  # end

  # desc "Check that the job is running"
  # task :check_running do
  #   on roles(:app) do
  #     within current_path do
  #       with RACK_ENV: fetch(:environment) do
  #         latest_release = capture("ls #{fetch(:deploy_to)}/releases | sort").split("\n").last
  #         puts "Latest Release was #{latest_release}"
  #         execute :bundle, :exec, '/opt/rubies/ruby-2.3.1/bin/ruby',
  #           "#{fetch(:deploy_to)}/releases/#{latest_release}/slack_eyes_daemon.rb", 'status'
  #       end
  #     end
  #   end
  # end

  before :starting,  :check_revision
  before :starting,  'secrets:sync'
  # before :finishing, :start
  # after  :finishing, :check_running
end
