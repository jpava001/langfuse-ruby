require "securerandom"

module Config
  module Langfuse
    OTEL_ENDPOINT = ENV.fetch("OTEL_ENDPOINT")
    PUBLIC_KEY    = ENV.fetch("LANGFUSE_PUBLIC_KEY")
    SECRET_KEY    = ENV.fetch("LANGFUSE_SECRET_KEY")
    ENVIRONMENT   = ENV.fetch("LANGFUSE_ENVIRONMENT", "local")
    USER_ID       = ENV.fetch("LANGFUSE_USER_ID", "example-user-123")

    def self.session_id
      @session_id ||= ENV.fetch("LANGFUSE_SESSION_ID") { SecureRandom.uuid }
    end

    def self.reset_session!
      @session_id = SecureRandom.uuid
    end

    def self.configure!
      # Extract host from OTEL_ENDPOINT
      # Example: http://localhost:3000/api/public/otel/v1/traces -> http://localhost:3000
      langfuse_host = OTEL_ENDPOINT.sub(%r{/api/public/otel.*$}, "")

      # Configure Langfuse
      ::Langfuse.configure do |config|
        config.public_key = PUBLIC_KEY
        config.secret_key = SECRET_KEY
        config.host = langfuse_host
      end
    end
  end

  module Bedrock
    REGION     = ENV.fetch("AWS_REGION", "us-east-1")
    MODEL_ID   = ENV.fetch("BEDROCK_MODEL_ID", "anthropic.claude-sonnet-4.5")
    MAX_TOKENS = ENV.fetch("CHAT_MAX_TOKENS", "300").to_i
  end

  module Pricing
    INPUT_USD_PER_1K  = ENV.fetch("USD_PER_1K_INPUT_TOKENS", "0.003").to_f
    OUTPUT_USD_PER_1K = ENV.fetch("USD_PER_1K_OUTPUT_TOKENS", "0.015").to_f
  end
end
