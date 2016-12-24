require 'remote_syslog_logger'

class SysLogger
  def self.logger
    RemoteSyslogLogger.new('logs2.papertrailapp.com', 26759)
  end
end
