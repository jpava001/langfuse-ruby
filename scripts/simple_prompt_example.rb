#!/usr/bin/env ruby
# 
# Simple Prompt Management Example
# Demonstrates LangFuse prompt management with proper prompt-to-trace linking
#
# IMPORTANT: Prompt linking uses OpenTelemetry attributes:
# - langfuse.observation.prompt.name: Links the prompt name
# - langfuse.observation.prompt.version: Links the prompt version
# These are automatically set when passing langfuse_prompt to bedrock.invoke()
#
# Reference: https://langfuse.com/integrations/native/opentelemetry
#

require "bundler/setup"
require "dotenv/load"
require "langfuse"
require_relative "../lib/config"
require_relative "../lib/bedrock_claude"

# Configure Langfuse
Config::Langfuse.configure!

# Initialize Bedrock client
bedrock = BedrockClaude.new(region: Config::Bedrock::REGION)

puts "Simple Prompt Management Example"
puts "=" * 50
puts

# Example 1: Fetch and use a simple prompt
# ============================================

begin
  puts "Example 1: Fetching a simple prompt"
  
  # Fetch the prompt from LangFuse using client
  prompt = Langfuse.client.get_prompt("greeting-assistant")
  
  # The prompt object has a 'prompt' property containing the prompt text
  # and supports compile() method for variable substitution
  prompt_text = prompt.is_a?(String) ? prompt : prompt.prompt
  
  puts "✓ Fetched prompt: #{prompt_text}"
  
  # Use propagate_attributes for trace context
  Langfuse.propagate_attributes(user_id: Config::Langfuse::USER_ID) do
    # Wrap in an observation
    # Use the prompt with the LLM (pass prompt object for linking)
    result = bedrock.invoke(
      model_id: Config::Bedrock::MODEL_ID,
      prompt_text: prompt_text,
      max_tokens: 200,
      langfuse_prompt: prompt
    )
    
    puts "Response: #{result.text}"
    puts
  end
  
rescue StandardError => e
  puts "⚠ Error: #{e.message}"
  puts "Make sure you've created the 'greeting-assistant' prompt in LangFuse UI"
  puts
end

# Example 2: Use a prompt with variables
# ============================================

begin
  puts "Example 2: Using a prompt with variables"
  
  # Fetch the prompt using client
  prompt = Langfuse.client.get_prompt("personalized-greeting")
  
  unless prompt
    puts "⚠ Prompt 'personalized-greeting' not found"
    raise "Prompt not found"
  end
  
  # Compile with variables
  compiled_prompt = prompt.compile(
    user_name: "Alice",
    language: "Spanish",
    context: "business meeting"
  )
  
  puts "✓ Compiled prompt with variables"
  puts "Compiled: #{compiled_prompt[0..100]}..." if compiled_prompt.length > 100
  
  # Use propagate_attributes for trace context
  Langfuse.propagate_attributes(
    user_id: "alice",
    metadata: { user_name: "Alice", language: "Spanish", context: "business meeting" }
  ) do
    # Wrap in an observation
    result = bedrock.invoke(
        model_id: Config::Bedrock::MODEL_ID,
        prompt_text: compiled_prompt,
        max_tokens: 200,
        langfuse_prompt: prompt
      )
      
      puts "Response: #{result.text}"
      puts
  end
  
rescue StandardError => e
  puts "⚠ Error: #{e.message}"
  puts "Make sure you've created the 'personalized-greeting' prompt in LangFuse UI"
  puts
end

# Example 3: Use specific version or label
# ============================================

begin
  puts "Example 3: Fetching specific version"
  
  # Fetch specific version using client
  prompt_v1 = Langfuse.client.get_prompt("greeting-assistant", version: 1)
  puts "✓ Fetched version: #{prompt_v1.version}"
  
  # Or fetch by label
  # prompt_prod = Langfuse.client.get_prompt("greeting-assistant", label: "production")
  # puts "✓ Fetched production version"
  
  puts
  
rescue StandardError => e
  puts "⚠ Error: #{e.message}"
  puts
end

# Force flush traces to Langfuse before script exits
Langfuse::OtelSetup.force_flush

puts "=" * 50
puts "Done! Check your LangFuse dashboard for traces."
