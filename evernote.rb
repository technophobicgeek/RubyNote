# TODO need to understand ruby method parameters better. default values, named parameters.


$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/lib/ruby/")
$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/lib/ruby/Evernote/EDAM")

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



module VisualTasks
  class EvernoteClient
    
    # TODO: The following static variables should be read from a config file
    @@consumerKey = "technophobicgeek"
    @@consumerSecret = "19ca30de71e16f63"

    @@evernoteHost = "sandbox.evernote.com"
    @@userStoreUrl = "https://#{@@evernoteHost}/edam/user"
    @@noteStoreUrlBase = "https://#{@@evernoteHost}/edam/note/"
         
    @@empty_note = '<?xml version="1.0" encoding="UTF-8"?>' +
        '<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml.dtd">' +
        '<en-note></en-note>'
    
    def initialize(username, password)
      @notebooks = nil
      
      @userStore = create_userStore
      
      versionOK = @userStore.checkVersion("Ruby EDAMTest",
                                      Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
                                      Evernote::EDAM::UserStore::EDAM_VERSION_MINOR)
      puts "Is my EDAM protocol version up to date?  #{versionOK}"
      if (!versionOK)
        exit(1)
      end
      
      authInfo = authenticate(username,password)
      @user = authInfo[:user]
      @authToken = authInfo[:token]
      
      @noteStore = create_noteStore(@user)
      
    end

    def notebooks
      if @notebooks.nil?
        @notebooks = @noteStore.listNotebooks(@authToken)
        extract_notebook_names
      end
      @notebooks
    end

    def create_notebook(name)
      unless @notebook_hash.include?(name)
        nb = Evernote::EDAM::Type::NoteBook.new()
        nb.name = name
        nb = createNotebook(@authToken,nb)
        @notebook_hash[name] = nb
      end
    end
    
    def create_note(title,txt)
      defaultNotebook = @notebooks[0]
      puts "Creating a new note in the default notebook: #{defaultNotebook.name}"

      note = Evernote::EDAM::Type::Note.new()
      note.notebookGuid = defaultNotebook.guid
      note.title = title
      note.content = text_note(txt)
      note.created = Time.now.to_i * 1000
      note.updated = note.created

      createdNote = @noteStore.createNote(@authToken, note)

      puts "Note was created, GUID = #{createdNote.guid}"
    end
    
    def tag_note
    end

    def find_notes(notebook, tag)
      
    end
    
    private
    
      def create_userStore
        userStoreTransport = Thrift::HTTPClientTransport.new(@@userStoreUrl)
        userStoreProtocol = Thrift::BinaryProtocol.new(userStoreTransport)    
        Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)
      end
      
      def create_noteStore(user)
        noteStoreUrl = @@noteStoreUrlBase + user.shardId
        noteStoreTransport = Thrift::HTTPClientTransport.new(noteStoreUrl)
        noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
        Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)
      end
    
      def authenticate(username,password)
        begin
          authResult = @userStore.authenticate(username, password,@@consumerKey, @@consumerSecret)
          ({:user => authResult.user, :token => authResult.authenticationToken})
        rescue Evernote::EDAM::Error::EDAMUserException => ex
          process_exn ex
        end
      end
      
      def process_exn(ex)
        # See http://www.evernote.com/about/developer/api/ref/UserStore.html#Fn_UserStore_authenticate
        parameter = ex.parameter
        errorCode = ex.errorCode
        errorText = Evernote::EDAM::Error::EDAMErrorCode::VALUE_MAP[errorCode]
        evernoteHost = @@evernoteHost
        
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

      def text_note(txt)
        %Q{<?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml.dtd">
        <en-note>#{txt}</en-note>}
      end

      def extract_notebook_names
        @notebook_hash = {} # TODO Should be a hash
        @notebooks.each { |notebook|
          @notebook_hash[notebook.name] = notebook
        }
      end
 
  end
end
