require 'sinatra'
require 'twilio-ruby'

# A hack around multiple routes in Sinatra
def get_or_post(path, opts={}, &block)
  get(path, opts, &block)
  post(path, opts, &block)
end

# Base URL
get_or_post '/' do
  TWILIO_ACCOUNT_SID = ENV['TWILIO_ACCOUNT_SID'] || TWILIO_ACCOUNT_SID
  TWILIO_AUTH_TOKEN = ENV['TWILIO_AUTH_TOKEN'] || TWILIO_AUTH_TOKEN
  TWILIO_APP_SID = ENV['TWILIO_APP_SID'] || TWILIO_APP_SID
  
  if !(TWILIO_ACCOUNT_SID && TWILIO_AUTH_TOKEN && TWILIO_APP_SID)
    return "Please run configure.rb before trying to do this!"
  end
  @title = "Conference Line"
  capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
  capability.allow_client_outgoing(TWILIO_APP_SID)
  capability.allow_client_incoming('twilioRubyHackpack')
  @token = capability.generate
  erb :client
end

# Primary voice URL for moderators or external callers
get_or_post '/voice' do
  # Check to see if the request is coming from a known "moderator" number
  if (params[:From] = ENV['TWILIO_CALLER_ID'])
    response = Twilio::TwiML::Response.new do |r|
      r.Say 'You are entering the Twilio Sales Conference as a Moderator'
      r.Dial do |d|
        d.Conference 'democonference', :startConferenceOnEnter => 'true', :beep => 'true', \
                      :endConferenceOnExit => 'true' 
      end
    end
  
  else
    response = Twilio::TwiML::Response.new do |r|
      r.Say 'You are entering the Twilio Sales Conference'
      r.Dial do |d|
        d.Conference 'democonference', :startConferenceOnEnter => 'false', :beep => 'true' 
      end
    end
  end
  response.text
end

# Dials in a caller as a particpant
get '/participant' do
  response = Twilio::TwiML::Response.new do |r|
    r.Dial do |d|
      d.Conference 'democonference', :startConferenceOnEnter => 'false', :beep => 'true' 
    end
  end
  response.text
end

# Dials in a caller as a silent listener who is muted and who's arrival is not announced 
get '/listener' do
  response = Twilio::TwiML::Response.new do |r|
    r.Dial do |d|
      d.Conference 'democonference', :startConferenceOnEnter => 'false', \
                    :beep => 'false', :muted => 'true'
    end
  end
  response.text
end