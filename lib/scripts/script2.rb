require_relative 'helpers/sys_logger'

loop do
  SysLogger.logger.info "#{Time.now} -> Logging background in script2.rb"
  sleep 1
end
