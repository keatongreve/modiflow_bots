require 'optparse'
require 'octokit'
require 'httparty'

options = {
  login: nil,
  password: nil,
  repo: nil,
  master_branch: nil,
  release_branch: nil,
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: gatekeeper.rb [options]"

  opts.on('-l', '--login login', 'Login (username or email)') do |login|
    options[:login] = login;
  end

  opts.on('-p', '--password password', 'Password') do |password|
    options[:password] = password;
  end

  opts.on('--repo repo', 'Repository name') do |repo|
    options[:repo] = repo;
  end

  opts.on('-m', '--master master', 'Master/stable branch') do |master_branch|
    options[:master_branch] = master_branch;
  end

  opts.on('--release release', 'Release candidate branch name (created if doesn\'t exist)') do |release_branch|
    options[:release_branch] = release_branch;
  end
end

parser.parse!


Octokit.auto_paginate = true
client = Octokit::Client.new(login: options[:login], password: options[:password])

user = client.user
repo = client.repository(options[:repo])

begin
  release_branch = client.branch(options[:repo], options[:release_branch])
rescue Octokit::NotFound
  raise ArgumentError.new, "branch '#{options[:release_branch]}' does not exist"
end

open_pulls = client.pull_requests(options[:repo], { state: 'open', base: options[:master_branch] })

rc_pull = open_pulls.select { |p| p[:head][:ref] == options[:release_branch] }.first
rc_commits = client.pull_request_commits(options[:repo], rc_pull[:number])

rc_commits_formatted = rc_commits.map do |commit|
    commit_msg = commit[:commit][:message]
    newline_index = commit_msg.index("\n")
    commit_msg = commit_msg[0..newline_index].strip unless newline_index.nil?
    { url: commit[:html_url], message: commit_msg }
  end

# PRs into develop before the RC was created
rc_features = rc_commits_formatted.select { |c|
  match = c[:message].match /Merge pull request #(\d*)/
  c[:pr_number] = match.captures[0] if match
  match
}

rc_features.each { |c| puts "#{c[:url]} - #{c[:message]}" }
puts rc_features.length

# print for easy markdown easy live
rc_features.each do |c|
  puts "[#{c[:message]}](https://github.com/hudl/modi/pull/#{c[:pr_number]})"
end
