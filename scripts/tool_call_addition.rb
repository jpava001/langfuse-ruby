require "bundler/setup"
require "dotenv/load"
require "langfuse"
require "json"
require_relative "../lib/config"
require_relative "../lib/bedrock_claude"

# Configure Langfuse
Config::Langfuse.configure!

# Initialize AWS Bedrock client
bedrock = BedrockClaude.new(region: Config::Bedrock::REGION)

# Helper function to find tool_use in response
def find_tool_use(response_body)
  content = response_body["content"] || []
  content.find { |c| c["type"] == "tool_use" }
end

# Helper function to execute the sum tool
def sum_tool(a, b)
  { "result" => a.to_f + b.to_f }
end

# Define the tools available to Claude
tools = [
  {
    "name"        => "sum",
    "description" => "Add two numbers and return the result.",
    "input_schema" => {
      "type"       => "object",
      "properties" => {
        "a" => { "type" => "number" },
        "b" => { "type" => "number" }
      },
      "required" => ["a", "b"]
    }
  }
]

# The initial prompt
prompt = "What is 41 + 1? Use the sum tool."

# Initialize message history
messages = [
  {
    "role"    => "user",
    "content" => [{ "type" => "text", "text" => prompt }]
  }
]

tool_use = nil

begin
  # Wrap entire workflow in propagate_attributes and observe
  Langfuse.propagate_attributes(
    user_id: Config::Langfuse::USER_ID,
    session_id: Config::Langfuse.session_id,
    metadata: { environment: Config::Langfuse::ENVIRONMENT }
  ) do
    Langfuse.observe("tool-call-addition-demo", input: { prompt: prompt }) do |root|
      # First LLM call - request tool use
      puts "=" * 60
      puts "Step 1: Requesting tool use from Claude..."
      puts "=" * 60

      result1 = bedrock.invoke(
        model_id: Config::Bedrock::MODEL_ID,
        messages: messages,
        tools: tools,
        max_tokens: 200,
        trace_generation: true
      )

      tool_use = find_tool_use(result1.raw)

      unless tool_use
        puts "\nNo tool call detected. Full response:"
        puts JSON.pretty_generate(result1.raw)
        exit 1
      end

      tool_name = tool_use["name"]
      tool_id   = tool_use["id"]
      tool_args = tool_use["input"] || {}

      puts "\nTool call detected:"
      puts "  Tool: #{tool_name}"
      puts "  ID: #{tool_id}"
      puts "  Arguments: #{tool_args.inspect}"

      # Execute the tool
      puts "\n" + "=" * 60
      puts "Step 2: Executing tool..."
      puts "=" * 60

      tool_result = root.start_observation("tool-execute-#{tool_name}", input: tool_args, as_type: :tool) do |tool_span|
        tool_span.metadata = { tool_name: tool_name }
        
        result = if tool_name == "sum"
                   sum_tool(tool_args["a"], tool_args["b"])
                 else
                   { "error" => "Unknown tool: #{tool_name}" }
                 end
        
        tool_span.update(output: result)
        result
      end

      puts "Result: #{tool_result.inspect}"

      # Add assistant response and tool result to message history
      messages << {
        "role"    => "assistant",
        "content" => result1.raw["content"]
      }

      messages << {
        "role"    => "user",
        "content" => [
          {
            "type"        => "tool_result",
            "tool_use_id" => tool_id,
            "content"     => [{ "type" => "text", "text" => JSON.generate(tool_result) }]
          }
        ]
      }

      # Second LLM call - final answer
      puts "\n" + "=" * 60
      puts "Step 3: Getting final answer from Claude..."
      puts "=" * 60

      result2 = bedrock.invoke(
        model_id: Config::Bedrock::MODEL_ID,
        messages: messages,
        tools: tools,
        max_tokens: 200,
        trace_generation: true
      )

      # Update root observation with final output
      root.update(output: { answer: result2.text })

      # Display final result
      puts "\n" + "=" * 60
      puts "Final Assistant Answer:"
      puts "=" * 60
      puts result2.text
      puts "=" * 60
    end
  end

rescue StandardError => e
  puts "\nError: #{e.message}"
  puts e.backtrace.join("\n")
  raise
ensure
  # Force flush traces to Langfuse before script exits
  Langfuse::OtelSetup.force_flush
end

puts "\nDone!"
