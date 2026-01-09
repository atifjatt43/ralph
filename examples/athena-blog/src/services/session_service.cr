require "openssl/hmac"
require "json"
require "base64"

module Blog
  # Simple cookie-based session management service
  # Sessions are encrypted and stored entirely in the cookie
  @[ADI::Register]
  class SessionService
    # Session cookie configuration
    COOKIE_NAME    = "blog_session"
    COOKIE_MAX_AGE = 7.days.total_seconds.to_i
    SECRET_KEY     = ENV.fetch("SESSION_SECRET", "super-secret-key-change-in-production")

    struct SessionData
      include JSON::Serializable

      property user_id : String?
      property flash_success : String?
      property flash_error : String?
      property flash_info : String?
      property return_to : String?

      def initialize(
        @user_id = nil,
        @flash_success = nil,
        @flash_error = nil,
        @flash_info = nil,
        @return_to = nil,
      )
      end
    end

    # Get session data from request cookies
    def get_session(request : ATH::Request) : SessionData
      cookie = request.cookies[COOKIE_NAME]?
      return SessionData.new unless cookie

      decode_session(cookie.value)
    rescue
      SessionData.new
    end

    # Set session data in response cookies
    def set_session(response : ATH::Response, data : SessionData) : Nil
      encoded = encode_session(data)
      cookie = HTTP::Cookie.new(
        name: COOKIE_NAME,
        value: encoded,
        path: "/",
        max_age: Time::Span.new(seconds: COOKIE_MAX_AGE),
        http_only: true,
        secure: false # Set to true in production with HTTPS
      )
      response.headers.cookies << cookie
    end

    # Update session on response, clearing flash messages after reading
    def update_session(response : ATH::Response, data : SessionData) : Nil
      # Clear flash messages after they've been read
      cleared_data = SessionData.new(
        user_id: data.user_id,
        flash_success: nil,
        flash_error: nil,
        flash_info: nil,
        return_to: data.return_to
      )
      set_session(response, cleared_data)
    end

    # Destroy session (logout)
    def destroy_session(response : ATH::Response) : Nil
      cookie = HTTP::Cookie.new(
        name: COOKIE_NAME,
        value: "",
        path: "/",
        max_age: Time::Span.new(seconds: 0),
        http_only: true
      )
      response.headers.cookies << cookie
    end

    # Get current user from session
    def current_user(request : ATH::Request) : User?
      session = get_session(request)
      return nil unless user_id = session.user_id
      return nil if user_id.empty?
      User.find_by("id", user_id)
    end

    private def encode_session(data : SessionData) : String
      json = data.to_json
      signature = sign(json)
      Base64.urlsafe_encode("#{json}--#{signature}")
    end

    private def decode_session(encoded : String) : SessionData
      decoded = Base64.decode_string(encoded)
      parts = decoded.split("--", 2)
      raise "Invalid session format" unless parts.size == 2

      json, signature = parts
      raise "Invalid session signature" unless verify(json, signature)

      SessionData.from_json(json)
    end

    private def sign(data : String) : String
      OpenSSL::HMAC.hexdigest(:sha256, SECRET_KEY, data)
    end

    private def verify(data : String, signature : String) : Bool
      expected = sign(data)
      # Constant-time comparison to prevent timing attacks
      return false unless expected.size == signature.size
      result = 0
      expected.each_char_with_index do |char, i|
        result |= char.ord ^ signature[i].ord
      end
      result == 0
    end
  end
end
