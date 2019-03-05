class BugzillaService
  include ServiceMixin

  CLOSING_KEYWORDS = %w(
    close
    closes
    closed
    fix
    fixes
    fixed
    resolve
    resolves
    resolved
  )

  class << self
    attr_reader :product

    def product=(product)
      if product.present?
        @product = product
      else
        raise "Please set a Bugzilla product in config/settings!"
      end
    end

    def credentials=(credentials)
      if credentials.username.present? || credentials.password.present?
        @credentials = credentials
      else
        raise "username and password must be set in config/settings"
      end
    end
  end

  # Helper class for specific bugs
  class Bug
    attr_reader   :service
    attr_accessor :id, :status

    def initialize(service, id, status)
      @service, @id, @status = service, id, status
    end

    def comments
      response = service.get("/rest/bug/#{id}/comment") do |req|
        req.params["include_fields"] = "text"
      end

      if response.status == 200
        JSON.parse(response.body)["bugs"][id.to_s]["comments"]
            .map { |comment| comment["text"] }
      else
        []
      end
    end

    # Adds a comment.  Returns true if status == 200
    def add_comment(text)
      payload  = {"comment" => text}.to_json
      response = service.post("/rest/bug/#{id}/comment", payload)

      response.status == 200
    end

    # Basicially API compatible with `active_bugzilla` way of updating the bug
    # status.
    def save
      payload  = { "ids" => [id], "status" => status }.to_json
      response = service.put("/rest/bug/#{id}", payload)

      response.status == 200
    end
  end

  def initialize
    connection # initialize the connection
  end

  def connection
    @connection ||= begin
      require 'faraday'

      Faraday.new(:url => credentials.to_h[:url]) do |faraday|
        faraday.request(:url_encoded)
        faraday.adapter(Faraday.default_adapter)
      end
    end
  end

  def find_bug(id)
    response = get("/rest/bug") do |req|
      req.params["id"]             = id
      req.params["product"]        = self.class.product
      req.params["include_fields"] = "id,status"
    end

    if response.status == 200
      attributes = JSON.parse(response.body)["bugs"].first
      Bug.new(self, attributes['id'], attributes['status'])
    end
  end

  def with_bug(id)
    yield find_bug(id)
  end

  # Shared request helpers for adding BZ auth to a request
  def get(path, &block)
    connection.get(&faraday_request_block(path, &block))
  end

  def post(path, payload, &block)
    connection.post(&put_post_block(path, payload, &block))
  end

  def put(path, payload, &block)
    connection.put(&put_post_block(path, payload, &block))
  end

  private

  # Shared request block for adding the URL and block (required for both GET
  # and POST requests)
  def faraday_request_block(path)
    lambda do |req|
      req.url(path)
      req.params["login"]    = credentials.username
      req.params["password"] = credentials.password

      yield req if block_given?
    end
  end

  # Double block nesting...
  #
  # Adds both auth from faraday_request_block, and sets body for the POST
  # payload, and passes the block twice (technically)
  def put_post_block(path, payload)
    faraday_request_block(path) do |req|
      req.headers["Content-Type"] = "application/json"
      req.body = payload

      yield if block_given?
    end
  end

  def self.ids_in_git_commit_message(message)
    search_in_message(message).collect { |bug| bug[:bug_id] }
  end

  def self.search_in_message(message)
    return [] unless Settings.bugzilla_credentials.url

    regex = match_regex

    message.each_line.collect do |line|
      match = regex.match(line.strip)
      match && Hash[match.names.zip(match.captures)].tap do |h|
        h.symbolize_keys!
        h[:bug_id]     &&= h[:bug_id].to_i
        h[:resolution] &&= h[:resolution].downcase
      end
    end.compact
  end

  private_class_method def self.match_regex
    url = Settings.bugzilla_credentials.url.to_s.chomp("/")
    /\A((?<resolution>#{CLOSING_KEYWORDS.join("|")}):?)?\s*#{url}\/\/?(?:show_bug\.cgi\?id=)?(?<bug_id>\d+)\Z/i
  end
end
