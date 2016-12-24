require_relative 'helpers/sys_logger'

loop do
  SysLogger.logger.info "Logging background in script2.rb"
  sleep 60
end
