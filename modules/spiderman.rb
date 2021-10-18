require 'discordrb'
require 'flickr'
require_relative '../pluggable'

class Spiderman

	include Pluggable

	PAGE_SIZE = 100
	RESOLUTIONS = %w[url_o url_l url_m url_s url_sq]

	def self.required_config_keys
		['flickr_id', 'flickr_secret']
	end

	def start

		@flickr = Flickr.new(@config['flickr_id'], @config['flickr_secret'])

		@bot.mention(contains: 'spiderman me') do |event|
			event.respond(random_photo('spiderman'))
		end

		# Respond to mentions that start with "Show me..."
		show_me_trigger = /.*[Ss]how me((?:\s+\S+){1,3})/
		@bot.message(contains: show_me_trigger) do |event|

			# Extract actual request
			original_query = event.message.to_s.match(show_me_trigger).captures[0]&.lstrip&.gsub(/\W+/, ' ')

			if original_query == nil
				event.respond("I ain't got no clue whatcher talking bout.")
				next
			end

			# Strip modifiers
			modifiers = ['a', 'the', 'some']
			query = original_query
			modifiers.each do |m|
				if original_query.start_with?(m + ' ')
					query = query.sub(m + ' ', '')
					break
				end
			end

			photo = random_photo(query)
			if photo == nil
				event.respond("I looked high an' low but I just couldn't find #{original_query}. Sorry!")
			else
				event.respond(photo)
			end

		end

	end

	# Search the Flickr API for a random photo
	def random_photo(str)

		# Right now we only search the first page
		results = @flickr.photos.search(text: str, per_page: PAGE_SIZE, extras: RESOLUTIONS.join(','))
		info("Query #{str} returned #{results.size} results on page one, and #{results.pages} pages")
		return nil unless results.size > 0

		result = results[rand(1..results.size) - 1]
		url_key = RESOLUTIONS.find { |r| !result[r].nil? }
	
		if url_key.nil?
			info("No supported resolutions found")
			return nil
		else
			info("Select resolution #{url_key}")
			return result[url_key]
		end

	end

	# Remove all mentions from the given string and return the result. Also removes
	# some redundant spaces that might be left afterwards.
	def strip_mention(str)
		str.gsub(/<@!\d+>/, '').squeeze(" ").lstrip
	end

end
