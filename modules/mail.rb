require 'discordrb'
require 'tty-prompt'
require 'pdfkit'
require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require_relative '../pluggable'

class Mail

  include Pluggable

  def self.required_config_keys
    #['email_poll_interval', 'email_watch_labels']
    ['bill_channel', 'bill_poll_minutes']
  end

  # Initialize the API connection and register the email poll signal
  def setup

    @service = Google::Apis::GmailV1::GmailService.new.tap do |s|
      s.client_options.application_name = 'BillBot Email Parser'
      s.authorization = set_credentials('credentials.json', 'google-tokens.yaml')
    end

    info('Successfully connected to the Gmail API')

    @labels = get_sublabel_names('Billing Statements')
    info("Fetched #{@labels.count} labels")

    # Configure PDF exporter
    PDFKit.configure do |c|
      c.default_options = { page_size: 'Legal', print_media_type: true, 'enable-local-file-access': true }
      c.wkhtmltopdf = @config['wk_location'] if @config['wk_location']
    end
    info('Configured wkhtmltopdf exporter')

    @last_check = Time.now
    @check_interval = @config['bill_poll_minutes'].to_i * 60

  end

  def start

    # Every <bill_poll_interval> minutes, check for new bills
    @bot.ready do
      @poll_thread = Thread.new do
        loop do
          info("Next email poll in #{@check_interval / 60} minutes")
          sleep(@check_interval)
          post_messages
          @last_check = Time.now
        end
      end
    end

    # Trigger manual bill check - usually called on timer
    @bot.mention(contains: /check for bills/i) do |event|
      event.respond("Checkin' now, I'll post anythin' new to the bill channel when I'm done")
      post_messages
    end

    # Helper to divide up an amount evenly among all members in the server
    divide_trigger = /divvy up \${0,1}([1-9]+[0-9]*\.{0,1}[0-9]+)/i
    @bot.mention(contains: divide_trigger) do |event|

      amount = event.message.to_s.match(divide_trigger).captures[0]&.to_f
      if !amount || amount == 0
        event.respond("That don't look like no number I ever seen.")
        next
      end

      # Get the list of everyone on the server, minus bots and the tagger
      if event.server.nil?
        event.respond("This don't work in PM's, dummy.")
        next
      end

      relevant_users = event.server.members - (event.server.bot_members + [event.author])
      price = (amount / relevant_users.count).ceil(2)
      response = relevant_users.map { |u| "#{u.mention}: $#{'%.2f' % price}" }.join("\n")

      event.respond(response)

    end

  end

  def stop
    Thread.kill(@poll_thread)
    @poll_thread.join
    info("Email check thread terminated")
  end

  # Core functionality - query messages, convert to PDF, and post in the configured channel
  def post_messages

    query = @labels.map { |l| "label:#{l}" }.join(' OR ')
    query += " after:#{@last_check.to_i}"

    info("Polling for messages with the following query: #{query}")
    messages = fetch_messages(@service, { q: query })

    if messages.empty?
      info("No new messages found")
      return
    end

    channel_id = @config['bill_channel']

    info("Generating PDFs for #{messages.count} emails...")

    messages.each do |msg|

      pdf_text = convert_to_pdf(msg)
      subject = extract_subject(msg)

      Tempfile.create(['', '.pdf']) do |f|
        f.write(pdf_text)
        f.rewind
        @bot.send_file(channel_id, f, caption: "Y'all got a bill or something!", filename: "#{subject}.pdf")
      end

    end

    info("Finished posting #{messages.count} files")

  end

  # Create the credentials object needed to access Google APIs. This handles loading the appropriate
  # credentials from a credential file, and performs the initial OAuth step if no cached token is present.
  def set_credentials(credentials_path, token_store_path, user_id = 'default')

    # Initialize backing token store
    client_id = Google::Auth::ClientId.from_file(credentials_path)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: token_store_path)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, Google::Apis::GmailV1::AUTH_GMAIL_READONLY, token_store)

    credentials = authorizer.get_credentials(user_id)

    # Perform initial OAuth step
    if credentials.nil?

      # Note: This is a special value which tells OAuth to return an auth code instead of redirecting
      code_url = 'urn:ietf:wg:oauth:2.0:oob'

      prompt = TTY::Prompt.new
      prompt.say("Open the following URL in a browser and paste the authorization code:")
      prompt.say(authorizer.get_authorization_url(base_url: code_url))
      auth_code = prompt.ask('Code: ', required: true)

      # Exchange auth code for a refresh token
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id,
        code: auth_code,
        base_url: code_url
      )

    end

    return credentials

  end

  # Get the name of all child labels under the named parent. The set returned also
  # includes the parent label.
  def get_sublabel_names(parent)

    all_labels = @service.list_user_labels('me')
    return [] if all_labels.nil?

    names = all_labels.labels.map do |label|
      next nil unless label.name.start_with?(parent)
      next label.name
    end

    # Gmail filters escape special characters as dashes
    return names.compact.map { |n| n.downcase.gsub(/[^a-z\/]/, '-') }

  end

  # Fetch the full data for all messages matching the given filter.
  def fetch_messages(service, filter = {})

    full_data = []

    messages = service.list_user_messages('me', **filter)
    if messages.messages
      messages.messages.each { |m| full_data << service.get_user_message('me', m.id, format: 'FULL') }
    end

    return full_data

  end

  # Extract the subject header from the message
  def extract_subject(msg)
    msg.payload.headers.find { |h| h.name == 'Subject' }.value || 'Unknown Subject'
  end

  # Convert a Gmail message object to a PDF object. Returns the formatted PDF as a text string.
  def convert_to_pdf(msg)

    # The payload field is essentially a tree of MessageParts - we want the first HTML one.
    # This only goes 2 levels deep, but technically these can be arbitrarily nested.
    html_part = msg.payload
    unless html_part.mime_type == 'text/html'
      html_part = html_part.parts.find { |p| p.mime_type == 'text/html' }
    end

    html = html_part.body.data
    return PDFKit.new(html).to_pdf

  end

end