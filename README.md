##Google Groups Scraper

This started with [mfortini](https://github.com/mfortini) as a fork of [google_group.to_discourse](https://github.com/pacharanero/google_group.to_discourse) during our hacking sessions at [Masters of Networks 3](wikitalia.github.io/MoN3), modified to simply dump the topics to json files.

Migrating away from a private Google Group is not easy. It would seem to be made deliberately so by Google.

1. there is no API
2. there is no API
3. the entire content is rendered in-browser from JS so HTML requesting tools such as the Ruby Mechanize gem don't work (you can log in but you can't see any content)
4. the HTML tags are (it seems deliberately) obfuscated - they are meaningless in English so it's hard to work out what CSS selectors to go for when scraping the page
5. I'm told there are Captchas if you go over a certain rate limit for page requests (although I didn't encounter this problem)


##Scraper Tool google_group_dump.rb
google_group_dump.rb uses Ruby Selenium to automate a Firefox browser which navigates to the Google Group, logs in, and scrapes all the topics from the front page. It then iterates through these to collect all the data from each Topic into a hash, which it then uses to save a json.

## Dependencies
* Firefox
* Selenium

##How To Use
1. Set up a user for the Google Group you want to scrape and obtain login credentials for that user.
1. edit env.sh.template to contain the correct credentials for the above user, and the classes of the elements to scrape (you can try with the ones here which are working at the time I'm writing this):

```bash
export GOOGLE_USER=""               # Google Group username 
export GOOGLE_PASSWORD=""           # Google Group user's password

export SENDER_CLASS="G3J0AAD-E-a"   # class of the HTML element that contains the sender
export DATE_CLASS="G3J0AAD-mb-Q"    # class of the HTML element that contains the date
export BODY_CLASS="G3J0AAD-mb-P"    # class of the HTML element that contains the body of the message
```
1. Rename the file env.sh (or whatever_you_like.sh)
1. Open a terminal (oh yeah, if you're on Windows, er... sorry?)
1. run `$ source env.sh`
1. run irb
```
irb 001 > load './google_group_dump.rb'
irb 002 > group_url = "https://groups.google.com/forum/#!forum/..."
irb 003 > messages = {}
irb 004 > topics = []
irb 005 > topics, messages = GoogleGroupDump.scrape_all(group_url,topics,messages)
irb 005 > GoogleGroupDump.save_all(topics, messages)
```
1. A Selenium browser window (Firefox) will appear, and it should navigate to the login page of your Google Group, enter your credentials, and login.
1. The program will ask you to scroll down the page in the Selenium browser until you reach the bottom. This is to ensure that all topics are scraped. It's very hacky but so far the only reliable way (see Known Issues)
1. You will get a list of every topic in your Google Group scrolling in the terminal
1. It will then start iterating through these and loading the messages
1. If you have problems at any stage look in the 'Known Issues' section to see if it is a new problem or one we know about, and maybe find a solution
1. Reinstate normal rate limits on Discourse
1. consider thanking the [original author](https://github.com/pacharanero/google_group.to_discourse)

Look at the `example.rb` file for more examples (e.g. how to handle the errors and retry)

##Known Issues/Imperfections
1. And most glaring during scraping - I still haven't worked out a way to scroll to the bottom of the Google Group page in Selenium - various approaches were tried but since the links below the bottom of the page don't actually *exist* (aren't yet rendered) until you scroll down, you can't reference them in Selenium in order to make it scroll down. And there don't seem to be any direct controls for scrolling.
1. `Selenium::WebDriver::Error::StaleElementReferenceError: Element is no longer attached to the DOM` - sometimes, for reasons not clear to me, the DOM either changes or something happens to Selenium's binding of DOM to Ruby Object, and it can't find stuff. Retrying, starting from that Topic seems to work, presumably the DOM is in some way refreshed. Only way to make it happen a lot less was to add a largish (15 sec) wait time after navigating to the page. On my roadmap is to trap this error and auto-retry with a backoff and limit.

##New issues and contributions
Please log issues in GitHub. Pull requests are welcome.

##Roadmap
* command line usage
* scrape a Range of topics (eg from topic 11..45)
* trap 'Selenium - Element is no longer attached to the DOM' error and auto-retry with backoff and limit
