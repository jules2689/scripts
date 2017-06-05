require_relative 'helpers/push_bullet'
require_relative 'helpers/sys_logger'

def notify(reminder, body)
  SysLogger.logger.info "=> Sending to push bullet"
  if PushBullet.send(reminder, body)
    SysLogger.logger.info "=> Successfully sent"
  else
    SysLogger.logger.error "=> Failed to send"
  end
end

notify(ARGV.shift, ARGV.shift)
