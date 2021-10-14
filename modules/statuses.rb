require 'discordrb'
require_relative '../pluggable'

class Statuses

	include Pluggable

	# File paths (relative to this file)
	STATUS_ROOT = "#{__dir__}/status_files"
	GAME_PATH = "#{STATUS_ROOT}/playing_statuses.txt"
	MUSIC_PATH = "#{STATUS_ROOT}/listening_statuses.txt"
	VIDEO_PATH = "#{STATUS_ROOT}/watching_statuses.txt"
	QUOTES_PATH = "#{STATUS_ROOT}/quotes.txt"

	# Run functions on ready
	def start

		# Randomly set status every 10-40 minutes (for spookyness)
		@bot.ready do
			@status_thread = Thread.new do
				loop do
					set_random_status
					#next_sleep = Random.rand(10..40)
					next_sleep = 1
					info("Next status update in #{next_sleep} minutes")
					sleep(next_sleep * 60)
				end
			end
		end

	end

	# Await termination of status thread
	def stop
		Thread.kill(@status_thread)
		@status_thread.join
		info("Status thread terminated")
	end

	# Select a random status from GAME, MUSIC, or VIDEO lists
	def set_random_status

		media_type = Random.rand(1..3)

		case media_type
		when 1
			status = random_file_line(GAME_PATH)
			info("Chose GAME status [#{status}]")
			@bot.playing = status
		when 2
			status = random_file_line(MUSIC_PATH)
			info("Chose MUSIC status [#{status}]")
			@bot.listening = status
		when 3
			status = random_file_line(VIDEO_PATH)
			info("Chose VIDEO status [#{status}]")
			@bot.watching = status
		end

	end

	# Helper to fetch a random line from a file
	def random_file_line(path)
		lines = File.readlines(path)
		return lines.sample.chomp
	end

end
