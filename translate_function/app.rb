require 'json'
# https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Translate/Client.html
require 'aws-sdk-translate'

def lambda_handler(event:, context:)
  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Translate/Client.html#initialize-instance_method
  client = Aws::Translate::Client.new
  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Translate/Client.html#translate_text-instance_method
  resp = client.translate_text({
    text: event['text'],
    source_language_code: :en,
    target_language_code: :ja,
  })
  
  {
    statusCode: 200,
    body: {
      message: resp.translated_text,
    }.to_json
  }
end
