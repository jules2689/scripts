loop do
  logger = Logger.new('/etc/log/script2.log')
  logger.info 'Logging background'
  sleep 1
end
