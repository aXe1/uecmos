require 'rack'
require 'httparty'
require 'json'
require 'sinatra'
require 'data_mapper'
require 'haml'


helpers do
  def get_json_str(num)
    url = 'http://www.uec.mos.ru/bitrix/templates/UEKpromo/scripts/req-status.php'
    HTTParty.post(url, body:{num:num}).to_s
  end
end

configure do
  use Rack::Deflater
  # disable :show_exceptions

  db_path = 'statuses.db'
  if development?
    db_path = File.join(File.expand_path('tmp'), db_path)
  else
    db_path = File.join(ENV['OPENSHIFT_DATA_DIR '], db_path)
  end
  DataMapper.setup(:default, adapter:'sqlite3', path:db_path)

  class Status
    include DataMapper::Resource

    property :id,         Serial
    property :num,        String, :length => 15
    property :data,       Text
    property :fetched_at, DateTime
  end

  DataMapper.finalize
  DataMapper.auto_upgrade!
end

template :atom_feed do
<<EOS
!!! XML
%feed{xmlns: 'http://www.w3.org/2005/Atom'}
  %title= num
  %updated= last.fetched_at
  - statuses = Status.all(num:num, order:[:fetched_at.asc])
  - statuses.each do |status|
    - json = {}
    - begin
      - json = JSON(status.data)
    - rescue
    - if json['status'] && json['notice']
      %entry
        %title= json['status']
        %summary= json['notice']
        %updated= status.fetched_at
EOS
end

get '/?' do
  '<form action="/request_atom" method="get"><input type="text" name="num"><input type="submit"></form>'
end

get '/request_atom' do
  redirect "/request/#{params[:num]}/atom.xml"
end

get '/request/:num/atom.xml' do
  num = params[:num]
  halt 404, '<h1>Недопустимый формат номера заявления.</h1><br>формат: 000000-00000000' unless num =~ /\A\d{6}-\d{8}\z/
  
  json_str = get_json_str(num)

  last = Status.last(num:num)
  if last.nil? || json_str != last.data
    last = Status.create(num:num, data:json_str, fetched_at:Time.now)
  end


  content_type 'application/atom+xml;charset=utf-8'
  haml :atom_feed, locals:{num:num, last:last}
end