require 'HTTParty'

module Zambroni::HockeyApp

  class HockeyAppApiClient
    include HTTParty

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
        raise "Bro. Bad API token" if response.code == 400
      end

  end
end
