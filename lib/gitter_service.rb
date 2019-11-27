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

  # A "cinch-like" gitter bot that will
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
        @channel_endpoints  << endpoint
      end
    end

    def channel_subscriptions
      channel_endpoints
    end

    def on(message, &block)
      raise ArgumentError, "Must provide a block to `.on'" unless block_given?
      dsl_eval(&block)
    end

    # See https://faye.jcoglan.com/ruby/clients.html
    def start
      require 'eventmachine'

      EM.run do
        client = Faye::Client.new(self.class.websocket_url)
        client.set_header "Authorization", "Bearer #{Service.credentials[:token]}"

        channel_subscriptions.each do |endpoint|
          puts "subscribing to #{endpoint}..."
          client.subscribe(endpoint) do |message|
            puts message.inspect
          end
        end
      end
    end

    private

    def dsl_eval(&block)
      instance_eval(&block)
    end

    class ChannelSubscription
    end
  end
end
