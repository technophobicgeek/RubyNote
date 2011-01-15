require 'evernote'

eclient = VisualTasks::EvernoteClient.new("plusbzz","bzzme1ce")

notebooks = eclient.notebooks
puts "Found #{notebooks.size} notebooks:"
defaultNotebook = notebooks[0]
notebooks.each { |notebook| 
  puts "  * #{notebook.name}"
  if (notebook.defaultNotebook)
    defaultNotebook = notebook
  end
}

eclient.create_note("new note " + Time.now.to_s,"hello")