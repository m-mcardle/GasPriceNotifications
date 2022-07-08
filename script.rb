require 'aws-sdk-sns'
require 'uri'
require 'net/http'
require 'openssl'

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
  request["X-RapidAPI-Key"] = ENV['RAPID_API_KEY']
  request["X-RapidAPI-Host"] = 'canadian-gas-prices.p.rapidapi.com'

  response = http.request(request)
  body = response.read_body
  json = JSON.parse(body)
  change = json['change']
  price = json['price']

  send_message("Gas is going down to $#{price}/L tomorrow! That is a change of #{change} cents!") if (change < -10)
  send_message("Gas is going up to $#{price}/L tomorrow! That is a change of +#{change} cents!") if (change > 10)
end

def send_message(message)

  topic_arn = 'arn:aws:sns:us-east-2:428539789229:Gas-Price-Alerts'
  region = 'us-east-2'

  sns_client = Aws::SNS::Client.new(region: region)

  puts "Message sending."

  if message_sent?(sns_client, topic_arn, message)
    puts 'The message was sent.'
  else
    puts 'The message was not sent. Stopping program.'
    exit 1
  end
end

run_me if $PROGRAM_NAME == __FILE__