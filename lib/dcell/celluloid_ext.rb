# Celluloid mailboxes are the universal message exchange points. You won't
# be able to marshal them though, unfortunately, because they contain
# mutexes.
#
# DCell provides a message routing layer between nodes that can direct
# messages back to local mailboxes. To accomplish this, DCell adds custom
# marshalling to mailboxes so that if they're unserialized on a remote
# node you instead get a proxy object that routes messages through the
# DCell overlay network back to the node where the actor actually exists

module Celluloid
  class Mailbox
    def to_msgpack(pk=nil)
      DCell::MailboxManager.register self
      {
        address: @address,
        id:      DCell.id,
      }.to_msgpack(pk)
    end
  end

  module InstanceMethods
    def ______dcell_dispatch(info)
      value = nil
      if info[:block]
        send(info[:meth], *info[:args]) { |v| value = v }
      else
        value = send(info[:meth], *info[:args])
      end
      value
    end

    def ____dcell_dispatch(message)
      info = message.message
      value = ______dcell_dispatch info
      return if info[:async]
      message.success value
    rescue => e
      message.exception e
    end
  end

  module ClassMethods
    alias_method :____supervise_as, :supervise_as
    def supervise_as(name, *args, &block)
      DCell.add_local_actor name
      Supervisor.supervise_as(name, self, *args, &block)
    end
  end

  class AsyncProxy
    alias_method :____method_missing, :method_missing
    def method_missing(meth, *args, &block)
      meth = "____async_#{meth}".to_sym if @klass.start_with? "DCellActorProxy"
      ____method_missing meth, *args, &block
    end
  end

  class CellProxy
    alias_method :____async, :async
    def async(meth = nil, *args, &block)
      fail DeadActorError unless alive?
      ____async meth, *args, &block
    end

    alias_method :____future, :future
    def future(meth = nil, *args, &block)
      fail DeadActorError unless alive?
      ____future meth, *args, &block
    end
  end
end
