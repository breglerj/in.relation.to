#!/usr/bin/env ruby
# encoding: UTF-8

require "rubygems"
require "bundler/setup"

require_relative 'blog_entry'
require_relative 'wxr_exporter'

require 'choice'
require 'pstore'
require 'nokogiri'
require 'date'
require 'fileutils'
require 'net/http'
require 'uri'

Choice.options do
  header 'Creates a HTTP redirects file for all blog users. Application options:'

  separator 'Required:'

  option :pstore, :required => true do
    short '-s'
    long '--store=<file>'
    desc 'The PStore file containing the spidered HTML. Expected to contain all blogger documents such as http://in.relation.to/Bloggers/Gunnar, http://in.relation.to/Bloggers/Davide etc.'
  end

  option :outfile, :required => true do
    short '-o'
    long '--output=<file>'
    desc 'The file to write the redirect rules to'
  end

  separator 'Common:'

  option :help do
    short '-h'
    long '--help'
    desc 'Show this message.'
  end
end

class Importer

  def initialize(import_file, out_file)
    @import_file = import_file
    @out_file = out_file
    @feed_url = "/blog.atom"
  end

  def process_bloggers
    bloggers = PStore.new(@import_file)
    redirects = File.open( @out_file, 'w')
    redirects.write "# Generated by #{File.basename($PROGRAM_NAME)}\n\n"

    bloggers.transaction(true) do
      bloggers.roots.each do |lace|
        process_blogger(lace, bloggers[lace], redirects)
      end
    end

    redirects.close
  end

  private

  def process_blogger(lace, content, redirects)
    doc = Nokogiri::HTML(content)

    name = doc.xpath("//div[@id='breadcrumb']/span/a[3]/text()").to_s
    blogger_name = doc.xpath("//div[@id='breadcrumb']/span/a[3]/@href").to_s[1..-1]
    home = doc.xpath("//div[@id='breadcrumb']/span/a[4]/@href").to_s[1..-1]
    user = doc.xpath("//div[@id='documentDisplay']//div[@class='boxHeader']/span/a/@href").to_s[1..-1]
    author = doc.xpath("//div[@id='documentDisplay']//div[@class='boxHeader']/span/a/text()").to_s.gsub(' ', '-').downcase.gsub('š', 's')
    dir_id = doc.xpath("//a[@id='browseDir']/@href").to_s.split('=')[1]
    has_posts = !doc.xpath("//div[@class='title']").empty?

    if(has_posts && !name.nil? && !name.empty? && !author.nil? && !author.empty?)
      redirects.write "# #{name}\n"
      redirects.write "RewriteRule ^#{blogger_name}$ /#{author}/ [R=301,L,E=nocache:1]\n"
      redirects.write "RewriteRule ^#{home}$ /#{author}/ [R=301,L,E=nocache:1]\n"
      redirects.write "RewriteRule ^#{home}/Page/.*$ /#{author}/ [R=301,L,E=nocache:1]\n"

      redirects.write "RewriteCond %{REQUEST_URI} ^/dirDisplay_d\.seam$\n"
      redirects.write "RewriteCond %{QUERY_STRING} ^directoryId=#{dir_id}$\n"
      redirects.write "RewriteRule ^(.*)$ /#{author}/? [R=301,L,E=nocache:1]\n"

      if(!user.nil? && !user.empty?)
        redirects.write "RewriteRule ^#{user}$ /#{author}/ [R=301,L,E=nocache:1]\n"
      end

      redirects.write "RewriteRule ^service/Feed/atom/Area/Bloggers/Node/#{name.gsub(' ', '')}(/Comments/.*)? #{@feed_url} [R=301,L,E=nocache:1]\n"
      redirects.write "\n"
    end
  end
end

importer = Importer.new(Choice.choices.pstore, Choice.choices.outfile)
importer.process_bloggers
