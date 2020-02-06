require 'json'
require 'open-uri'
# https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Polly.html
require 'aws-sdk-polly'
# https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/TranscribeService.html
require 'aws-sdk-transcribeservice'
# https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Comprehend.html
require 'aws-sdk-comprehend'

def lambda_handler(event:, context:)
  polly_client = Aws::Polly::Client.new

  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Polly/Client.html#start_speech_synthesis_task-instance_method
  @polly_resp = polly_client.start_speech_synthesis_task({
    engine: :standard,
    language_code: 'ja-JP',
    output_format: :mp3, 
    output_s3_bucket_name: ENV['S3_BUCKET_NAME'],
    sample_rate: '22050',
    text: event['text'],
    text_type: :text,
    voice_id: 'Mizuki',
  })

  loop do
    # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Polly/Client.html#get_speech_synthesis_task-instance_method
    @polly_resp = polly_client.get_speech_synthesis_task({
      task_id: @polly_resp.synthesis_task.task_id,
    })
    # TODO: 'FAILED' Handling
    break if ['failed', 'completed'].include?(@polly_resp.synthesis_task.task_status)
    sleep(5)
  end

  transcribe_client = Aws::TranscribeService::Client.new

  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/TranscribeService/Client.html#start_transcription_job-instance_method
  @transcribe_resp = transcribe_client.start_transcription_job({
    transcription_job_name: @polly_resp.synthesis_task.task_id,
    language_code: 'ja-JP',
    media_format: @polly_resp.synthesis_task.output_format,
    media: {
      media_file_uri: @polly_resp.synthesis_task.output_uri,
    },
  })

  loop do
    # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/TranscribeService/Client.html#get_transcription_job-instance_method
    @transcribe_resp = transcribe_client.get_transcription_job({
      transcription_job_name: @polly_resp.synthesis_task.task_id,
    })
    # TODO: 'FAILED' Handling
    break if ['FAILED', 'COMPLETED'].include?(@transcribe_resp.transcription_job.transcription_job_status)
    sleep(5)
  end

  uri = URI.parse(@transcribe_resp.transcription_job.transcript.transcript_file_uri)
  transcribe_job_resp = JSON.parse(uri.open.read)
  transcript = transcribe_job_resp['results']['transcripts'][0]['transcript']

  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Comprehend/Client.html#initialize-instance_method
  # 'ap-northeast-1' not supported.
  comprehend_client = Aws::Comprehend::Client.new(region: 'us-west-2')

  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Comprehend/Client.html#detect_sentiment-instance_method
  sentiment_resp = comprehend_client.detect_sentiment({
    text: transcript,
    language_code: :ja
  })

  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Comprehend/Client.html#detect_syntax-instance_method
  key_phrases_resp = comprehend_client.detect_key_phrases({
    text: transcript,
    language_code: :ja
  })

  {
    statusCode: 200,
    body: {
      polly_uri: @polly_resp.synthesis_task.output_uri,
      transcribe_uri: @transcribe_resp.transcription_job.transcript.transcript_file_uri,
      transcribe_text: transcribe_job_resp,
      comprehend_sentiment: sentiment_resp.sentiment,
      comprehend_key_phrases: key_phrases_resp.key_phrases,
    }.to_json
  }
end
