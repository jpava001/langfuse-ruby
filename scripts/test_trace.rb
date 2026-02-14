#!/usr/bin/env ruby
# Simple test script to verify Langfuse tracing is working

require "bundler/setup"
require "dotenv/load"
require "langfuse"
require_relative "../lib/config"

puts "Testing Langfuse Tracing Setup"
puts "=" * 60

# Configure Langfuse
Config::Langfuse.configure!

puts "✓ Langfuse configured"
puts "  Base URL: #{Langfuse.configuration.base_url}"
puts "  Public Key: #{Langfuse.configuration.public_key[0..15]}..."
puts

# Create a simple test trace
puts "Creating test trace..."
Langfuse.propagate_attributes(
  user_id: "test-user",
  session_id: "test-session",
  metadata: { test: true, timestamp: Time.now.to_i }
) do
  Langfuse.observe("test-trace", input: { message: "Testing Langfuse setup" }) do |obs|
    # Simulate some work
    sleep 0.5
    
    # Update with output
    obs.update(
      output: { 
        status: "success",
        message: "Trace created successfully!"
      },
      metadata: {
        duration_ms: 500
      }
    )
    
    puts "✓ Test trace created"
  end
end

# Force flush to send immediately
puts "Flushing traces to Langfuse..."
Langfuse::OtelSetup.force_flush
puts "✓ Traces flushed"

puts
puts "=" * 60
puts "Test Complete!"
puts
puts "Next steps:"
puts "1. Wait 5-10 seconds for traces to process"
puts "2. Open your Langfuse dashboard"
puts "3. Navigate to 'Traces' tab"
puts "4. Look for trace named 'test-trace'"
puts "5. Verify it has:"
puts "   - User ID: test-user"
puts "   - Session ID: test-session"
puts "   - Input/Output data"
puts
puts "If you see the trace, your setup is working! 🎉"
puts "=" * 60
