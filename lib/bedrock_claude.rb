require "json"
require "aws-sdk-bedrockruntime"

class BedrockClaude
  Result = Struct.new(
    :text,
    :stop_reason,
    :input_tokens,
    :output_tokens,
    :raw,
    keyword_init: true
  )

  def initialize(region:)
    @client = Aws::BedrockRuntime::Client.new(region: region)
  end

  def invoke(model_id:, prompt_text: nil, messages: nil, tools: nil, max_tokens: 50, trace: nil)
    # Build messages array based on input format
    messages_payload = if messages
                         messages.dup
                       elsif prompt_text
                         [
                           {
                             "role" => "user",
                             "content" => [{ "type" => "text", "text" => prompt_text }]
                           }
                         ]
                       else
                         raise ArgumentError, "Either prompt_text or messages must be provided"
                       end

    # Create Langfuse generation if trace is provided
    generation = nil
    if trace
      generation = Langfuse.generation(
        trace_id: trace.id,
        name: "bedrock-generation",
        model: model_id,
        input: messages_payload
      )
    end

    # Build request body
    request_body = {
      anthropic_version: "bedrock-2023-05-31",
      max_tokens: max_tokens,
      messages: messages_payload
    }
    request_body[:tools] = tools if tools

    # Call AWS Bedrock
    resp = @client.invoke_model(
      model_id: model_id,
      content_type: "application/json",
      accept: "application/json",
      body: request_body.to_json
    )

    body = JSON.parse(resp.body.read.force_encoding('UTF-8'))

    usage = body["usage"] || {}
    input_tokens = usage["input_tokens"].to_i
    output_tokens = usage["output_tokens"].to_i
    total_tokens = input_tokens + output_tokens

    # Extract text from response
    text = body.dig("content", 0, "text").to_s

    # Update Langfuse generation with output and usage
    if trace && generation
      Langfuse.generation(
        id: generation.id,
        trace_id: trace.id,
        output: { "content" => body["content"] },
        usage: {
          input: input_tokens,
          output: output_tokens,
          total: total_tokens
        }
      )
    end

    Result.new(
      text: text,
      stop_reason: body["stop_reason"].to_s,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      raw: body
    )
  end
end
