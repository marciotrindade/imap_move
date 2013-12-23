#!/usr/bin/env ruby
require 'yaml'
require_relative 'imap_adapter'

# load config
AppConfig = YAML.load_file(File.expand_path('../config.yml',  __FILE__))

# Connect into servers
conn_from = ImapAdapter.new(AppConfig['from'])
conn_to   = ImapAdapter.new(AppConfig['to'])

AppConfig['boxes_to_sync'].each do |box_from, box_to|
  # select box_from
  conn_from.select_box(box_from)
  puts "conected from #{box_from}"

  # select or create box_to
  conn_to.select_or_create_box(box_to)
  puts "conected to #{box_to}"

  # find messages that exist in the destination
  messages_existing = conn_to.find_message_ids
  puts "messages_existing: #{messages_existing.size}"

  # messages to remove from original server
  @messages_to_delete = []

  puts "block to each message"
  # a block to execute fo each message
  conn_from.for_each_message do |message|
    uid        = message.attr['UID']
    message_id = message.attr['ENVELOPE'].message_id
    puts "processing message #{uid}"

    # if message exist just remove
    if messages_existing.include?(message_id)
      puts "message ##{uid} exixsts in destination"
      @messages_to_delete << uid
      next
    end

    # find message body from original server
    conn_from.copy_message(uid, conn_to, box_to)
    puts "message ##{uid} copied to destination"

    # removed message that is copied
    @messages_to_delete << uid
  end

  # deleting coped messages
  conn_from.delete_messages(@messages_to_delete)
  puts "deleted messages that has ben copied #{@messages_to_delete}"

  conn_from.disconnect
  conn_to.disconnect
end
