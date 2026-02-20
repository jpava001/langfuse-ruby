#!/usr/bin/env ruby
#
# Evaluate Grading with Langfuse Prompt Management
#
# This script demonstrates:
# - Fetching prompts from Langfuse API by name and label
# - Using test cases to simulate LLM grading
# - Pushing simulated responses to Langfuse with proper prompt linking
#

require "bundler/setup"
require "dotenv/load"
require "langfuse"
require "json"
require_relative "../lib/config"

# Configure Langfuse
Config::Langfuse.configure!

# Prompt configuration
prompt_name = "assignment-feedback"
prompt_label = "latest"

puts "=" * 60
puts "Evaluating Reading Comprehension with Langfuse Prompt API"
puts "=" * 60
puts "Prompt Name: #{prompt_name}"
puts "Prompt Label: #{prompt_label}"
puts "=" * 60
puts

# Load test cases from JSON
test_cases_path = File.join(__dir__, "../data/assignment_evaluation_test_cases.json")
test_cases = JSON.parse(File.read(test_cases_path, encoding: 'UTF-8'))

# Track statistics
exact_matches = 0
grade_counts = Hash.new(0)

begin
  # Fetch the prompt from Langfuse API
  puts "Fetching prompt from Langfuse..."
  prompt = Langfuse.client.get_prompt(prompt_name, label: prompt_label)

  unless prompt
    puts "⚠ Error: Could not fetch prompt '#{prompt_name}' with label '#{prompt_label}'"
    puts "Please ensure the prompt exists in your Langfuse dashboard"
    exit 1
  end

  puts "✓ Successfully fetched prompt"
  puts "  Version: #{prompt.version}"
  puts "  Name: #{prompt.name}"
  puts

  # Extract the prompt text/template
  prompt_template = prompt.prompt

  # Wrap all evaluations in a session context
  Langfuse.propagate_attributes(
    user_id: Config::Langfuse::USER_ID,
    session_id: Config::Langfuse.session_id,
    metadata: {
      environment: Config::Langfuse::ENVIRONMENT,
      prompt_name: prompt_name,
      prompt_label: prompt_label,
      prompt_version: prompt.version.to_s
    }
  ) do
    test_cases.each do |test_case|
      # Extract fields
      id = test_case["id"]
      passage = test_case["passage"]
      question = test_case["question"]
      rubric = test_case["rubric"]
      answer = test_case["answer"]
      student_grade = test_case["student_grade"]
      llm_scoring_output = test_case["llm_scoring_output"]
      expected_score = test_case["expected_score"]

      # Get LLM score from output
      llm_score = llm_scoring_output["total_score"]

      # Track statistics
      exact_matches += 1 if llm_score == expected_score
      grade_counts[student_grade] += 1

      # Compile the prompt with variables
      # If the prompt supports Mustache templating, use compile()
      # Otherwise, fall back to the raw prompt template
      begin
        compiled_prompt = prompt.compile(
          passage: passage,
          question: question,
          rubric: rubric,
          answer: answer
        )
      rescue NoMethodError
        # If compile method doesn't exist, use the raw template
        # and do simple string substitution
        compiled_prompt = prompt_template
          .gsub("{{passage}}", passage)
          .gsub("{{question}}", question)
          .gsub("{{rubric}}", rubric)
          .gsub("{{answer}}", answer)
      end

      # Prepare input for generation
      trace_generation_input = {
        "messages" => [
          {
            "role" => "user",
            "content" => compiled_prompt
          }
        ]
      }

      # Prepare metadata
      shared_metadata = {
        student_grade: student_grade,
        expected_score: expected_score,
        test_case_id: id,
        prompt_name: prompt_name,
        prompt_label: prompt_label,
        prompt_version: prompt.version.to_s
      }

      # Simulate token counts based on content length
      input_text = compiled_prompt
      output_text = llm_scoring_output.to_json
      input_tokens = (input_text.length / 4.0).round
      output_tokens = (output_text.length / 4.0).round
      total_tokens = input_tokens + output_tokens

      # Simulate latency
      base_latency = 1200
      complexity_factor = (input_tokens / 80.0) + (output_tokens / 40.0)
      simulated_latency_ms = (base_latency + (complexity_factor * 150) + rand(300..800)).round
      simulated_latency_seconds = simulated_latency_ms / 1000.0

      # Simulate cost (using typical Claude pricing: $3/1M input, $15/1M output tokens)
      input_cost = (input_tokens / 1_000_000.0) * 3.0
      output_cost = (output_tokens / 1_000_000.0) * 15.0
      total_cost = input_cost + output_cost

      # Create an observation for this grading task
      Langfuse.observe(
        "reading-comprehension-grading",
        input: trace_generation_input,
        metadata: shared_metadata
      ) do |obs|
        # Simulate the grading generation with prompt linking
        sleep(simulated_latency_seconds) if simulated_latency_seconds < 1 # Only sleep if < 1 second to keep tests fast

        obs.start_observation("grading-llm-call", { input: trace_generation_input }, as_type: :generation) do |gen|
          # Set the model
          gen.model = "simulated-grader"
          gen.metadata = shared_metadata

          # Link the prompt to this generation
          # This creates the connection in Langfuse between the prompt and the trace
          gen.update(prompt: {
            name: prompt.name,
            version: prompt.version
          })

          # Set output and usage
          gen.output = llm_scoring_output
          gen.usage = {
            prompt_tokens: input_tokens,
            completion_tokens: output_tokens,
            total_tokens: total_tokens
          }

          llm_scoring_output
        end

        # Update observation with output
        obs.update(output: llm_scoring_output)
      end

      # Print summary for this test case
      match_indicator = llm_score == expected_score ? " ✓" : ""
      puts "[#{id}] Grade: #{student_grade} | LLM: #{llm_score}/6 | Expected: #{expected_score}/6#{match_indicator}"
    end
  end

  # Print summary statistics
  puts
  puts "=" * 60
  puts "Summary Statistics"
  puts "=" * 60
  puts "Total test cases: #{test_cases.length}"
  puts "Exact matches: #{exact_matches}"
  puts "Accuracy: #{(exact_matches.to_f / test_cases.length * 100).round(1)}%"

  # Print grade level distribution
  grade_dist = grade_counts.sort.map { |grade, count| "#{grade}th (#{count})" }.join(", ")
  puts "Grade levels: #{grade_dist}"

  # Print prompt info
  puts
  puts "Prompt Information:"
  puts "  Name: #{prompt.name}"
  puts "  Version: #{prompt.version}"
  puts "  Label: #{prompt_label}"

rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.join("\n")
  raise
ensure
  # Force flush traces to Langfuse before script exits
  Langfuse::OtelSetup.force_flush
end

puts
puts "=" * 60
puts "Done! Check your Langfuse dashboard for:"
puts "  - Traces with prompt linking"
puts "  - Generation observations with prompt metadata"
puts "  - Session data with all test cases"
puts "=" * 60
