require 'mechanize'
require_relative 'helpers/push_bullet'
require_relative 'helpers/sys_logger'
require_relative 'helpers/secrets'

GOES_LOGIN_URL = 'https://goes-app.cbp.dhs.gov/goes/jsp/login.jsp'
GOES_DATA_URL = 'https://goes-app.cbp.dhs.gov/goes/HomePagePreAction.do'

def login(page)
  SysLogger.logger.info "=> Logging in"
  page.form_with(action: '/goes/security_check') do |f|
    f['j_username']  = Secrets.secrets['goes_username']
    f['j_password']  = Secrets.secrets['goes_password']
  end.click_button
end

def scrape(mechanize)
  SysLogger.logger.info "=> Scraping Table Data"
  main_page = mechanize.get(GOES_DATA_URL)
  table = main_page.css('.appcontent').first.css('table').first

  headers = table.css('th').map(&:text)
  data = table.css('td').map do |td|
    td.text.gsub(/^\s*/, '').gsub(/\s*$/, '').strip
  end
  headers.zip(data).to_h
end

def notify(status)
  SysLogger.logger.info "=> Sending to push bullet"
  body = status.map { |e| e.join(": ") }.join(", ")
  if PushBullet.send("Nexus Update (#{status['Status']})", body)
    SysLogger.logger.info "=> Successfully sent"
  else
    SysLogger.logger.error "=> Failed to send"
  end
end

mechanize = Mechanize.new

SysLogger.logger.info "Scraping Nexus Status"
SysLogger.logger.info "=> Scraping Login Page"

mechanize.get(GOES_LOGIN_URL) do |page|
  login_page = login(page)
  status = scrape(mechanize)
  notify(status)
end
