command :clean do |c|
  c.syntax = 'zambroni clean [options]'
  c.summary = 'Delete old HockeyApp versions'
  c.description = %(
      Finds all existing versions in your HockeyApp app, and groups them by
      the branch they were built from. Your long version string should have the
      format MAJOR.MINOR.PATCH.REVISION (BRANCH_NAME). If the (BRANCH_NAME) is
      not  included, then the app versions are grouped by exact version. Then
      zambroni will sort them by date created, and delete all but the 3 newest
      versions in that group. If you add GitHub credentials, it will delete all
      builds for a branch that is no longer on origin.
    ).gsub(/\s+/, " ").strip

  c.option '--app APP_VERSION_ID', String, 'The long App ID'
  c.option '--token API_TOKEN', String, 'Your API auth token'
  c.option '--gh_user GITHUB_USERNAME', String, 'Your username to log into GitHub'
  c.option '--gh_pass GITHUB_PASSWORD', String, 'Your password to log into GitHub'
  c.option '--gh_token GITHUB_API_TOKEN', String, 'Your API token for GitHub (overrides username and password)'
  c.option '--gh_repo GITHUB_REPO', String, 'The repo for the source code for your HockeyApp builds'
  c.action do |args, options|

    # the  maximum number of available versions corresponding to
    # the same git branch
    GIT_BRANCH_VERSION_MAX_COUNT = 3

    token = options.token
    @app_id = options.app
    @client = Zambroni::HockeyApp::HockeyAppApiClient.new(token)

    if options.gh_user || options.gh_pass || options.gh_token || options.gh_repo

      # Check for sufficient --gh options
      # 1. User & password & repo
      # 2. Token & repo
      # 3. User & password & token & repo (user and password ignored)
      token = options.gh_token
      unless token
        raise "Need both --gh_user and --gh_pass if not using --gh_token" unless options.gh_user && options.gh_pass
      end
      raise "Need --gh_repo if using any GitHub authentication" unless options.gh_repo
      @repo = options.gh_repo

      if token
        @github_client = Octokit::Client.new(access_token: token)
      else
        @github_client = Octokit::Client.new(login: options.gh_user, password: options.gh_pass)
      end
    end

    apps = @client.get_apps
    app = apps.find { |a| a['public_identifier'] == @app_id }

    raise "Bro. Could not find app with ID #{@app_id}" unless app

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

      group_parts = group.split(" ")
      if group_parts.length == 2 && @github_client
        branch = group_parts[1].match(/\((.*)\)/).captures.first
        branch_exists = true
        begin
          @github_client.branch(@repo, branch)
        rescue Octokit::NotFound
          branch_exists = false
        end

        unless branch_exists
          puts "Deleting all builds for branch #{branch}"
          app_versions.each do |app_version|
            version_id = app_version['id']
            puts "Deleting #{group} - #{version_id}"
            @client.delete_app_version(@app_id, version_id)
          end
        end
      end

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
