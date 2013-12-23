require 'net/imap'

class ImapAdapter
  def initialize(options)
    @config = options
  end

  def select_box(box)
    connection.select('INBOX') rescue false
  end

  def select_or_create_box(box)
    begin
      connection.select(box)
    rescue
      begin
        connection.create(box)
        connection.select(box)
      rescue
        false
      end
    end
  end

  def find_uids
    connection.uid_search(['ALL'])
  end

  def find_message_ids
    message_ids = []
    uids = find_uids
    if uids.any?
      each_slice(uids, ['ENVELOPE']) do |message|
        message_ids << message.attr['ENVELOPE'].message_id
      end
    end
    message_ids
  end

  def for_each_message
    uids = find_uids
    if uids.any?
      each_slice(uids, ['ENVELOPE']) do |message|
        yield message
      end
    end
  end

  def delete_messages(uids)
    connection.uid_store(uids, "+FLAGS", [:Deleted]) if uids.any?
  end

  def copy_message(uid, server, folder)
    message = find_message(uid)
    server.append_message(message, folder)
  end

  def append_message(message, folder)
    connection.append(folder, message.attr['RFC822'], nil, message.attr['INTERNALDATE'])
  end

  def disconnect
    connection.expunge
    connection.close
    @connection = nil
  end

  private

  def find_message(uid)
    connection.uid_fetch(uid, ['RFC822', 'FLAGS', 'INTERNALDATE']).first
  end

  def connection
    @connection ||= do_connection
  end

  def do_connection
    con = Net::IMAP.new(@config['host'], @config['port'], @config['ssl'])
    con.login(@config['username'], @config['password'])
    con
  end

  def each_slice(uids, *args)
    uids.each_slice(500) do |slice|
      connection.uid_fetch(slice, *args).each {|message| yield message }
    end
  end
end
