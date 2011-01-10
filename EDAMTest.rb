#
# A simple Evernote API demo application that authenticates with the
# Evernote web service, lists all notebooks in the user's account,
# and creates a simple test note in the default notebook.
#
# Before running this sample, you must change the API consumer key
# and consumer secret to the values that you received from Evernote.
#
# To run (Unix):
#   ruby -I../../lib/ruby -I../../lib/ruby/Evernote/EDAM EDAMTest.rb myuser mypass
#

$LOAD_PATH.unshift("lib/ruby/")
$LOAD_PATH.unshift("lib/ruby/Evernote/EDAM")

require "digest/md5"
require "thrift/types"
require "thrift/struct"
require "thrift/protocol/base_protocol"
require "thrift/protocol/binary_protocol"
require "thrift/transport/base_transport"
require "thrift/transport/http_client_transport"
require "Evernote/EDAM/user_store"
require "Evernote/EDAM/user_store_constants.rb"
require "Evernote/EDAM/note_store"
require "Evernote/EDAM/limits_constants.rb"

#
# NOTE: You must change the consumer key and consumer secret to the 
#       key and secret that you received from Evernote
#
consumerKey = "technophobicgeek"
consumerSecret = "19ca30de71e16f63"

evernoteHost = "sandbox.evernote.com"
userStoreUrl = "https://#{evernoteHost}/edam/user"
noteStoreUrlBase = "https://#{evernoteHost}/edam/note/"

if (ARGV.size < 2)
  puts "Arguments:  <username> <password>"
  exit(1)
end

username = ARGV[0]
password = ARGV[1]

userStoreTransport = Thrift::HTTPClientTransport.new(userStoreUrl)
userStoreProtocol = Thrift::BinaryProtocol.new(userStoreTransport)
userStore = Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)

versionOK = userStore.checkVersion("Ruby EDAMTest",
                                Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
                                Evernote::EDAM::UserStore::EDAM_VERSION_MINOR)
puts "Is my EDAM protocol version up to date?  #{versionOK}"
if (!versionOK)
  exit(1)
end

# Authenticate the user
begin
  authResult = userStore.authenticate(username, password,
                                      consumerKey, consumerSecret)
rescue Evernote::EDAM::Error::EDAMUserException => ex
  # See http://www.evernote.com/about/developer/api/ref/UserStore.html#Fn_UserStore_authenticate
  parameter = ex.parameter
  errorCode = ex.errorCode
  errorText = Evernote::EDAM::Error::EDAMErrorCode::VALUE_MAP[errorCode]

  puts "Authentication failed (parameter: #{parameter} errorCode: #{errorText})"
  
  if (errorCode == Evernote::EDAM::Error::EDAMErrorCode::INVALID_AUTH)
    if (parameter == "consumerKey")
      if (consumerKey == "en-edamtest")
        puts "You must replace the variables consumerKey and consumerSecret with the values you received from Evernote."
      else
        puts "Your consumer key was not accepted by #{evernoteHost}"
      end
      puts "If you do not have an API Key from Evernote, you can request one from http://www.evernote.com/about/developer/api"
    elsif (parameter == "username")
      puts "You must authenticate using a username and password from #{evernoteHost}"
      if (evernoteHost != "www.evernote.com")
        puts "Note that your production Evernote account will not work on #{evernoteHost},"
        puts "you must register for a separate test account at https://#{evernoteHost}/Registration.action"
      end
    elsif (parameter == "password")
      puts "The password that you entered is incorrect"
    end
  end

  exit(1)
end

user = authResult.user
authToken = authResult.authenticationToken
puts "Authentication was successful for #{user.username}"
puts "Authentication token = #{authToken}"

noteStoreUrl = noteStoreUrlBase + user.shardId
noteStoreTransport = Thrift::HTTPClientTransport.new(noteStoreUrl)
noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)

notebooks = noteStore.listNotebooks(authToken)
puts "Found #{notebooks.size} notebooks:"
defaultNotebook = notebooks[0]
notebooks.each { |notebook| 
  puts "  * #{notebook.name}"
  if (notebook.defaultNotebook)
    defaultNotebook = notebook
  end
}
# 
# puts
# puts "Creating a new note in the default notebook: #{defaultNotebook.name}"
# puts
# 
# image = File.open("enlogo.png", "rb") { |io| io.read }
# hashFunc = Digest::MD5.new
# hashHex = hashFunc.hexdigest(image)
# 
# data = Evernote::EDAM::Type::Data.new()
# data.size = image.size
# data.bodyHash = hashHex
# data.body = image
# 
# resource = Evernote::EDAM::Type::Resource.new()
# resource.mime = "image/png"
# resource.data = data
# 
# note = Evernote::EDAM::Type::Note.new()
# note.notebookGuid = defaultNotebook.guid
# note.title = "Test note from ENTest.rb"
# note.content = '<?xml version="1.0" encoding="UTF-8"?>' +
#   '<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml.dtd">' +
#   '<en-note>Here is the Evernote logo:<br/>' +
#   '<en-media type="image/png" hash="' + hashHex + '"/>' +
#   '</en-note>'
# note.created = Time.now.to_i * 1000
# note.updated = note.created
# note.resources = [ resource ]
# 
# createdNote = noteStore.createNote(authToken, note)
# 
# puts "Note was created, GUID = #{createdNote.guid}"

