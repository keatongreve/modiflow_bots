#!/usr/bin/env ruby

# Corrects the names (and values) of NSNotification names to match the format Notif[UniqueIdentifer],
# which adheres to the modi style guide.

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

source_extensions = [".h", ".m", ".c", ".swift", ".cpp"]

path = ARGV[0]

unless path
	puts "please specify a directory"
	exit 1
end

unless File.directory? path
	puts "#{path} is not a directory"
	exit 2
end

source_files = Dir.glob("#{path}/**/*").keep_if { |f| source_extensions.include? File.extname(f) }

notification_names = []

source_files.each do |path|
	File.read(path).each_line do |line|
		match = line.match /postNotificationName:(\w*)/
		if match
			captures = match.captures
			notification_names << captures[0] unless notification_names.include? captures[0] || captures[0] == ""
		end
	end
end

incorrect_notification_names = notification_names.select { |notif| !notif.match /^notif/i  and notif != '' }

corrections = []
incorrect_notification_names.each do |notif|
	if notif.start_with? "k"
		corrected_notif = "Notif" + notif[1..-1]
	elsif notif.end_with? "Notification"
		corrected_notif = "Notif" + notif[0..-13]
	else
		corrected_notif = "Notif" + notif
	end

	puts "#{notif} should be #{corrected_notif}"
	corrections << { original: notif, corrected: corrected_notif }
end

puts "There are #{incorrect_notification_names.length} incorrect notification names"
puts "#{corrections.length} have been corrected"

puts corrections

corrections.each do |correction|
	original = correction[:original]
	corrected = correction[:corrected]
	puts "Correcting #{original} to #{corrected}"
	source_files.each do |path|
		puts "\tIn file #{path}"
		File.write(
			path,
			File.open(path, &:read).gsub(original, corrected)
		)
	end
end

# Correct the values of the notification names to ensure consistency
# Example: NSString *const NotifMyNotification = @"NotifMyNotification";
source_files.each do |path|
	text = File.read(path)
	new_text = ""
	text.each_line do |line|
		match = line.match /\ (Notif\w*)\s*=\s*@"(\w*)";/
		if match && match.captures[0] != match.captures[1]
			puts line
			line = line.gsub("@\"#{match.captures[1]}\"", "@\"#{match.captures[0]}\"")
		end
		new_text = new_text + line
	end
	File.write(path, new_text)
end
