module DCell
  # Servers handle incoming 0MQ traffic
  class PullServer
    # Bind to the given 0MQ address (in URL form ala tcp://host:port)
    def initialize(cell, logger=Logger)
      @logger = logger
      @socket = Celluloid::ZMQ::PullSocket.new

      begin
        @socket.bind(cell.addr)
        real_addr = @socket.get(::ZMQ::LAST_ENDPOINT).strip
        cell.addr = real_addr
        @socket.linger = 1000
      rescue IOError
        @socket.close
        raise
      end
    end

    def close
      @socket.close if @socket
    end

    # Handle incoming messages
    def handle_message(message)
      begin
        message = decode_message message
      rescue InvalidMessageError => ex
        @logger.crash("couldn't decode message", ex)
        return
      end

      begin
        message.dispatch
      rescue => ex
        @logger.crash("message dispatch failed", ex)
      end
    end

    class InvalidMessageError < StandardError; end # undecodable message

    def symbolize!(h)
      return unless h.kind_of? Hash
      h.keys.each do |k|
        ks = k.to_sym
        val = h.delete k
        h[ks] = val
        if val.kind_of? Hash
          symbolize! val
        elsif val.kind_of? Array
          val.each do |entry|
            symbolize! entry
          end
        end
      end
    end

    def full_const_get(name)
      list = name.split("::")
      obj = Object
      list.each do |x|
        obj = obj.const_get x
      end
      obj
    end

    # Decode incoming messages
    def decode_message(message)
      begin
        msg = MessagePack.unpack(message)
        symbolize! msg
      rescue => ex
        raise InvalidMessageError, "couldn't unpack message: #{ex}"
      end
      begin
        klass = full_const_get msg[:type]
        o = klass.new *msg[:args]
        if o.respond_to? :id and msg[:id]
          o.id = msg[:id]
        end
        o
      rescue => ex
        raise InvalidMessageError, "invalid message: #{ex}"
      end
    end
  end

  class Server < PullServer
    include Celluloid::ZMQ

    finalizer :close

    # Bind to the given 0MQ address (in URL form ala tcp://host:port)
    def initialize(cell)
      super(cell)
      # The gossip protocol is dependent on the node manager
      link Celluloid::Actor[:node_manager]
      async.run
    end

    # Wait for incoming 0MQ messages
    def run
      while true
        async.handle_message @socket.read
      end
    end
  end
end
