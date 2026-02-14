require "bundler/setup"
require "dotenv/load"
require "langfuse"
require_relative "../lib/config"
require_relative "../lib/bedrock_claude"

# Configure Langfuse
Config::Langfuse.configure!

# Initialize AWS Bedrock client
bedrock = BedrockClaude.new(region: Config::Bedrock::REGION)

# Initialize conversation history
messages = []

puts "=" * 60
puts "Interactive Chat with Langfuse Gem Tracing"
puts "Type /exit to quit, /new to start a new session."
puts "=" * 60
puts

# Main conversation loop wrapped in propagate_attributes
Langfuse.propagate_attributes(
  user_id: Config::Langfuse::USER_ID,
  session_id: Config::Langfuse.session_id,
  metadata: { environment: Config::Langfuse::ENVIRONMENT }
) do
  loop do
    print "You> "
    user_input = STDIN.gets
    break if user_input.nil?

    user_input = user_input.strip
    next if user_input.empty?

    break if user_input == "/exit"

    if user_input == "/new"
      Config::Langfuse.reset_session!
      messages = []
      puts "\n" + "=" * 60
      puts "New session started!"
      puts "=" * 60
      puts
      next
    end

    # Add user message to history
    messages << {
      "role"    => "user",
      "content" => [{ "type" => "text", "text" => user_input }]
    }

    begin
      # Create an observation for this turn
      Langfuse.observe("chat-turn", input: { message: user_input, history_length: messages.length }) do |obs|
        result = bedrock.invoke(
          model_id: Config::Bedrock::MODEL_ID,
          messages: messages,
          max_tokens: Config::Bedrock::MAX_TOKENS,
          trace_generation: true
        )

        # Add assistant response to message history
        messages << {
          "role"    => "assistant",
          "content" => result.raw["content"]
        }

        # Update observation with the result
        obs.update(output: { response: result.text, total_messages: messages.length })

        # Display response
        puts "Assistant> #{result.text}"
        puts

        result
      end

    rescue StandardError => e
      puts "Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      puts
    end
  end
end

# Force flush traces to Langfuse before script exits
Langfuse::OtelSetup.force_flush

puts "\n" + "=" * 60
puts "Goodbye!"
puts "=" * 60
