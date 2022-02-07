# frozen_string_literal: true

require "yaml"
require "adapter/imap"
require "mover/folder"

module Mover
  class Box
    attr_reader :config, :conn_from, :conn_to

    def initialize(debugger: false)
      @debugger = debugger
      @config = YAML.load_file(File.expand_path("../config.yml", __dir__))
      @conn_from = Adapter::Imap.new(config["from"])
      @conn_to = Adapter::Imap.new(config["to"])
    end

    def move
      config["folders_to_sync"].each do |from, to|
        conn_from.expunge # remove all messages that is mark to remove
        Mover::Folder.new(box: self, from: from, to: to).move
        conn_from.expunge # remove all messages that is mark to remove
      end

      conn_to.disconnect
      conn_from.disconnect
    end

    def debugger?
      @debugger
    end
  end
end
