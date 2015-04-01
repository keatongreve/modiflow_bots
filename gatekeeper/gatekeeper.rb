require 'optparse'
require 'octokit'

options = {
  login: nil,
  password: nil,
  token: nil,
  repo: nil,
  master_branch: nil,
  develop_branch: nil,
  release_branch: nil,
  title: nil,
  body: nil
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: gatekeeper.rb [options]"

  opts.on('-l', '--login login', 'GitHub login (username or email)') do |login|
    options[:login] = login;
  end

  opts.on('-p', '--password password', 'GitHub password') do |password|
    options[:password] = password;
  end

  opts.on('--token token', 'GitHub access token (overrides username and password)') do |token|
    options[:token] = token;
  end

  opts.on('--repo repo', 'Repository name') do |repo|
    options[:repo] = repo;
  end

  opts.on('-m', '--master master', 'Master/stable branch (default is master)') do |master_branch|
    options[:master_branch] = master_branch;
  end

  opts.on('-d', '--develop develop', 'Develop branch (default is develop)') do |develop_branch|
    options[:develop_branch] = develop_branch;
  end

  opts.on('--release release', 'Release candidate branch name (created if doesn\'t exist)') do |release_branch|
    options[:release_branch] = release_branch;
  end

  opts.on('--title title', 'Pull request title') do |title|
    options[:title] = title;
  end

  opts.on('--body body', 'Pull request body') do |body|
    options[:body] = body;
  end

  opts.on('-v', '--verbose', 'Enable verbose output') do |verbose|
    options[:verbose] = true
  end
end

parser.parse!

if options.values.all?(&:nil?)
  puts parser.to_s
  exit
end

options[:master_branch] = 'master' unless options[:master_branch]
puts "master branch is '#{options[:master_branch]}'."
options[:develop_branch] = 'develop' unless options[:develop_branch]
puts "develop branch is '#{options[:develop_branch]}'."
options[:body] = '' unless options[:body]


abort "Please provide a repository name (--repo)." unless options[:repo]
abort "Please provide a release/RC branch name (--release)." unless options[:release_branch]
abort "Please specify a PR title (--title)." unless options[:title]

if options[:token]
  client = Octokit::Client.new(access_token: options[:token])
elsif options[:login] && options[:password]
  client = Octokit::Client.new(login: options[:login], password: options[:password])
else
  raise "No GitHub authentication credentials. Please provide a username/login or an access token"
end

user = client.user
begin
  repo = client.repository(options[:repo])
rescue Octokit::NotFound
  abort "Repo '#{options[:repo]} could not be found."
end

begin
  master_branch = client.branch(options[:repo], options[:master_branch])
rescue Octokit::NotFound
  raise ArgumentError.new, "branch '#{options[:master_branch]}' does not exist"
end

begin
  develop_branch = client.branch(options[:repo], options[:develop_branch])
rescue Octokit::NotFound
  raise ArgumentError.new, "branch '#{options[:develop_branch]}' does not exist"
end

begin
  release_branch = client.branch(options[:repo], options[:release_branch])

  puts "release branch #{options[:release_branch]} exists, commit SHA is #{release_branch.commit.sha}"
  if release_branch.commit.sha != develop_branch.commit.sha
    puts "WARNING: does not match #{options[:develop_branch]} commit SHA #{develop_branch.commit.sha}"
    puts "If this is intended, you can disregard this warning."
  end
rescue Octokit::NotFound
  puts "Creating ref heads/#{options[:release_branch]} with SHA = #{develop_branch.commit.sha} from #{options[:develop_branch]}"
  begin
    client.create_ref(options[:repo], "heads/#{options[:release_branch]}", develop_branch.commit.sha)
    puts "Ref created"
  rescue
    puts "Failed to create new ref"
    exit 1
  end
end

if options[:verbose]
  puts "master: #{master_branch.inspect}"
  puts "develop: #{develop_branch.inspect}"
  puts "release: #{release_branch.inspect}"
end

pull_requests = client.pull_requests(options[:repo], state: 'open')
if pull_requests.any? { |pr| pr[:head][:ref] == options[:release_branch] && pr[:base][:ref] == options[:master_branch] }
  puts "WARNING: Pull request already exists from #{options[:release_branch]} to #{options[:master_branch]}."
  puts "Nothing to do here."
else
  puts "Creating pull request from #{options[:release_branch]} to #{options[:master_branch]}"
  begin
    client.create_pull_request(options[:repo],
      options[:master_branch],
      options[:release_branch],
      options[:title],
      options[:body])
    puts "Pull request created"
  rescue Octokit::UnprocessableEntity => e
    puts "ERROR Failed to create pull request!"
    puts e.message
    exit 2
  end
end
