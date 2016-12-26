Scripts
---

Runs a set of Ruby scripts on a schedule or constantly in the background.

`config.yml` defines a set of scripts that run using cron or using a background daemon. Capistrano sets up the scripts to run as needed.

`lib/scripts` contains the scripts that are running.

Manual Steps (for now):
1. Install Ruby (2.3.3)
2. Manually install `bundler`, `daemons`, `remote_syslog_logger`, `ejson` gems
3. Install the proper ejson private key
