require 'json'

class Properties
   def initialize()
      @file_path="application.json"
   end
   def get_properties()
     if File.exists?(@file_path)
       @file = File.read("#{@file_path}")
     else
        return nil
     end
     return JSON.parse(@file)
   end
end
