require 'weakref'

module DCell
  # A node in a DCell cluster
  class Node
    include Celluloid
    include Celluloid::FSM
    attr_reader :id, :addr

    finalizer :shutdown

    # FSM
    default_state :disconnected
    state :shutdown
    state :disconnected, :to => [:connected, :shutdown]
    state :connected do
      send_heartbeat
      transition :partitioned, :delay => @heartbeat_timeout
      Logger.info "Connected to #{id}"
    end
    state :partitioned do
      @heartbeat.cancel if @heartbeat
      Logger.warn "Communication with #{id} interrupted"
      move_node
    end

    # Singleton methods
    class << self
      include Enumerable
      extend Forwardable

      def_delegators "Celluloid::Actor[:node_manager]", :all, :each, :find, :[]
    end

    def initialize(id, addr)
      @id, @addr = id, addr
      @socket = nil
      @heartbeat = nil
      @requests = Hash.new
      @lock = Mutex.new

      @heartbeat_rate    = DCell.heartbeat_rate  # How often to send heartbeats in seconds
      @heartbeat_timeout = DCell.heartbeat_timeout # How soon until a lost heartbeat triggers a node partition

      # Total hax to accommodate the new Celluloid::FSM API
      attach self
    end

    def save_request(request)
      @lock.synchronize do
        id = request.id
        raise RuntimeError, "Request ID collision" if @requests.include? id
        @requests[id] = request
      end
    end

    def delete_request(request)
      @lock.synchronize do
        id = request.id
        raise RuntimeError, "Request not found" unless @requests.include? id
        @requests.delete id
      end
    end

    def retry_requests
      @lock.synchronize do
        @requests.each do |id, request|
          address = request.sender.address
          if request.kind_of? Message::Relay
            rsp = DeadActorResponse.new id, address
          else
            rsp = RetryResponse.new id, address
          end
          rsp.dispatch
        end
      end
    end

    def move_node
      addr = Directory[id]
      if addr
        update_client_address addr
        retry_requests
      else
        terminate
      end
    end

    def update_client_address(addr)
      @heartbeat.cancel if @heartbeat
      @addr = addr
      if @socket
        @socket.close
        @socket = nil
      end
      socket
    end

    def update_server_address(addr)
      @addr = addr
    end

    def shutdown
      transition :shutdown
      @socket.close if @socket
    end

    # Obtain the node's 0MQ socket
    def socket
      return @socket if @socket

      @socket = Celluloid::ZMQ::PushSocket.new
      begin
        @socket.connect @addr
        @socket.linger = @heartbeat_timeout * 1000
      rescue IOError
        @socket.close
        @socket = nil
        raise
      end
      @addr = @socket.get(::ZMQ::LAST_ENDPOINT).strip

      transition :connected
      @socket
    end

    def send_request(request)
      loop do
        send_message request
        save_request request
        response = receive do |msg|
          msg.respond_to?(:request_id) && msg.request_id == request.id
        end
        delete_request request

        next if response.is_a? RetryResponse
        raise ::Celluloid::DeadActorError.new if response.is_a? DeadActorResponse
        if response.is_a? ErrorResponse
          klass = Utils::full_const_get response.value[:class]
          msg = response.value[:msg]
          raise klass.new msg
        end
        return response.value
      end
    end

    # Find an call registered with a given name on this node
    def find(name)
      request = Message::Find.new(Thread.mailbox, name)
      mailbox, methods = send_request request
      return nil if mailbox.kind_of? NilClass
      DCell::ActorProxy.new self, mailbox, methods
    end
    alias_method :[], :find

    # List all registered actors on this node
    def actors
      request = Message::List.new(Thread.mailbox)
      list = send_request request
      list.map! do |entry|
        entry.to_sym
      end
    end
    alias_method :all, :actors

    # Relay message to remote actor
    def relay(message)
      request = Message::Relay.new(Thread.mailbox, message)

      # send_message request
      # save_request request
      send_request request
    end

    # Send a message to another DCell node
    def send_message(message)
      begin
        message = message.to_msgpack
      rescue => e
        abort e
      end
      socket << message
    end
    alias_method :<<, :send_message
    
    # Send a heartbeat message after the given interval
    def send_heartbeat
      return if DCell.id == id
      send_message DCell::Message::Heartbeat.new id
      @heartbeat = after(@heartbeat_rate) { send_heartbeat }
    end

    # Handle an incoming heartbeat for this node
    def handle_heartbeat(from)
      return if from == id
      transition :connected
      transition :partitioned, :delay => @heartbeat_timeout
    end

    # Friendlier inspection
    def inspect
      "#<DCell::Node[#{@id}] @addr=#{@addr.inspect}>"
    end
  end
end
