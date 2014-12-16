require 'optparse'
require 'httmultiparty'

# the  maximum number of available versions corresponding to the same git branch
GIT_BRANCH_VERSION_MAX_COUNT = 5

class HockeyAppApiClient
  include HTTMultiParty

  HOCKEYAPP_BASE_URI = 'https://rink.hockeyapp.net/api/2'

  base_uri HOCKEYAPP_BASE_URI
  headers 'Accept' => 'application/json'
  format :json

  def initialize(api_token)
    raise "No API Token Given" if api_token.nil?
    @api_token = api_token
    self.class.headers 'X-HockeyAppToken' => @api_token
    test_api_token
  end

  def get_apps
    response = self.class.get '/apps'
    response.parsed_response['apps']
  end

  def get_app_versions(app_id, options = {})
    response = self.class.get "/apps/#{app_id}/app_versions", options
    response.parsed_response['app_versions']
  end

  def delete_app_version(app_id, app_version_id)
    self.class.delete "/apps/#{app_id}/app_versions/#{app_version_id}"
  end

  private
    def test_api_token
      response = self.class.get '/apps'
      raise "Bro. Bad API token." if response.code == 400
    end

end

options = {
  token: nil,
  app_id: nil,
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: zambroni.rb [options]"

  opts.on('-t', '--token token', 'Your API token') do |token|
    options[:token] = token;
  end

  opts.on('-a', '--app app_id', 'Your App ID (the long one)') do |app_id|
    options[:app_id] = app_id;
  end
end

parser.parse!

if options.values.all?(&:nil?)
  puts parser.to_s
  exit
end

client = HockeyAppApiClient.new(options[:token])

apps = client.get_apps
app = apps.find { |a| a['public_identifier'] == options[:app_id] }

raise "Bro. Could not find app with id #{options[:app_id]}." unless app

versions = client.get_app_versions(options[:app_id])
  .select { |v| v['status'] >= 0 }
  .sort_by! { |v| v['timestamp'] }

def group_app_versions_by_git_branch(app_versions)
  app_versions_grouped = {}
  app_versions.each do |version|
    version_string = version['version']
    match = version_string.match(/(\d*\.\d*\.\d*)\.?\w*\s?(\([\w\.\-]*\))?/i)
    appstore_version, git_branch = match.captures
    version_group_string = "#{appstore_version} #{git_branch}"
    version_group_string = appstore_version if git_branch.nil?
    if app_versions_grouped[version_group_string]
      app_versions_grouped[version_group_string] << version
    else
      app_versions_grouped[version_group_string] = [version]
    end
  end
  app_versions_grouped
end

grouped = group_app_versions_by_git_branch(versions)
grouped.each do |group, app_versions|
  if app_versions.length > GIT_BRANCH_VERSION_MAX_COUNT
    puts "#{group} has more than #{GIT_BRANCH_VERSION_MAX_COUNT} versions. Cleaning up."
    app_versions.take(app_versions.length - GIT_BRANCH_VERSION_MAX_COUNT).each do |app_version|
      version_id = app_version['id']
      puts "Deleting #{group} - #{version_id}"
      client.delete_app_version(options[:app_id], version_id)
    end
  end
end
