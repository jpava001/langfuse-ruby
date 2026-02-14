require "bundler/setup"
require "dotenv/load"
require "langfuse"
require_relative "../lib/config"
require_relative "../lib/bedrock_claude"

# Configure Langfuse
Config::Langfuse.configure!

# Initialize AWS Bedrock client
bedrock = BedrockClaude.new(region: Config::Bedrock::REGION)

# The prompt
prompt_text = "Hello World"

begin
  # Create a trace with propagate_attributes for context
  Langfuse.propagate_attributes(
    user_id: Config::Langfuse::USER_ID,
    session_id: Config::Langfuse.session_id,
    metadata: { environment: Config::Langfuse::ENVIRONMENT }
  ) do
      # Call AWS Bedrock (generation tracing handled internally)
      response = bedrock.invoke(
        model_id: Config::Bedrock::MODEL_ID,
        prompt_text: prompt_text,
        max_tokens: 50,
      )

      # Print results to console
      puts "=" * 60
      puts "Claude's Response:"
      puts "=" * 60
      puts response.text
  end
rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.join("\n")
  raise
ensure
  # Force flush traces to Langfuse before script exits
  Langfuse::OtelSetup.force_flush
end

puts "\nDone!"