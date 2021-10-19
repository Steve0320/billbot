require 'discordrb'
require 'rest_client'
require 'json'
require_relative '../pluggable'

class DeepText

	include Pluggable

	def self.required_config_keys
		['deepai_key']
	end

	def start
		@bot.mention(contains: /what'{0,1}s my horoscope/i) do |event|
			response = complete_text('Your horoscope is')
			if response
				event.respond(response)
			else
				event.respond("Horoscopes are bunk, I tell ya! (also, something went wrong and ah couldn' find it...)")
			end
		end
	end

	def api_key
		@config['deepai_key']
	end

	# Use DeepAI's text completion and return the completed text.
	def complete_text(str)
		begin
			r = RestClient::Request.execute(
				method: :post,
				url: 'https://api.deepai.org/api/text-generator',
				timeout: 600,
				headers: { 'api-key' => api_key },
				payload: { 'text' => str }
			)
		rescue RestClient::ExceptionWithResponse => e
			info("Text completion request failed: #{e.message}")
			return false
		else
			return JSON.parse(r)['output']
		end
	end

end
