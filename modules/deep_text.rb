require 'discordrb'
require 'rest_client'
require 'json'
require_relative '../pluggable'

class DeepText

	include Pluggable

	STATUS_ROOT = "#{__dir__}/fanfic"
	CHARACTER_PATH = "#{STATUS_ROOT}/characters.txt"
	TITLES_PATH = "#{STATUS_ROOT}/titles.txt"
	ERROR_TEXT = "Horoscopes are bunk, I tell ya! (also, something went wrong and ah couldn' find it...)"

	def self.required_config_keys
		['deepai_key']
	end

	def start

		# General bad horoscopes
		@bot.mention(contains: /what'{0,1}s my horoscope/i) do |event|
			response = complete_text('Your horoscope is')
			if response
				event.respond(response)
			else
				event.respond(ERROR_TEXT)
			end
		end

		# Personalized bad horoscopes
		horoscope_regex = /what'{0,1}s (.*) horoscope/i
		@bot.mention(contains: horoscope_regex) do |event|

			name = event.message.to_s.match(horoscope_regex).captures[0]&.gsub("'s", "")
			info("Issuing personalized horoscope for #{name}")

			response = complete_text("#{name.capitalize}'s personalized horoscope for today is")
			if response
				event.respond(response)
			else
				event.respond(ERROR_TEXT)
			end
		
		end

		# Famous quotes generator
		quote_regex = /give me an{0,1} (.*) quote/i
		@bot.mention(contains: quote_regex) do |event|

			name = event.message.to_s.match(quote_regex).captures[0]&.split(' ')&.map(&:capitalize)&.join(' ')
			info("Issuing probably-libelous quote for #{name}")

			response = complete_text("#{name} once said: ")
			if response
				event.respond(parse_quote(response))
			else
				event.respond("I couldn't find a quote for that'un. You sure they exist?")
			end

		end

		# Write a bad erotic pairing. Potential employers plz ignore, thx
		@bot.mention(contains: /write me a bad fanfic/i) do |event|

			first_character = random_file_line(CHARACTER_PATH)
			second_character = random_file_line(CHARACTER_PATH)
			title = random_file_line(TITLES_PATH)

			title = "#{first_character} X #{second_character}: #{title}"
			info("Generating a masterpiece: #{title}")

			text_start = "#{first_character} and #{second_character} loved each other very much."

			response = complete_text(text_start)
			if response
				event.respond("#{title}\n#{response}")
			else
				event.respond(ERROR_TEXT)
			end

		end

	end

	# Limit the text to just the first pair of quotation marks (and
	# any preceding text).
	def parse_quote(text)

		counter = 0
		output = []

		text.each_char do |c|
			counter += 1 if c == "\""
			output << c
			break if counter == 2
		end

		return output.join

	end

	def api_key
		@config['deepai_key']
	end

	# Make a title of a bad erotic fanfic
	def make_title

		first_character = random_file_line(CHARACTER_PATH)
		second_character = random_file_line(CHARACTER_PATH)
		title = random_file_line(TITLES_PATH)

		return "#{first_character} X #{second_character}: #{title}"

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

	# Helper to fetch a random line from a file
	# TODO: This is duplicated, probably would be better in a helper
	def random_file_line(path)
		lines = File.readlines(path)
		return lines.sample.chomp
	end

end
