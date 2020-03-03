class Gitter
  class Service
    include ServiceMixin

    class << self
      # Send a message to a room
      #
      # The :room: parameter can either be a id or a uri, and if neither are
      # joined, it will join that room prior to sending the message (TODO).
      #
      def send_message(room, message)
        room_id = get_room_id(room)

        api.send_message(room_id, message)
      end

      def unread_messages(room)
        room_id = get_room_id(room)

        api.unread_messages(user_id, room_id)
      end

      def joined_rooms
        @joined_rooms ||= begin
          response = api.user_rooms

          if response.status == 200
            rooms = JSON.parse(response.body)

            rooms.reject { |room| room["oneOnOne"] }
                 .map    { |room| [ room["uri"], room["id"] ] }
                 .to_h
          end
        end
      end

      def user
        @user ||= begin
          response = api.user

          if response.status == 200
            JSON.parse(response.body).first
          end
        end
      end

      def user_id
        self.user["id"]
      end

      def user_handle
        "@#{self.user["username"]}"
      end

      def get_room_id(room_key)
        return room_key               if joined_rooms.values.include?(room_key)
        return joined_rooms[room_key] if joined_rooms.has_key?(room_key)
      end

      private

      def api
        @api ||= API.new(credentials[:token])
      end
    end
  end

  class API
    class << self
      attr_reader :api_url

      # The prefix for the API endpoints
      #
      # In development using a local gitter instance, it should be `/api/v1`,
      # but in production it is just `/v1`
      attr_accessor :api_prefix

      def api_url=(api_url)
        if api_url.present?
          @api_url = api_url
        else
          raise "Please set a Gitter api_url in config/settings!"
        end
      end
    end

    attr_reader :auth_token

    def initialize auth_token
      @auth_token = auth_token
    end

    def user
      get "#{api_prefix}/user"
    end

    def user_rooms
      get "#{api_prefix}/rooms"
    end

    def send_message(room_id, message)
      payload = { "text" => message }.to_json
      post "#{api_prefix}/rooms/#{room_id}/chatMessages", payload
    end

    def unread_messages(user_id, room_id)
      get "#{api_prefix}/user/#{user_id}/rooms/#{room_id}/unreadItems"
    end

    def connection
      @connection ||= begin
        require 'faraday'

        Faraday.new(:url => self.class.api_url) do |faraday|
          # faraday.request(:url_encoded)
          faraday.adapter(Faraday.default_adapter)
        end
      end
    end

    # Shared request helpers for adding BZ auth to a request
    #
    # TODO:  put this in a shared mixin for faraday API helpers
    def get(path, &block)
      connection.get(&faraday_request_block(path, &block))
    end

    def post(path, payload, &block)
      connection.post(&put_post_block(path, payload, &block))
    end

    def put(path, payload, &block)
      connection.put(&put_post_block(path, payload, &block))
    end

    # Shared request block for adding the URL and block (required for both GET
    # and POST requests)
    def faraday_request_block(path)
      lambda do |req|
        req.url(path)
        req.headers["Accept"]        = "application/json"
        req.headers["Content-Type"]  = "application/json"
        req.headers["Authorization"] = "Bearer #{auth_token}"

        yield req if block_given?

        req
      end
    end

    # Double block nesting...
    #
    # Adds both auth from faraday_request_block, and sets body for the POST
    # payload, and passes the block twice (technically)
    def put_post_block(path, payload)
      faraday_request_block(path) do |req|
        req.body = payload

        yield req if block_given?
      end
    end

    def api_prefix
      self.class.api_prefix
    end
  end

  module AuthHandshake
    module_function

    # Add the auth needed by Gitter's bayeux protocol
    #
    # Basically, we just add a `"ext" => { "token" => "MY_TOKEN"}` to the
    # message on a "/meta/handshake" request to authenticate with gitter.
    #
    # See the following as reference:
    #
    #   - https://github.com/gitterHQ/gitter-faye-client/blob/391345d6/gitter-faye.js#L10-L17
    #   - https://gitlab.com/gitlab-org/gitter/webapp/blob/3cfaa1fb/server/web/bayeux/authenticator.js#L53-60
    #
    # NVL:  Took me fricken forever to figure this out...
    #
    def outgoing message, env, pipe
      if message["channel"] == "/meta/handshake"
        message["ext"] = {"token" => Service.credentials[:token]}
      end

      pipe.call message
    end

    # Implement if we want to validate a success clause or not
    #
    # See:
    #
    #   https://github.com/gitterHQ/gitter-faye-client/blob/391345d6/gitter-faye.js#L19-L26
    #
    # def incoming message, env, pipe
    # end
  end

  # A "cinch-like" gitter bot that will respond to messages we give it
  class Bot
    class << self
      attr_reader :websocket_url

      def websocket_url=(websocket_url)
        if websocket_url.present?
          @websocket_url = websocket_url
        else
          raise "Please set a Gitter websocket_url in config/settings!"
        end
      end
    end

    attr_reader :channel_endpoints

    def initialize(&block)
      @message_handlers = []
      dsl_eval(&block) if block_given?
    end

    # List of channels to watch
    #
    # Note:  the `api_prefix` isn't valid for this endpoint, and is always `/api/v1`
    def channels(channel_list)
      channel_list.each do |channel|
        room_id  = Service.get_room_id(channel)
        # user_id  = Service.user_id
        # endpoint = "/api/v1/user/#{user_id}/rooms/#{room_id}/unreadItems"
        endpoint = "/api/v1/rooms/#{room_id}/chatMessages"

        @channel_endpoints ||= []
        @channel_endpoints  << [endpoint, room_id]
      end
    end

    def channel_subscriptions
      channel_endpoints
    end

    def on(message, &block)
      raise ArgumentError, "Must provide a block to `.on'" unless block_given?
      @message_handlers << MessageHandler.new(message, &block)
    end

    # See https://faye.jcoglan.com/ruby/clients.html
    def start
      require 'eventmachine'

      EM.run do
        client = Faye::Client.new(self.class.websocket_url)
        client.add_extension AuthHandshake

        channel_subscriptions.each do |(endpoint, room_id)|
          puts "subscribing to #{endpoint}..."
          client.subscribe(endpoint) do |message|
            handle message, room_id
          end
        end
      end
    end

    private

    def handle message, room_id
      # Only respond to messages with text
      msg_text = message.fetch("model", {})["text"].dup
      return unless msg_text

      # Only respond to messages starting with the bot name
      return unless MessageContext.trim_bot_username msg_text

      # Only repond to messages with a defined handler
      handler, msg_cmd, msg_args = nil
      handler = @message_handlers.detect { |h| h.match msg_text }
      return unless handler

      handler.respond_to message, msg_text, room_id
    end

    def dsl_eval(&block)
      instance_eval(&block)
    end

    # A regexp/block pairing that is used to match a message, and the block it
    # should respond with.
    class MessageHandler
      attr_reader :matcher, :block

      def initialize msg_match, &block
        @block = block
        case msg_match
        when String, Symbol
          @matcher = /^#{msg_match.to_s}/
        else
          @matcher = msg_match
        end
      end

      def match message
        message =~ @matcher
      end

      # Create a message context to respond to the message from the user
      def respond_to message, msg_text, room_id
        matcher =~ msg_text

        msg_cmd  = $&            # last match string
        msg_args = $'.to_s.strip # string to right of match

        context  = MessageContext.new room_id, message, self, msg_cmd, msg_args
        context.call
      end
    end

    # Message context for the matched message
    #
    # The block of an `on "msg" do ...` is executed in an instance (context) of
    # MessageContext, which provides a DSL for some helper methods for
    # responding to the message.
    #
    class MessageContext
      attr_reader :handler, :room_id, :user_id, :raw_message, :msg_cmd, :msg_args

      def self.trim_bot_username msg_text
        msg_text.gsub! /^#{Gitter::Service.user_handle} */, ''
      end

      def initialize room_id, message, handler, msg_cmd, msg_args
        @handler     = handler
        @room_id     = room_id
        @raw_message = message
        @msg_cmd     = msg_cmd
        @msg_args    = msg_args.split(" ")

        if raw_message.fetch("model", {})["fromUser"]
          @user_id  = raw_message["model"]["fromUser"]["id"]
          @username = raw_message["model"]["fromUser"]["username"]
        end
      end

      # Raw msg text from the socket
      #
      # still has bot's username, so most likely you want to work with #user_message
      def msg_text
        @msg_text ||= raw_message.fetch("model", {})["text"].to_s
      end

      def reply reply_message
        Gitter::Service.send_message room_id, "#{username_handle} #{reply_message}"
      end

      # Send a generic message to the channel
      def send_message message
        Gitter::Service.send_message room_id, message
      end

      def username
        @username ||= lookup_username
      end

      def username_handle
        "@#{username}"
      end

      # Message that was sent to the bot from the user
      def user_message
        "#{msg_cmd} #{msg_args}"
      end

      def call
        instance_eval(&handler.block)
      end

      private

      def lookup_username
        # TODO
      end
    end

    class ChannelSubscription
    end
  end
end
