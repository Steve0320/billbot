# BillBot
Discord bot providing some useful functions for roommates

## Architecture
This bot is broken into a main runner defined in main.rb, which handles initializing the bot and loading the configuration file. It also automatically loads
all plugin classes defined in the modules directory and calls their hooks at the appropriate time.

### Plugins
This bot allows plugins to be defined in the modules directory. Plugins are defined as simple Ruby classes which include the Pluggable module. The Pluggable
module automatically inserts the class into the plugins list, and provides default implementations of all plugin hooks. At minimum, a plugin must define the
`start` method, which takes no arguments and defines the code to be run when the bot initializes. This usually entails registering a callback on the bot instance
as one normally would. The Pluggable module also provides a default constructor which initializes the @bot and @logger instance variables; this constructor may
be overridden as long as it implements the same method signature.

## Existing Plugins

### Statuses
The Statuses plugin automatically shuffles the bot's status every 10 to 40 minutes to one of the statuses defined in the modules/status_files directory. This
serves no functional purpose other than to make things more fun and spooky.

### Administration
The Administration plugin provides handlers for administration-related tasks.
