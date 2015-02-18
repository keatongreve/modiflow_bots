command :clean do |c|
  c.syntax = 'zambroni clean [options]'
  c.summary = 'Delete old HockeyApp versions'
  c.description = ''

  c.option '--app APP_VERSION_ID', String, 'The long App ID'
  c.option '--token API_TOKEN', String, 'Your API auth token'

  c.action do |args, options|

    # the  maximum number of available versions corresponding to
    # the same git branch
    GIT_BRANCH_VERSION_MAX_COUNT = 3

    token = options.token
    @app_id = options.app
    @client = Zambroni::HockeyApp::HockeyAppApiClient.new(token)

    apps = @client.get_apps
    app = apps.find { |a| a['public_identifier'] == @app_id }

    raise "Bro. Could not find app with ID #{@app_id}." unless app

    versions = @client.get_app_versions(@app_id)
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
          @client.delete_app_version(@app_id, version_id)
        end
      end
    end

  end
end
