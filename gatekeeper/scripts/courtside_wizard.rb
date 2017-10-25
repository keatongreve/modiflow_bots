require 'date'

DEFAULT_GITHUB_API_TOKEN = ENV["GITHUB_API_TOKEN"]
COURTSIDE_REPO = "hudl/courtside"
REPLAY_REPO = "hudl/SportsCodeNext"

puts "This script is specifically for the Courtside repos (Courtside and Replay)"
puts "Answer some questions and we'll generate some shell commands for you.\n"

current_script_dir = File.expand_path(File.dirname(__FILE__))
auto_gk = File.expand_path(current_script_dir + "/auto_gk")

gh_token = DEFAULT_GITHUB_API_TOKEN || ""
while gh_token.length == 0
  puts "No Github access token found in default env var ($GITHUB_API_TOKEN). You can set it then rerun this script."
  print "GitHub access token: "
  gh_token = gets.strip
end

courtside_rc_version = ""
while courtside_rc_version.length == 0
  print "Courtside RC version number: "
  courtside_rc_version = gets.strip
end

replay_rc_version = ""
while replay_rc_version.length == 0
  print "Hudl Replay RC version number: "
  replay_rc_version = gets.strip
end

puts "when do you want this to run?"
print "month (January is 1, December is 12): "
month = gets.strip.to_i
print "day: "
day = gets.strip.to_i
date = Date.new(Date.today.year, month, day)
date = Date.new(Date.today.year + 1, month, day) if date < Date.today

print "time (24-hour format pls. e.g. 1300): "
time = gets.strip

shell_date_string = "#{date.strftime("%Y%m%d")}#{time}"
at_command = "at -t #{shell_date_string}"

puts "Proofread and copy and paste these commands into your terminal:"
puts [
  "echo \"#{auto_gk} #{gh_token} #{COURTSIDE_REPO} #{courtside_rc_version}\" | #{at_command}",
  "echo \"#{auto_gk} #{gh_token} #{REPLAY_REPO} #{replay_rc_version}\" | #{at_command}",
].join("\n")
