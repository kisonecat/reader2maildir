#! /usr/bin/ruby
# 
# reader.rb --- ruby interface to Google Reader API
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
require 'net/https'
require 'json'
require 'rfeedparser'

module GoogleReader

  class GoogleReader
    def login(user, pass)
      url = "https://www.google.com/accounts/ClientLogin"
      uri = URI.parse(url)
      params = {
        'service' => 'reader',
        'Email' => user,
        'Passwd' => pass,
        'source' => 'reader2maildirv0.3'
      }
    
      http = Net::HTTP.new(uri.host, uri.port)
      req = Net::HTTP::Post.new(uri.path)
      req.set_form_data(params)
      http.use_ssl = true
      body = http.request(req).body
      
      @vars = {}
      body.split("\n").each do |kv|
        kvs = kv.split("=")
        @vars[kvs[0]] = kvs[1]
      end
    end

    def to_s
      "<GoogleReader>"
    end

    def inspect
      self.to_s
    end

    def auth_token
      return @vars['Auth']
    end

    # Retrieve a token to change something in the reader
    def edit_token
      return @token unless @token.nil?

      url = "http://www.google.com/reader/api/0/token"
      uri = URI.parse url
      
      headers = {
        'Authorization' => "GoogleLogin auth=#{@vars['Auth']}"
      }
      
      http = Net::HTTP.new uri.host, uri.port
      req = Net::HTTP::Get.new uri.path, headers
      @token = http.request(req).body

      return @token
    end

    # List all Subscriptions
    def subscriptions
      return @subscriptions unless @subscriptions.nil?

      url = "http://www.google.com/reader/api/0/subscription/list?output=json"
      uri = URI.parse url
      
      headers = {
        'Authorization' => "GoogleLogin auth=#{@vars['Auth']}"
      }
      
      http = Net::HTTP.new uri.host, uri.port
      req = Net::HTTP::Get.new uri.path + "?output=json", headers
      subscriptions = JSON.parse(http.request(req).body)['subscriptions'].map do |item| 
        {
          'feedurl' => item['id'].gsub(/^feed\//, ''),
          'title' => item['title'],
          'tags' => item['categories'].map{ |cat| cat['label'] }
        }
      end

      @subscriptions = subscriptions.collect{ |s|
        sub = Subscription.new
        sub.title = s['title']
        sub.tags = s['tags']
        sub.feedurl = s['feedurl']
        sub.reader = self

        sub
      }
      return @subscriptions
    end

    def parse(data)
      data['items'].collect{ |item|
        article = Article.new
        article.description = item['content'].to_s
        if article.description.length == 0
          article.description = item['summary']['content'] unless item['summary'].nil?
        end
        article.author = item['author']
        article.email = item['email']
        article.title = item['title']
        article.link = item['alternate'][0]['href']
        article.categories = item['categories']
        article.published = Time.at(item['published'])
        article.guid = item['id']
        article.reader = self

        article.source = self.subscriptions.select{ |s| s.feedurl == item['origin']['streamId'].gsub( /^feed\//, '' ) }[0]

        article
      }
    end

    def articles( continuing )
      query = "?ot=0&output=json&n=1000&ck=#{Time.now.tv_sec}&client=offlinereader"
      url = "http://www.google.com/reader/api/0/stream/contents/user/-/state/com.google/reading-list"

      if continuing and @continuation.nil?
        return nil
      end

      if continuing
        puts "using #{@continuation}"
        query = query + "&c=#{@continuation}"
      end
      uri = URI.parse(url)
      puts "using #{uri.path}"
      
      headers = {
        'Authorization' => "GoogleLogin auth=#{self.auth_token}"
      }
  
      http = Net::HTTP.new(uri.host, uri.port)
      req = Net::HTTP::Get.new(uri.path + query, headers)
      data = JSON.parse(http.request(req).body)

      @continuation = data['continuation']

      return self.parse(data)
    end
  end # of class GoogleReader

  class Subscription
    attr_accessor :title
    attr_accessor :tags
    attr_accessor :feedurl
    attr_accessor :reader

    def to_s
      "<Subscription: #{title}>"
    end

    def inspect
      self.to_s
    end
  end # of class Subscription

  class Article
    attr_accessor :description
    attr_accessor :author
    attr_accessor :email
    attr_accessor :categories
    attr_accessor :title
    attr_accessor :link
    attr_accessor :published
    attr_accessor :guid
    attr_accessor :source
    attr_accessor :reader

    def to_s
      "<Article '#{self.title}' from #{self.source}>"
    end

    def inspect
      self.to_s
    end

    def add_tag(tag)
      url = 'http://www.google.com/reader/api/0/edit-tag'
      uri = URI.parse url
  
      headers = {
        'Authorization' => "GoogleLogin auth=#{self.reader.auth_token}"
      }

      http = Net::HTTP.new(uri.host, uri.port)
      req = Net::HTTP::Post.new(uri.path, headers)
      req.set_form_data({
                          'i' => self.guid,
                          's' => "feed/#{self.source.feedurl}",
                          'ac' => 'edit-tags',
                          'a' => "user/-/state/com.google/#{tag}",
                          'T' => self.reader.edit_token
                        })
      res = http.request(req).body
    end

    def mark_read
      self.add_tag("read")
    end
    
  end # of class Article

end # of module
