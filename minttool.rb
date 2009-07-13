#!/usr/bin/env ruby -KU

# There was an awful lot of debugging this script, so it's messy as hell.
# Which is really a pity, because I thought the idea was pretty elegant.

require 'mint'

begin
  require 'rubygems'
  require 'meow'
rescue LoadError
  puts "Error loading Meow. Run 'gem install meow' for Growl notifications."
end

# The whole purpose of this class is to add value saving functionality to
# my MintCheck tool.
class MintTool < MintCheck
  @@file = File.expand_path("~/.balance")
  attr_reader :file
  
  # set up option parser
  def self.parse(args)
    options = Hash.new
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #$0 [options]"

      opts.on("-u", "--user USER",
              "Use USER as account name") do |u|
        options[:user] = u
      end
  
      opts.on("-p", "--password PASS",
              "Use PASS as account password") do |p|
        options[:pass] = p
      end
      
      opts.on("-f","--force",
              "Force write to file") do |force|
        options[:force] = force
      end
      
      # TODO:
      # Something with the filename here?
    end
    opts.parse!
    return options
  end
  
  def self.go(args)
    @options = MintTool.parse(args)
    mint = MintTool.new(@options)

    # here we catch the exception raised by MintCheck
    # TODO: Create my own exception?
    begin
      current_page = mint.log_in
    rescue
      STDERR.print "caught exception; reading...\n" if $DEBUG
      puts mint.file_contents
      return 1
    end
    
    file = File.new( @@file, File::CREAT | File::RDONLY )
    
    if file.old_enough? || File.size(@@file).zero? || @options[:force]
      STDERR.print "saving...\n" if $DEBUG
      
      new_balance = mint.balance(current_page)
      old_balance = mint.file_contents.chomp || ''
      
      mint.save(new_balance)
      puts mint.file_contents
       
      # set up message details for growl
      if new_balance != old_balance
        title   = "Mint.com Updated"
        # TODO: Test me!
        details = "New balance is: #{new_balance} (#{new_balance - old_balance})"
      else
        title   = "Mint.com Refreshed"
        details = "Click here for more info."
      end
      
      meep = Meow.new('#$0')
      meep.notify(title, details) do
        # this loop makes the script run for a little longer than usual
        # because it waits for the growl window to close
        url = 'https://wwws.mint.com/summary.event'
        `/usr/bin/open #{url}`
      end # meep block
    else
      STDERR.print "reading...\n" if $DEBUG
      puts mint.file_contents
    end
  end
  
  def save(balance,filename = nil)
    filename ||= @@file
    file = File.open(filename,"w") do |f|
      f.puts balance
    end
    # chmod -rw-------
    File.chmod(0600,filename)    
  end
  
  def file_contents(filename = nil)
    filename ||= @@file
    begin
      content = File.open(filename).readline
    rescue
      STDERR.print "caught exception; content = ''\n" if $DEBUG
      content = ''
    end
    puts "File read passed:" if $DEBUG
    return content
  end
  
end

class Integer
  def minutes
    self*60
  end
  def hours
    self.minutes*60
  end
end

class String
  # to allow string subtractions like: "$1,000"-"$5" #=> "$995"
  def -(other)
    self.gsub!(/[$,]/,'')
    other.gsub!(/[$,]/,'')
    value = self.to_i - other.to_i
    sign  = value < 0 ? "down $" : "up $"
    # FIXME: This doesn't work for values >$999,999. (ha!)
    value = sign + value.abs.to_s.sub(/(\d)(\d\d\d)$/,'\1,\2')
    return value
  end
end

class File
  def old_enough?
    # This probably shouldn't live here, but oh well.
    return true if File.zero? self
    diff = Time.now - self.mtime
    STDERR.print diff.to_s + "\n" if $DEBUG
    return diff > 6.hours
  end
end

if $0 == __FILE__
  MintTool.go(ARGV)
end
