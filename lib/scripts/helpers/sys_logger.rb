require 'remote_syslog_logger'

class SysLogger
  def self.logger
    logger = RemoteSyslogLogger.new('logs2.papertrailapp.com', 26759)
    logger.formatter = proc { |severity, datetime, _, msg|
      "#{severity} [#{caller[4]}] [#{datetime}] #{msg}\n"
    }
    logger
  end
end
