# frozen_string_literal: true

require "forwardable"

module Mover
  class Message
    extend Forwardable

    def_delegator :folder, :log
    def_delegator :folder, :conn_from
    def_delegator :folder, :conn_to

    ERROR_FILE = "log/error.log"

    attr_reader :folder, :uid, :to

    def initialize(folder:, uid:, to:)
      @folder = folder
      @uid = uid
      @to = to
    end

    def move
      conn_from.copy_message(uid, conn_to, to)
      conn_from.delete_messages(uid) # removed message that is copied
      log("Deleted message ##{uid}")
    rescue Net::IMAP::BadResponseError => error
      log_uid_to_ignore(uid)
      error_log.error("{uid: #{uid}, class: #{error.class}, message: #{error.message}}")
    rescue StandardError => error
      error_log.error("{uid: #{uid}, class: #{error.class}, message: #{error.message}}")
    end

    private def error_log
      @error_log ||= Logger.new(ERROR_FILE)
    end

    private def log_uid_to_ignore(uid)
      File.open(Mover::Folder::UID_FILE, "a+") do |file|
        file.puts uid
      end
    end
  end
end
