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

  def invoke(model_id:, prompt_text: nil, messages: nil, tools: nil, max_tokens: 50, langfuse_prompt: nil)
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

    # Build request body
    request_body = {
      anthropic_version: "bedrock-2023-05-31",
      max_tokens: max_tokens,
      messages: messages_payload
    }
    request_body[:tools] = tools if tools

    # Wrap in Langfuse observation if tracing is enabled
    Langfuse.observe("bedrock-generation", input: messages_payload, as_type: :generation) do |gen|
      # Set model information
      gen.model = model_id
      
      # Add prompt linking if prompt is provided
      if langfuse_prompt
        gen.update(prompt: {
          name: langfuse_prompt.name,
          version: langfuse_prompt.version
        })
      end

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

      # Update generation with output and usage
      gen.output = { "content" => body["content"] }
      gen.usage = {
        prompt_tokens: input_tokens,
        completion_tokens: output_tokens,
        total_tokens: total_tokens
      }

      Result.new(
        text: text,
        stop_reason: body["stop_reason"].to_s,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        raw: body
      )
    end
  end
end
