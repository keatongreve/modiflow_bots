require 'optparse'
require 'octokit'

options = { 
  login: nil,
  password: nil,
  repo: nil,
  master_branch: nil,
  develop_branch: nil,
  release_branch: nil,
  title: nil,
  body: nil
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

  opts.on('-d', '--develop develop', 'Develop branch') do |develop_branch|
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

options.each do |k, v|
  raise OptionParser::MissingArgument, k if v.nil?
end

client = Octokit::Client.new(login: options[:login], password: options[:password])

user = client.user
repo = client.repository(options[:repo]) 
branches = client.branches(options[:repo])

master_branch = branches.find { |b| b.name == options[:master_branch] }
raise ArgumentError.new, "branch '#{options[:master_branch]}' does not exist" unless master_branch

develop_branch = branches.find { |b| b.name == options[:develop_branch] }
raise ArgumentError.new, "branch '#{options[:develop_branch]}' does not exist" unless develop_branch

release_branch = branches.find { |b| b.name == options[:release_branch] }

if options[:verbose]
  puts "master: #{master_branch.inspect}" 
  puts "develop: #{develop_branch.inspect}"
  puts "release: #{release_branch.inspect}"
end

if release_branch.nil?
  puts "Creating ref heads/#{options[:release_branch]} with SHA = #{develop_branch.commit.sha} from #{options[:develop_branch]}"
  begin
    client.create_ref(options[:repo], "heads/#{options[:release_branch]}", develop_branch.commit.sha)
    puts "Ref created"
  rescue
    puts "Failed to create new ref"
    exit 1
  end
else
  puts "release branch #{options[:release_branch]} exists, commit SHA is #{release_branch.commit.sha}"
  if release_branch.commit.sha != develop_branch.commit.sha
    puts "WARNING: does not match #{options[:develop_branch]} commit SHA #{develop_branch.commit.sha}"
    puts "If this is intended, you can disregard this warning."
  end
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
