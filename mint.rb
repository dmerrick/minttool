#!/usr/bin/env ruby
#require 'digest'
require 'optparse'

# handle the require gem nicely
begin
  require 'rubygems'
  require 'www/mechanize'
rescue LoadError
  puts "Error loading Mechanize. Run 'gem install mechanize' first."
end

class MintCheck
  # maybe uncomment this for exploring the code
  #attr_reader :agent

  # set up option parser
  def self.parse(args)
    options = Hash.new
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #$0 [options]"

      opts.on("-n", "--number NUM",
              "Return NUM of recent transactions") do |n|
        options[:num] = n.to_i - 1
      end

      opts.on("-u", "--user USER",
              "Use USER as account name") do |u|
        options[:user] = u
      end
  
      opts.on("-p", "--password PASS",
              "Use PASS as account password") do |p|
        options[:pass] = p
      end
    end
    opts.parse!
    return options
  end

  def initialize(options)
    @options = options
    
    p options if $DEBUG

    # hpricot buffer increase
    Hpricot.buffer_size = 262144

    # create the mechanize agent and set it up
    @agent = WWW::Mechanize.new
    @agent.user_agent_alias = 'Mac Safari'
  end # initialize
  
  def log_in()
    # log in
    begin
      page = @agent.get('https://wwws.mint.com/login.event')
      form = page.forms.first
      form['username'] = @options[:user] || "YOUR EMAIL"
      form['password'] = @options[:pass] || "YOUR ROT13 PASSWORD".tr("A-Za-z0-9","N-ZA-Mn-za-m5-90-4")
      return @agent.submit(form, form.buttons.first)
    rescue
      # we want to re-raise this error so subclasses can catch it.
      raise if self.class != "MintCheck"
      STDERR.print "Unable to log in. Check your connection?\n"
      exit 3
    end
  end # log_in
  
  def balance(page)
    # print available balance
    begin
     return page.search("//span[@class='balance']").last.inner_html
    rescue
     STDERR.print "Login error. Please try again!\n"
    end
  end # balance
  
  def with_transactions?
    return @options[:num]
  end
  
  def transactions(page)
    transactions = Array.new
    link = page.links.href(/transaction.event/)
    page = @agent.click(link)
    page.search("//td").each do |row|
      if row.attributes['title'] =~ /^Statement Name: /
        # the inner html has more than what we're looking for
        transaction = row.inner_html.sub(/<.*\n.*/,"")
        transactions << transaction
      end
    end
    return transactions[0..@options[:num]||2]
  end # transactions
end # MintCheck

if $0 == __FILE__
  options = MintCheck.parse(ARGV)
  mint = MintCheck.new(options)
  current_page = mint.log_in
  puts mint.balance(current_page)
  puts mint.transactions(current_page) if mint.with_transactions? #options[:num]
end
