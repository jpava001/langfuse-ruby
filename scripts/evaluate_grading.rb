require "bundler/setup"
require "dotenv/load"
require "langfuse"
require "json"
require_relative "../lib/config"

# Configure Langfuse
Config::Langfuse.configure!

# Load test cases from JSON
test_cases_path = File.join(__dir__, "../data/reading_comprehension_test_cases.json")
test_cases = JSON.parse(File.read(test_cases_path, encoding: 'UTF-8'))

puts "=" * 60
puts "Evaluating Reading Comprehension Grading Test Cases"
puts "=" * 60
puts

# Track statistics
exact_matches = 0
grade_counts = Hash.new(0)

begin
  # Wrap all evaluations in a session context
  Langfuse.propagate_attributes(
    user_id: Config::Langfuse::USER_ID,
    session_id: Config::Langfuse.session_id,
    metadata: { environment: Config::Langfuse::ENVIRONMENT }
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
      
      # Build the input prompt (simulated LLM grading prompt)
      input_prompt = <<~PROMPT
        You are an expert educational assessor grading a reading comprehension answer.
        
        PASSAGE:
        #{passage}
        
        QUESTION:
        #{question}
        
        RUBRIC:
        #{rubric}
        
        STUDENT'S ANSWER:
        #{answer}
        
        INSTRUCTIONS:
        Evaluate the student's answer against each criterion in the rubric. The rubric specifies what earns 0, 1, or 2 points for each criterion.
        
        For each criterion:
        1. Determine which level (0, 1, or 2 points) best matches the student's answer
        2. Provide a brief explanation for your decision
        
        After evaluating all criteria, sum the points to calculate the total score.
        
        Provide your evaluation in the following JSON format:
        {
          "criterion_1_score": <0, 1, or 2>,
          "criterion_1_reasoning": "<brief explanation>",
          "criterion_2_score": <0, 1, or 2>,
          "criterion_2_reasoning": "<brief explanation>",
          "criterion_3_score": <0, 1, or 2>,
          "criterion_3_reasoning": "<brief explanation>",
          "total_score": <sum of all criterion scores>,
          "overall_feedback": "<optional 1-2 sentence summary>"
        }
      PROMPT
      
      # Prepare input for generation
      trace_generation_input = {
        "messages" => [
          {
            "role" => "user",
            "content" => input_prompt
          }
        ]
      }
      
      # Prepare metadata
      shared_metadata = {
        student_grade: student_grade,
        expected_score: expected_score
      }
      
      # Simulate token counts based on content length
      input_text = input_prompt
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
        # Simulate the grading generation
        # Note: The new gem doesn't support manual timestamps in the same way
        # We'll create the generation observation and simulate latency with sleep
        sleep(simulated_latency_seconds) if simulated_latency_seconds < 1 # Only sleep if < 1 second to keep tests fast
        
        obs.start_observation("grading-llm-call", input: trace_generation_input, as_type: :generation) do |gen|
          gen.model = "simulated-grader"
          gen.metadata = shared_metadata
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
  
  # Print grade level distribution
  grade_dist = grade_counts.sort.map { |grade, count| "#{grade}th (#{count})" }.join(", ")
  puts "Grade levels: #{grade_dist}"
  
rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.join("\n")
  raise
ensure
  # Force flush traces to Langfuse before script exits
  Langfuse::OtelSetup.force_flush
end

puts "\nDone!"
