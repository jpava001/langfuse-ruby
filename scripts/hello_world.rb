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

# Create a trace
trace = Langfuse.trace(
  name: "Claude Hello World with Langfuse Gem",
  user_id: Config::Langfuse::USER_ID,
  session_id: Config::Langfuse.session_id,
  metadata: {
    environment: Config::Langfuse::ENVIRONMENT
  },
  input: { "prompt" => prompt_text }
)

begin
  # Call AWS Bedrock (generation tracing handled internally)
  result = bedrock.invoke(
    model_id: Config::Bedrock::MODEL_ID,
    prompt_text: prompt_text,
    max_tokens: 50,
    trace: trace
  )

  # Update trace with output
  Langfuse.trace(
    id: trace.id,
    output: { "response" => result.text }
  )

  # Print results to console
  puts "=" * 60
  puts "Claude's Response:"
  puts "=" * 60
  puts result.text

rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.join("\n")
  raise
ensure
  # Flush events to Langfuse
  puts "\nFlushing events to Langfuse..."
  Langfuse.flush
  puts "Done!"
end
