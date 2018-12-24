# frozen_string_literal: true

require "concurrent/array"
require "concurrent/timer_task"
require "concurrent/executor/thread_pool_executor"

require "websocket/driver"

require "pakyow/support/message_verifier"

require "pakyow/realtime/websocket"
require "pakyow/realtime/event_loop"

module Pakyow
  module Realtime
    class Server
      class << self
        # Returns a key.
        #
        def socket_server_id
          Support::MessageVerifier.key
        end

        # Returns a connection id (used throughout the current request lifecycle).
        #
        def socket_client_id
          Support::MessageVerifier.key
        end

        # Returns a digest created from the connection id and socket key.
        #
        def socket_digest(socket_server_id, socket_client_id)
          Support::MessageVerifier.digest(socket_client_id, key: socket_server_id)
        end
      end

      attr_reader :adapter

      HEARTBEAT_INTERVAL = 3

      def initialize(adapter = :memory, adapter_config, timeout_config)
        require "pakyow/realtime/server/adapters/#{adapter}"
        @adapter = Adapter.const_get(adapter.to_s.capitalize).new(self, adapter_config)
        @event_loop = EventLoop.new
        @sockets = Concurrent::Array.new
        @timeout_config = timeout_config

        connect
      rescue LoadError => e
        Pakyow.logger.error "Failed to load data subscriber store adapter named `#{adapter}'"
        Pakyow.logger.error e.message
      end

      def connect
        start_heartbeat; @adapter.connect
      end

      def disconnect
        stop_heartbeat; @adapter.disconnect
      end

      def socket_connect(id_or_socket, io)
        find_socket(id_or_socket) do |socket|
          @event_loop.add(io, socket)
          @sockets << socket
          @adapter.persist(socket.id)
          @adapter.current!(socket.id, socket.object_id)
        end
      end

      def socket_disconnect(id_or_socket, io)
        find_socket(id_or_socket) do |socket|
          @event_loop.rm(io)
          @sockets.delete(socket)

          # If this isn't the current instance for the socket id, it means that a
          # reconnect probably happened and the new socket connected before we
          # knew that the old one disconnected. Since there's a newer socket,
          # don't trigger leave events or expirations for the old one.
          #
          if @adapter.current?(socket.id, socket.object_id)
            socket.leave
            @adapter.expire(socket.id, @timeout_config.disconnect)
          end
        end
      end

      def socket_subscribe(id_or_socket, *channels)
        find_socket_id(id_or_socket) do |socket_id|
          @adapter.socket_subscribe(socket_id, *channels)
          @adapter.expire(socket_id, @timeout_config.initial)
        end
      end

      def socket_unsubscribe(*channels)
        @adapter.socket_unsubscribe(*channels)
      end

      def subscription_broadcast(channel, message)
        @adapter.subscription_broadcast(channel.to_s, channel: channel.name, message: message)
      end

      # Called by the adapter, which guarantees that this server has connections for these ids.
      #
      def transmit_message_to_connection_ids(message, socket_ids, raw: false)
        socket_ids.each do |socket_id|
          find_socket_by_id(socket_id)&.transmit(message, raw: raw)
        end
      end

      def find_socket_by_id(socket_id)
        @sockets.find { |socket| socket.id == socket_id }
      end

      def find_socket(id_or_socket)
        socket = if id_or_socket.is_a?(WebSocket)
          id_or_socket
        else
          find_socket_by_id(id_or_socket)
        end

        yield socket if socket
      end

      def find_socket_id(id_or_socket)
        socket_id = if id_or_socket.is_a?(WebSocket)
          id_or_socket.id
        else
          id_or_socket
        end

        yield socket_id if socket_id
      end

      protected

      def start_heartbeat
        @executor = Concurrent::ThreadPoolExecutor.new

        @heartbeat = Concurrent::TimerTask.new(execution_interval: HEARTBEAT_INTERVAL) do
          @executor << -> {
            @sockets.each(&:beat)
          }
        end

        @heartbeat.execute
      end

      def stop_heartbeat
        @heartbeat.shutdown
      end
    end
  end
end
