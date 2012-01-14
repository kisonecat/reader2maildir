#! /usr/bin/ruby
# 
# message-ids.rb --- extend maildir gem with message-ids
# 
# Copyright (C) 2011 Jim Fowler     
# 
# This file is part of reader2maildir.
# 
# reader2maildir is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# reader2maildir is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with reader2maildir.  If not, see <http://www.gnu.org/licenses/>.

require 'rubygems'
require 'maildir'

class Maildir::Message
  # Fetch message_id from message on disk
  def message_id
    for line in File.open(self.path).readlines do
      if line.match( /^[Mm]essage-[Ii][Dd]: <(.*)>/ )
        return $1
      end
    end
    return nil
  end
end

class Maildir
  # Return hash from message_ids to messages
  def message_ids
    return @message_ids unless @message_ids.nil?
    
    @message_ids = Hash.new
    
    messages = self.list(:new) + self.list(:cur) 

    for message in messages
      message_id = message.message_id
      
      next if message_id.nil?

      @message_ids[message_id] = message
    end

    return @message_ids
  end

  def message_by_id(message_id)
    self.message_ids[message_id]
  end
end
