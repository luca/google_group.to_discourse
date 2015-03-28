require 'selenium-webdriver'
require 'mail'
require 'nokogiri'
require 'cgi'
require 'json'


class GoogleGroupDump
  attr_reader :driver
  attr_reader :topics
  attr_reader :messages
  attr_reader :google_group_url
  
  # set up variables from the env file
  def initialize(group_url)
    
    # set the local variables for the scraping
    @sender_class = ENV['SENDER_CLASS']||'G3J0AAD-E-a'
    @date_class = ENV['DATE_CLASS']||'G3J0AAD-mb-Q'
    @body_class = ENV['BODY_CLASS']||'G3J0AAD-mb-P'
    
    # set local variables to environment variables
  	@username = ENV['GOOGLE_USER']||''
  	@password = ENV['GOOGLE_PASSWORD']||''
  	@google_group_url = group_url      

    # initialize a driver to look up DOM information and another for scraping raw email information
  	@driver = Selenium::WebDriver.for(:firefox)
    goto_group(@driver)
    login(@driver) if @username!='' && @password!=''
    
  end
  
  def goto_group(driver)
    puts "[#{Time.now}] I'm loading #{@google_group_url}. Wait and be patient\n\n"
    driver.navigate.to(@google_group_url)
    sleep(15)
  end

  # log in to google group
  def login(driver)
    # find the right elements
    username_field = driver.find_element(:id, 'Email')
    password_field = driver.find_element(:id, 'Passwd')
    signin_button = driver.find_element(:id, 'signIn')

    puts "[#{Time.now}] Now I'm logging in with the username #{@username} and the password.\n\n"
    # fill in credentials
    username_field.send_keys(@username)
    password_field.send_keys(@password)
    signin_button.click
  end

  def get_topics
    @topics = []
    # scroll to the bottom of google group (to force Groups to load - and therefore render - all the threads)
    puts "[#{Time.now}] Scroll down MANUALLY to the bottom of the Selenium window. Press Enter when ready"
    x = gets
    # user scrolls down MANUALLY then get topics
    
    puts "[#{Time.now}] Scraping topics index"
    # get all the links (which includes all the topics but also other stuff)
    topics = @driver.find_elements(:tag_name, 'a')

    # We only want the links that include "#!topic/"
    topics.each do |topic|
      if !topic.nil? and !topic.attribute(:href).nil? and topic.attribute(:href).include? "#!topic/" # it is a topic.
        puts "[#{Time.now}] topic: \"#{(topic.text||'')[0..30]}...\""
        thread_id = topic.attribute(:href).split("/").last #Format: "https://groups.google.com/forum/#!topic/ccio/g9qK6Zefb3w" 
        topic = { title: topic.text, url: topic.attribute(:href), thread_id: thread_id }           
        @topics << topic                    
      end
    end

    puts "[#{Time.now}] #{@topics.count} topics in this Google Group\n\n"  
    return @topics
  end

  def get_messages(topic, driver)
    topic[:messages] =[] # messages will be appended to this as an array of hashes
    driver.navigate.to(topic[:url])
    sleep (15) #wait for it to load
    
    # expand all the message_snippets
    minimized_messages = driver.find_elements(:xpath, "//span[contains(@id, 'message_snippet_')]")
    minimized_messages.each { |link| link.click; sleep (2)}
    sleep(15)
    
    # get all messages
    all_messages = driver.find_elements(:xpath, "//div[contains(@id, 'b_action_')]")
    puts "[#{Time.now}] #{all_messages.count} messages in this thread"
    
    # iterate through messages
    sender = driver.find_elements(:class, @sender_class)
    date = driver.find_elements(:class, @date_class)
    body = driver.find_elements(:class, @body_class).reject!{ |c| c.text=="" } #reject blank ones
    if sender.size > 0
      all_messages.each_with_index do |message, index|
             topic[:messages] << { 
               sender: (sender[index].attribute(:"data-name")||sender[index].text rescue nil), 
               date: (date[index].attribute(:title) rescue  nil), 
               body: (body[index].text rescue nil) 
             }
      end      
    else
      puts "[#{Time.now}] ATTENTION: no elements found for the message, check the page sources, maybe the HTML changed"
      topic[:error] = "Impossible to scrape"
    end
    return topic
  end


  class<< self
    
    def scrape_and_save(group_url)
      topics, messages = scrape_all(group_url)
      save_all(topics, messages)
    end
    
    def scrape_all(group_url, topics=[], messages={}, retry_only_errors=false)
      scraper = new(group_url)
      topics = scraper.get_topics if !topics || topics.empty?
      topics.reverse_each do |topic|
        if retry_only_errors && topic[:error].nil?
          puts "[#{Time.now}] skipping #{topic[:url]}"
          next
        end
        
        begin
          topic.delete(:error)
          messages[topic[:url]] = scraper.get_messages(topic, scraper.driver)
        rescue Exception=>exc
          puts "[#{Time.now}] Error scraping #{topic[:url]} #{exc.to_s}"
          topic[:error] = exc.message
          scraper = new(group_url)
        end
      end
      puts "[#{Time.now}] All topics scraped"
      scraper.driver.close
      return [topics, messages]
    rescue Exception=>exc
      puts "[#{Time.now}] Error scraping... #{exc.to_s}"
      return [topics, messages]
    end
    
    def save_all(topics, messages)
      Dir.mkdir("topics") unless Dir.exist?("topics")
      
      File.open("./topics/index.json", "w") do |f|
        f.write(topics.to_json)
      end
      topics.each_with_index do |topic, topic_number|
        if topic_messages = messages[topic[:url]]
          topic_json = topic_messages.to_json
          File.open("./topics/topic#{topic[:thread_id]}.json", "w") do |f|
            f.write(topic_json)
          end
        end
      end
      puts "[#{Time.now}] All topics saved to ./topics/ directory in JSON format" 
    end
    
    def load_topics_index(file)
      topics = JSON.parse(File.read(file))
      topics.inject({}){|memo, (k,v)| memo[k.to_sym] = v; memo}
    end
  end

end #class

