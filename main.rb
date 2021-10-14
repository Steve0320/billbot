require 'discordrb'
require 'yaml'

# Load all plugin files
Dir.glob('modules/*.rb').each { |f| require_relative(f) }

class Main

	# File paths
	CONFIG_PATH = 'main.config'

	def self.run

		# Load the initial config and persisted values
		load_config

		# Initialize bot for Discord communication
		bot = Discordrb::Bot.new(token: @config['bot_token'])
		logger = Discordrb::LOGGER

		logger.info("Invite URL: #{bot.invite_url}")
		bot.ready { logger.info("Bot successfully connected to Discord") }

		# Initialize all plugins
		plugins = plugin_classes.map { |p| p.new(bot, logger) }
		logger.info("Found #{plugins.count} plugins: #{plugins.map(&:plugin_name).join(', ')}")

		# Register plugin functionality
		plugins.each do |p|
			begin
				p.start
				Discordrb::LOGGER.info("Successfully started #{p.plugin_name} plugin")
			rescue StandardError => e
				Discordrb::LOGGER.info("Failed to start #{p.plugin_name}: #{e.message}")
			end
		end

		# Main loop - start the bot and block
		begin
			Discordrb::LOGGER.info("Starting bot")
			bot.run(true)
			sleep
		rescue Interrupt => e
			Discordrb::LOGGER.info("Stopping bot")
			plugins.each { |p| p.stop(bot) }
			bot.stop
		end


	end

	# If the config file exists already, load and return
	def self.load_config

		expected_keys = %w[bot_token notification_channel_id]

		# Ensure config exists
		unless File.file?(CONFIG_PATH)
			puts "ERROR: Missing config file. Generating default one - fill it out and run again."
			config = expected_keys.map { |k| [k, 'FILL OUT'] }.to_h
			File.write(CONFIG_PATH, config.to_yaml)
			exit(-1)
		end
	
		config = YAML.load(File.read(CONFIG_PATH))
		
		# Ensure all expected keys are present
		unless (expected_keys - config.keys).empty?
			puts "ERROR: Invalid config file. Ensure the following keys are present: #{expected_keys.join(', ')}"
			exit(-1)
		end

		@config = config

	end

	# Update the config keys and write to file
	def self.modify_config(mods)
		@config = @config.merge(mods)
		File.write(CONFIG_PATH, @config.to_yaml)
	end

	# Convenience accessor to abstract away global variables a bit
	def self.plugin_classes
		$plugins || []
	end

end

Main.run