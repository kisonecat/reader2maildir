#! /usr/bin/ruby
# 
# reader2maildir.rb --- synchronize Google reader with a maildir
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
require 'reader'
require 'mail'
require 'fileutils'
require 'message-ids'
require 'uri'

# String encoding is broken in ruby 1.8
class String
  def encode!(string)
    self
  end
end

# Load configuration file from home directory
configuration_filename = "#{ENV['HOME']}/.reader2maildir"
configuration = YAML::load( File.open( configuration_filename ).read )
user = configuration['username']
pass = configuration['password']
root = configuration['maildir']

if user.nil?
  puts "Missing username in #{configuration_filename}"
  exit
end

if pass.nil?
  puts "Missing password in #{configuration_filename}"
  exit
end

if root.nil?
  puts "Missing maildir in #{configuration_filename}"
  exit
end

# Create maildir root
Dir.mkdir( "#{root}" ) unless File.exist?( "#{root}" )

# Download subscriptions from Google reader
reader = GoogleReader::GoogleReader.new
reader.login( user, pass )
subscriptions = reader.subscriptions
maildirs = Hash.new

for subscription in subscriptions
  subdirectory = URI.escape(subscription.feedurl, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
  directory = "#{root}/#{subdirectory}"
  maildirs[subscription] = Maildir.new( directory )
end

# load the guid database
guids = Hash.new

puts "Creating guid database..."
subdirectories = Dir.new( "#{root}" ).entries.select{ |x| File.stat("#{root}/#{x}").directory? }
  
for subdirectory in subdirectories
  maildir = Maildir.new("#{root}/#{subdirectory}", false)
  guids.merge!( maildir.message_ids )
end

# Process fresh items from Google reader
puts "Downloading items from Google reader..."
items = reader.articles(false)

items.each{ |post|
  guid = post.guid.gsub( 'tag:google.com,2005:reader/item/', '' ) + "@reader.google.com"
  message = guids[guid]

  if message.nil?
    puts "Downloading #{post}..."
    mail = Mail.new do
      from "#{post.author}@example.com"
      message_id "<#{guid}>"
      subject post.title.to_s
      date post.published.to_s
      content_type 'text/html; charset=UTF-8'
      body post.description.to_s
    end
    mail['X-URL'] = post.link.to_s

    maildir = maildirs[post.source]
    message = maildir.add(mail.to_s)
    message.process
    guids[guid] = message
  end

  # TODO currently seen marks are only propagated if the message is in the fresh pile... maybe that's alright?

  # Propogate seen mark from local maildir to Reader
  if message.seen?
    if post.categories.select{ |c| c.match( /\/com.google\/read$/ ) }.length == 0
      post.mark_read
      puts "marking remote #{post} as seen"
    end
  end

  # Propogate seen mark from Reader to local maildir
  if post.categories.select{ |c| c.match( /\/com.google\/read$/ ) }.length > 0 and not message.seen?
    puts "marking local #{post} as seen"
    message.process
    message.seen!
  end
}


