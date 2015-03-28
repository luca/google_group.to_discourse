require './google_group_dump.rb'

# this is the URL gor the google group to scrape
group_url = "https://groups.google.com/forum/#!forum/..."

# To save a group, first you scrape it
messages = {}
topics = []
topics, messages = GoogleGroupDump.scrape_all(group_url,topics,messages)

# then you save all topics as json
GoogleGroupDump.save_all(topics, messages)

# if some topic has had errors you can select them and retry
topics_with_errors = topics.select{|t| !t[:error].nil? }

# to retry only those with errors
topics, messages = GoogleGroupDump.scrape_all(group_url,topics,messages,true)

# to reload the topics index file
topics = GoogleGroupDump.load_topics_index('./topics/index.json')
