# frozen_string_literal: true

require "net/imap"

module Adapter
  class Imap
    private attr_reader :config

    def initialize(options)
      @config = options
    end

    def select_box(box)
      connection.select(box)
    end

    def select_or_create_box(box)
      select_box(box)
    rescue StandardError
      connection.create(box)
      select_box(box)
    end

    def find_uids
      connection.uid_search(["ALL"])
    end

    def find_message_ids
      message_ids = []
      uids = find_uids
      if uids.any?
        each_slice(uids, ["ENVELOPE"]) do |message|
          message_ids << message.attr["ENVELOPE"].message_id
        end
      end
      message_ids
    end

    def for_each_message(&block)
      uids = find_uids
      each_slice(uids, ["ENVELOPE"], &block) if uids.any?
    end

    def delete_messages(uid)
      connection.uid_store(uid, "+FLAGS", [:Deleted]) if uid
    end

    def copy_message(uid, server, folder)
      message = find_message(uid)
      server.append_message(message, folder)
    end

    def append_message(message, folder)
      connection.append(folder, message.attr["RFC822"], nil, message.attr["INTERNALDATE"])
    end

    def expunge
      connection.expunge
    end

    def disconnect
      connection.close
      @connection = nil
    end

    private def find_message(uid)
      connection.uid_fetch(uid, %w[RFC822 FLAGS INTERNALDATE]).first
    end

    private def connection
      @connection ||= Net::IMAP.new(config["host"], config["port"], config["ssl"], nil,
                                    false).tap do |c|
        c.login(config["username"], config["password"])
        c.select("INBOX")
      end
    end

    private def each_slice(uids, *args, &block)
      uids.each_slice(500) do |slice|
        connection.uid_fetch(slice, *args).each(&block)
      end
    end
  end
end
