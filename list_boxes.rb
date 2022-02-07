# frozen_string_literal: true

require "yaml"
require "net/imap"

config = YAML.load_file(File.expand_path("config.yml", __dir__))

from = Net::IMAP.new(config["from"]["host"], config["from"]["port"], config["from"]["ssl"], nil,
                     false).tap do |c|
  c.login(config["from"]["username"], config["from"]["password"])
  c.select("INBOX")
end

to = Net::IMAP.new(config["to"]["host"], config["to"]["port"], config["to"]["ssl"], nil,
                   false).tap do |c|
  c.login(config["to"]["username"], config["to"]["password"])
  c.select("INBOX")
end

puts "Folders in origin mail box"
puts from.list("*", "%").map(&:name)

puts ""
puts ""
puts "Folders in destination mail box"
puts to.list("*", "%").map(&:name)
