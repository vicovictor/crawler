require 'rubygems'
require 'cgi'
require 'json'
require 'mechanize'
require 'mysql2'
require 'byebug'

DB_HOST = ''
DB_USERNAME = ''
DB_PASSWORD = ''
DB_NAME = 'spidy'
SEED_TABLE_NAME = 'spider_raw'
TARGET_TABLE_NAME = 'crawled_urls'
USER_AGENT_ALIAS_SAMPLES = [
  'Linux Firefox',
  'Linux Konqueror',
  'Linux Mozilla',
  'Mac Firefox',
  'Mac Mozilla',
  'Mac Safari 4',
  'Mac Safari',
  "Windows Chrome",
  "Windows IE 10",
  "Windows IE 11",
  "Windows Edge",
  "Windows Mozilla",
  "Windows Firefox"
]

def insert_to_target(hash, con)
  statement = "
    INSERT INTO
      #{TARGET_TABLE_NAME}
    SET
      #{hash.map { |k, v| "#{k} = '#{v}'" }.join(', ')};
  "
  con.query(statement)
end

def get_base_url
  begin
    con = Mysql2::Client.new(host: DB_HOST, username: DB_USERNAME, password: DB_PASSWORD, database: DB_NAME)
    @base_url = con.query("select * from #{SEED_TABLE_NAME} where crawled = 0 order by id asc limit 1;")
    @base_url = @base_url.first
    con.query("update #{SEED_TABLE_NAME} set crawled = 1 where id = #{@base_url['id']};")
    @base_url
  rescue Mysql2::Error => e
    p e
  ensure
    con.close if con
  end
end

def crawl_base_url
  begin
    con = Mysql2::Client.new(host: DB_HOST, username: DB_USERNAME, password: DB_PASSWORD, database: DB_NAME)

    agent_page = Mechanize.new
    agent_page.user_agent_alias = USER_AGENT_ALIAS_SAMPLES[Random.rand(0..12)]
    base_page = agent_page.get('http://www.' + @base_url['url'])
    page_links = base_page.links

    if !page_links.nil?
      page_links.each do |link|
        href = link.href
        uri = URI.parse(href)
        p href
        if uri.host.nil?
          decorated_url = "http://www.#{@base_url['url']}/#{href}".gsub(Regexp.new('(?<!http:)(?<!https:)//'), '/')
          insert_to_target({ url: decorated_url }, con)
        elsif /#{@base_url['url']}/.match(uri.host)
          if href.start_with?('http')
            insert_to_target({ url: href }, con)
          else
            decorated_url = href.prepend('http:')
            insert_to_target({ url: decorated_url }, con)
          end
        end
      end
    end
  rescue Mysql2::Error => e
    p e
  ensure
    con.close if con
  end
end

def crawl
  crawl_base_url unless get_base_url.nil?
end

crawl
