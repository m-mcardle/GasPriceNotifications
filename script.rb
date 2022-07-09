require 'aws-sdk-sns'
require 'uri'
require 'net/http'
require 'openssl'
require 'aws-sdk-kms'
require 'base64'

# TODO - Figure this out
# ENCRYPTED = ENV['RAPID_API_KEY']
# # Decrypt code should run once and variables stored outside of the function
# # handler so that these are decrypted once per container
# DECRYPTED = Aws::KMS::Client.new
#     .decrypt({
#         ciphertext_blob: Base64.decode64(ENCRYPTED),
#         encryption_context: {'LambdaFunctionName' => ENV['AWS_LAMBDA_FUNCTION_NAME']},
#     })
#     .plaintext

# RAPID_API_KEY = DECRYPTED

# TODO - Remove this after above is working
RAPID_API_KEY = ENV['RAPID_API_KEY']

def message_sent?(sns_client, topic_arn, message)

  sns_client.publish(topic_arn: topic_arn, message: message)
rescue StandardError => e
  puts "Error while sending the message: #{e.message}"
end

def run_me
  url = URI('https://canadian-gas-prices.p.rapidapi.com/city-prediction?city=Waterloo')

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Get.new(url)
  request["X-RapidAPI-Key"] = RAPID_API_KEY
  request["X-RapidAPI-Host"] = 'canadian-gas-prices.p.rapidapi.com'

  puts 'Fetching Gas Prices...'
  response = http.request(request)
  puts response
  body = response.read_body
  json = JSON.parse(body)
  change = json['change']
  price = json['price']

  if !change
    puts 'Failure! Response: #{response}'
    exit(1) if !change
  end

  percent_change = ((change) / price).round(2)

  send_message("Gas is going down #{percent_change}% to $#{price}/L tomorrow! That is a change of #{change} cents!") if (percent_change < -5)
  send_message("Gas is going up #{percent_change}% to $#{price}/L tomorrow! That is a change of +#{change} cents!") if (percent_change > 5)
end

def send_message(message)

  topic_arn = ENV['TOPIC_ARN']
  region = 'us-east-2'

  sns_client = Aws::SNS::Client.new(region: region)

  puts "Message sending: '#{message}'"

  if message_sent?(sns_client, topic_arn, message)
    puts 'The message was sent.'
  else
    puts 'The message was not sent. Stopping program.'
    exit 1
  end
end

def lambda_handler(event:, context:)
    run_me()
    { statusCode: 200, body: JSON.generate('Hello from Lambda!') }
end

run_me if $PROGRAM_NAME == __FILE__