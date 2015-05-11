#!/usr/bin/env ruby

require 'byebug'

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

if File.directory? path
	source_files = Dir.glob("#{path}/**/*").keep_if { |f| source_extensions.include? File.extname(f) }
else
	source_files = [path] if source_extensions.include? File.extname(path)
end


@properties = []

source_files.each do |path|
	File.read(path).each_line do |line|
		match = line.match /^\s*(@property)\s*(\(.*\))?\s*(IBOutlet)?\s*(\w*)\s*(\*)?\s*(\w*).*(;)/
		if match
			@properties << match.captures
		end
	end
end

@properties.each { |p| puts p.each(&:strip).join(" ") }