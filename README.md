# Langfuse Ruby Integration with AWS Bedrock Claude

A Ruby-based project demonstrating how to integrate [Langfuse](https://langfuse.com/) observability with AWS Bedrock's Claude models. This project provides examples of LLM tracing, monitoring, and evaluation using the [langfuse-rb gem](https://github.com/simplepractice/langfuse-rb).

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd langfuse
```

2. Install dependencies:
```bash
bundle install
```

3. Create a `.env` file based on the required environment variables:
```bash
cp .env.example .env
```

4. Configure your environment variables in `.env`:
```
# Langfuse Configuration
OTEL_ENDPOINT=http://localhost:3000/api/public/otel/v1/traces
LANGFUSE_PUBLIC_KEY=your_public_key
LANGFUSE_SECRET_KEY=your_secret_key
LANGFUSE_ENVIRONMENT=local
LANGFUSE_USER_ID=example-user-123
LANGFUSE_SESSION_ID=your_session_id

# AWS Bedrock Configuration
AWS_REGION=us-east-1
BEDROCK_MODEL_ID=us.anthropic.claude-sonnet-4.5

# Model Configuration
CHAT_MAX_TOKENS=300

# Pricing (optional, for cost tracking)
USD_PER_1K_INPUT_TOKENS=0.003
USD_PER_1K_OUTPUT_TOKENS=0.015
```

## Project Structure

```
.
├── lib/
│   ├── bedrock_claude.rb    # AWS Bedrock client wrapper
│   └── config.rb             # Configuration management
├── scripts/
│   ├── hello_world.rb           # Simple single-turn example
│   ├── chat_conversation.rb     # Interactive chat with tracing
│   ├── tool_call_addition.rb    # Tool calling demonstration
│   ├── evaluate_grading.rb      # Evaluation framework example
│   └── simple_prompt_example.rb # Prompt management example
├── data/
│   └── reading_comprehension_test_cases.json  # Test data
├── Gemfile                   # Ruby dependencies
└── README.md                 # This file
```

## Usage

### 1. Hello World Example

A simple example demonstrating basic Langfuse tracing with a single LLM call:

```bash
bundle exec ruby scripts/hello_world.rb
```

This script:
- Creates a Langfuse trace
- Sends a "Hello World" prompt to Claude
- Tracks token usage and response
- Flushes data to Langfuse

### 2. Interactive Chat

An interactive chat application with full conversation tracing:

```bash
bundle exec ruby scripts/chat_conversation.rb
```

Features:
- Multi-turn conversations with memory
- Session management with `/new` command
- Exit with `/exit` command
- Real-time tracing of each turn
- Automatic flush after each interaction

### 3. Tool Calling Example

Demonstrates Claude's tool calling capabilities with observability:

```bash
bundle exec ruby scripts/tool_call_addition.rb
```

This example:
- Defines a `sum` tool for Claude
- Requests Claude to use the tool
- Executes the tool locally
- Returns the result to Claude for final response
- Tracks each step with Langfuse spans

### 4. Evaluation Framework

An example of evaluating LLM performance on reading comprehension tasks:

```bash
bundle exec ruby scripts/evaluate_grading.rb
```

This script:
- Loads test cases from JSON data
- Simulates LLM grading of student answers
- Tracks evaluation metrics in Langfuse
- Calculates accuracy and statistics
- Simulates realistic token counts, latency, and costs

### 5. Prompt Management Example

Explore LangFuse's prompt management capabilities:

```bash
bundle exec ruby scripts/simple_prompt_example.rb
```

This script demonstrates:
- Fetching prompts from LangFuse by name
- Using prompts with variable substitution
- Fetching specific prompt versions
- Linking prompts to traces in LLM calls

**Note:** You'll need to create prompts in the LangFuse UI first. Create a prompt named `greeting-assistant` with simple greeting text to test the basic example.

## Key Components

### BedrockClaude Client

The `BedrockClaude` class (`lib/bedrock_claude.rb`) provides a clean interface to AWS Bedrock:

- Supports both single prompts and multi-turn conversations
- Automatic Langfuse generation tracking
- Token usage and cost calculation
- Tool calling support
- Structured result objects

### Configuration Module

The `Config` module (`lib/config.rb`) manages:

- Langfuse connection settings
- AWS Bedrock configuration
- Session ID generation and reset
- Pricing information for cost tracking

## Langfuse Features Demonstrated

- **Traces**: Top-level tracking of complete workflows
- **Generations**: Individual LLM calls with input/output
- **Spans**: Custom spans for tool execution
- **Metadata**: Environment, user, session information
- **Usage Tracking**: Token counts and costs
- **Session Management**: Multi-turn conversation tracking
- **Evaluation**: Test case evaluation and metrics
- **Prompt Management**: Fetching, versioning, and using managed prompts

## Development

### Langfuse Connection

Verify your Langfuse endpoint is accessible and credentials are correct. For local development with Langfuse self-hosted:
```
OTEL_ENDPOINT=http://localhost:3000/api/public/otel/v1/traces
```

### Token Limits

If you encounter token limit errors, adjust `CHAT_MAX_TOKENS` in your `.env` file.

## Key Features

This project uses the [langfuse-rb gem](https://github.com/simplepractice/langfuse-rb) which provides:

- **Built on OpenTelemetry**: Automatic context propagation and industry-standard tracing
- **Block-based API**: Clean, Ruby-idiomatic `observe` blocks with automatic resource cleanup
- **Context Management**: `propagate_attributes` for automatic trace-level attributes
- **Prompt Management**: Centralized prompt versioning with Mustache templating
- **Automatic Caching**: Redis or in-memory caching with stampede protection
- **Generation Tracking**: Specialized observation type for LLM calls with token usage

## Resources

- [Langfuse Documentation](https://langfuse.com/docs)
- [langfuse-rb GitHub](https://github.com/simplepractice/langfuse-rb)
- [langfuse-rb Documentation](https://github.com/simplepractice/langfuse-rb/tree/main/docs)
- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Claude API Documentation](https://docs.anthropic.com/)
