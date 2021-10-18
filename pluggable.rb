require 'discordrb'

# This module is expected to be included into all plugin classes
# for the discord bot. These are expected to implement the "start"
# method, which receives a discord bot as an argument.
module Pluggable

	# Hook to register the including class to the plugin list
	def self.included(base)
		$plugins ||= []
		$plugins << base
		base.extend(ClassMethods)
	end

	# Class-level methods
	module ClassMethods

		# The name of the plugin
		def plugin_name
			self.name
		end

		# Any keys required for the plugin
		def required_config_keys
			[]
		end

	end

	# Accessors for all instance variables set by the instantiator
	attr_accessor :bot
	attr_accessor :logger
	attr_accessor :config

	# Shorthand info
	def info(str)
		@logger.info(str)
	end

	# Modules should implement this
	def start
		info("Loaded a plugin with no behavior")
	end

	# Modules may optionally implement this to close out their
	# resources gracefully.
	def stop
	end

	# Convenience accessor
	def plugin_name
		self.class.plugin_name
	end

end
