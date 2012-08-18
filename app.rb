require 'sinatra'
require 'twilio-ruby'

# A hack around multiple routes in Sinatra
def get_or_post(path, opts={}, &block)
  get(path, opts, &block)
  post(path, opts, &block)
end

# Simple rack auth
helpers do

  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [ENV['RACK_USER'], ENV['RACK_PW']]
  end

end

# Base URL
get_or_post '/' do
  #protected!

  TWILIO_ACCOUNT_SID = ENV['TWILIO_ACCOUNT_SID'] || TWILIO_ACCOUNT_SID
  TWILIO_AUTH_TOKEN = ENV['TWILIO_AUTH_TOKEN'] || TWILIO_AUTH_TOKEN
  TWILIO_APP_SID = ENV['TWILIO_APP_SID'] || TWILIO_APP_SID
  TWILIO_CALLER_ID = ENV['TWILIO_CALLER_ID'] || TWILIO_CALLER_ID

  if !(TWILIO_ACCOUNT_SID && TWILIO_AUTH_TOKEN && TWILIO_APP_SID)
    return "Please run configure.rb before trying to do this!"
  end
  @title = "Conference Line"
  capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
  capability.allow_client_outgoing(TWILIO_APP_SID)
  @token = capability.generate
  @twilionumber = TWILIO_CALLER_ID
  erb :client
end

# Primary voice URL for moderators or external callers
get_or_post '/voice' do
  # Check to see if the request is coming from a known "moderator" number
  if (params[:From] = ENV['TWILIO_CALLER_ID'])
    response = Twilio::TwiML::Response.new do |r|
      r.Say 'You are entering the Twilio Sales Conference as a Moderator'
      r.Dial do |d|
        d.Conference 'democonference',:endConferenceOnExit => 'true',\
                      :waitUrl => 'http://twimlets.com/holdmusic?Bucket=com.twilio.music.electronica'
      end
    end
  
  else
    response = Twilio::TwiML::Response.new do |r|
      r.Say 'You are entering the Twilio Sales Conference'
      r.Dial do |d|
        d.Conference 'democonference', :startConferenceOnEnter => 'false' 
      end
    end
  end
  response.text
end

# Dials in a caller
get_or_post '/unmuted' do
  response = Twilio::TwiML::Response.new do |r|
    r.Dial do |d|
      d.Conference 'democonference', :startConferenceOnEnter => 'false', :beep => 'false' 
    end
  end
  response.text
end

# Dials in a caller who is muted without a beep
get_or_post '/muted' do
  response = Twilio::TwiML::Response.new do |r|
    r.Say 'You are entering the Twilio Sales Conference and are muted'
    r.Dial do |d|
      d.Conference 'democonference', :startConferenceOnEnter => 'false', \
                    :beep => 'false', :muted => 'true'
    end
  end
  response.text
end

# Makes an API call to bring a caller into the conference
post '/dialparticipant' do
#protected!

TWILIO_ACCOUNT_SID = ENV['TWILIO_ACCOUNT_SID'] || TWILIO_ACCOUNT_SID
TWILIO_AUTH_TOKEN = ENV['TWILIO_AUTH_TOKEN'] || TWILIO_AUTH_TOKEN
TWILIO_CALLER_ID = ENV['TWILIO_CALLER_ID'] || TWILIO_CALLER_ID

@client = Twilio::REST::Client.new(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)

@account = @client.account
@call = @account.calls.create({:from => TWILIO_CALLER_ID, :to => params[:number], :url => request.base_url << "/" << params[:mute]})
puts @call

end