[![Build Status](https://travis-ci.org/hatorikibble/twitter-europeanabot.svg?branch=master)](https://travis-ci.org/hatorikibble/twitter-europeanabot)

twitter-europeanabot
====================

the aim of this twitter bot is to explore the diverse contents of [Europeana](http://www.europeana.eu).

The programm takes a list of "seed terms" from a file, searches for corresponding images and posts the URL of the first result to the Twitter-Account [*EuropeanaBot*](http://www.twitter.com/EuropeanaBot).

In the current implementation I used [Austrian place names] (http://www.statistik.at/web_de/klassifikationen/regionale_gliederungen/gemeinden/index.html) and a list of [Nobel Prize winners](http://console.apihq.com/nobel-prize-api).

What's New?
===========

Please refer to the [CHANGES](CHANGES.md) file

How To Deploy
=============

1) get API keys
---------------

you'll need an [Europeana API-key](http://www.europeana.eu/portal/api/registration.html) and [Twitter OAuth credentials](https://dev.twitter.com/docs/auth/oauth/faq).

2) get seed file
----------------

I used a list of Austrian place names which I got from [Statistik Austria] (http://www.statistik.at/web_de/klassifikationen/regionale_gliederungen/gemeinden/index.html) as a seed file for location searches.
A CSV file with all Nobel Prize winners was found at [http://console.apihq.com/nobel-prize-api](http://console.apihq.com/nobel-prize-api).

3) edit config files
--------------------

Rename `logging.conf_example` to `logging.conf` and edit if necessary. Rename èuropeana.json_example' to 'europeana.json' and edit the parameters.

* *pidbase*
    location of PID-file, should be user-writable

* *debug*
    if set to *1*, all messages are only written into the logfile and not
    posted on twitter, default is *0*
    
* *europeana_api_key*
    see step 1

* *twitter_**
    see step 1

* *url_shortener*
   generally the result urls are too long, here you can user also any other service

* *location_file*
    list of possible location search terms in a csv file. If you use a different source file, you may have to adjust the subroutine `createSeed` in `EuropeanaBot.pm`

* *nobel_file*
    CSV file with a list of Nobel Prize winners

* *user_agent*
    the Wikipedia API requires setting a user agent for requests
    
* *wikipedia_base*
    which Wikipedia version to use, defaults to `http://en.wikipedia.org`

* *sleep_time*
    interval between searches

* *sleep_time_margin*
    add a little random variation, to maybe fool Twitters bot detection
	algorithm ;-)

More Information
==================

* Inspiration: [DPLABot] (https://twitter.com/DPLAbot)

Talks
-----

* June 2014: 103. Deutscher Bibliothekartag: [*"Lasst digitale Sammlungen sprechen!" - TwitterBots, Tumblr und die Rückkehr des Serendipitätsprinzips*](http://www.opus-bayern.de/bib-info/volltexte/2014/1552/)
* June 2014: ELAG 2014: [*EuropeanaBot – using open data and open APIs to present digital collections*](http://elag2014.org/programme/elag-workshops-list-page/12-6/) ([Slides](http://www.slideshare.net/hatorikibble/elag-mayr-europeanabot1), [Video](https://www.youtube.com/watch?v=l_i-_2YEpT0))

Blog posts
-----------

* [Blogpost in German] (https://hatorikibble.wordpress.com/2013/07/19/ich-hab-da-mal-einen-osterreichischen-europeana-bot-geschrieben/)
* [Blogpost in German about Version 1.1] (http://hatorikibble.wordpress.com/2013/07/22/der-europeanabot-mag-jetzt-auch-katzen/)
* [Blogpost in German about Version 1.2] (http://hatorikibble.wordpress.com/2013/08/01/jede-menge-nobelpreise-fur-den-europeanabot/)
* [Blogpost in German about Version 1.3] (http://hatorikibble.wordpress.com/2013/08/12/passen-gut-zusammen-europeanabot-und-wikipedia/)
* [Blogpost in German about Version 1.4] (http://hatorikibble.wordpress.com/2013/09/16/der-europeanabot-liest-jetzt-auch-den-guardian/)
* [Blogpost in German about Version 1.5] (https://hatorikibble.wordpress.com/2013/11/03/der-europeanabot-schaut-zuruck/)
* [Blogpost in German about Version 1.6] (https://hatorikibble.wordpress.com/2014/02/08/der-europeanabot-lernt-vokabeln/)
* [Blogpost in German about Version 1.7] (https://hatorikibble.wordpress.com/2014/03/20/der-europeanabot-jetzt-noch-europaischer/)
* [Blogpost in German about Version 1.8] (https://hatorikibble.wordpress.com/2014/06/22/den-europeanabot-zum-fusballschauen-geschickt/)

