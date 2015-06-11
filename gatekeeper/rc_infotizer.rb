require 'optparse'
require 'octokit'
require 'httparty'

options = {
  login: nil,
  password: nil,
  token: nil,
  repo: nil,
  master_branch: nil,
  release_branch: nil,
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: gatekeeper.rb [options]"

  opts.on('-l', '--login login', 'GitHub login (username or email)') do |login|
    options[:login] = login
  end
  
  opts.on('-p', '--password password', 'GitHub password') do |password|
    options[:password] = password
  end
  
  opts.on('-t', '--token token', 'GitHub access token (overrides username and password)') do |token|
    options[:token] = token
  end
  
  opts.on('--repo repo', 'Repository name') do |repo|
    options[:repo] = repo
  end
  
  opts.on('-m', '--master master', 'Master/stable branch (default is master)') do |master_branch|
    options[:master_branch] = master_branch
  end
  
  opts.on('--release release', 'Release candidate branch name (pull request should already be open)') do |release_branch|
    options[:release_branch] = release_branch
  end
end

parser.parse!

if options.values.all?(&:nil?)
  puts parser.to_s
  exit
end

options[:master_branch] = 'master' unless options[:master_branch]

abort "Please provide a repository name (--repo)." unless options[:repo]
abort "Please provide a release/RC branch name (--release)." unless options[:release_branch]

Octokit.auto_paginate = true

if options[:token]
  client = Octokit::Client.new(access_token: options[:token])
elsif options[:login] && options[:password]
  client = Octokit::Client.new(login: options[:login], password: options[:password])
else
  abort "No GitHub authentication credentials. Please provide a username/login or an access token"
end

user = client.user

begin
  repo = client.repository(options[:repo])
  puts "Cloning/pulling git repo #{options[:repo]} on another thread"
  git_repo_dir = "infotizer_tmp_#{options[:repo]}".gsub!(/\W/,'')
  thread = Thread.new {
    if Dir.exist? git_repo_dir
      puts "dir exists, pulling"
      `cd #{git_repo_dir} && git pull`
    else
      "dir does not exist, cloning new"
      `git clone git@github.com:#{options[:repo]}.git #{git_repo_dir}`
    end
  }
rescue Octokit::NotFound
  abort "Repo '#{options[:repo]} could not be found."
end

begin
  release_branch = client.branch(options[:repo], options[:release_branch])
rescue Octokit::NotFound
  abort "branch '#{options[:release_branch]}' does not exist"
end

open_pulls = client.pull_requests(options[:repo], { state: 'open', base: options[:master_branch] })

rc_pull = open_pulls.select { |p| p[:head][:ref] == options[:release_branch] }.first

thread.join

Dir.chdir git_repo_dir
master_commits = `git log --oneline --reverse origin/#{options[:master_branch]}`.split("\n")
rc_commits = `git log --oneline --reverse origin/#{options[:release_branch]}`.split("\n")

rc_commits_diff = rc_commits - master_commits
puts rc_commits_diff
puts rc_commits_diff.length

rc_commit_links = rc_commits_diff.map do |commit|
  c = {}
  match = commit.match /Merge pull request #(\d*)/
  if match
    c[:pr_number] = match.captures[0] 
    c[:text] = commit.split(" ")[1..commit.split(" ").length-1].join(" ")
    c[:url] = "https://github.com/#{options[:repo]}/pull/#{c[:pr_number]}"
    c
  else
    nil
  end
end.compact

body_text =  rc_commit_links.map do |c| 
 "[#{c[:text]}](#{c[:url]})"
end.join("\n")

puts "RC pull request \# is #{rc_pull[:number]}"
puts body_text
client.update_pull_request(options[:repo], rc_pull[:number], { body: body_text })
