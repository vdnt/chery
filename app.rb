require 'sinatra'
require 'chef-api'
require 'json'

include ChefAPI::Resource

before do
  cache_control :public, :must_revalidate, :max_age => 30
end

helpers do
  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Authentication required"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == ['user', 'somebasicauthpassword']
  end
end

ChefAPI.configure do |config|
  config.endpoint = 'https://chef.server.com/organizations/name' # Chef Server/Organization
  config.flavor = :open_source
  config.client = 'client.server.fqdn.com' # Client Name
  config.key    = '/etc/chef/client.pem' # Client PEM file
  config.ssl_verify = true
end

get '/' do
  "OK"
end

get '/nodes?*' do
  protected!
  content_type :json

  params = request.env['rack.request.query_hash']
  search_query = params.map { |k, v| "#{k}:#{[v].flatten.join(';')}" }.join(' AND ')

  unless params.empty?
    nodes = {}
    query = Search.query(:node, search_query)
    query.rows.each do |row|
      nodes[row['name']] = { fqdn: row['automatic']['fqdn'],
                             hostname: row['automatic']['hostname'],
                             tags: row['normal']['tags'],
                             ip: row['automatic']['ipaddress'] }
    end
    nodes.sort.to_json
  else
    'No nodes found. Add some parameters.'.to_json
  end
end
