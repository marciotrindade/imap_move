# frozen_string_literal: true

require "logger"
require "mover/message"
require "forwardable"

module Mover
  class Folder
    extend Forwardable

    def_delegator :box, :conn_from
    def_delegator :box, :conn_to
    def_delegator :box, :debugger?

    UID_FILE = "log/uids.log"

    attr_reader :box, :from, :to, :size

    def initialize(box:, from:, to:)
      @box = box
      @from = from
      @to = to
    end

    def move
      select_folders

      # count messages to move
      @size = conn_from.find_message_ids.size

      if size.zero?
        log("There isn't new message to move!")
        return
      end
      log("There's #{size} messages to move")

      # a block to execute for each message
      index = 0
      conn_from.for_each_message do |message|
        index += 1

        uid = message.attr["UID"]
        log("processing message uid: ##{uid} (#{index}/#{size})")

        next unless valid?(message)

        Mover::Message.new(folder: self, uid: uid, to: to).move
        log("Message ##{uid} success moved")
      end
    end

    private def select_folders
      log("Selecting \"origin\" box: #{from}")
      conn_from.select_box(from)

      log("Selecting \"destination\" box: #{to}")
      conn_to.select_or_create_box(to)
    end

    private def valid?(message)
      uid = message.attr["UID"]

      if messages_to_ignore.include?(uid.to_s)
        log("Message ##{uid} should be ignored")
        return false
      end

      if exist_messages.include?(message.attr["ENVELOPE"].message_id)
        log("Message ##{uid} exixsts in destination")
        conn_from.delete_messages(uid)
        false
      end

      true
    end

    private def exist_messages
      @exist_messages ||= conn_to.find_message_ids
    end

    private def messages_to_ignore
      @messages_to_ignore = File.readlines(UID_FILE, chomp: true)
    end

    def log(message)
      info_log.info(message) if debugger?
    end

    private def info_log
      @info_log ||= Logger.new($stdout)
    end
  end
end
