# NAME

Log::Log4perl::KISS - Human-friendly logging functions out-of-the-box. Just use it!  

# SYNOPSIS

    use Log::Log4perl::KISS;

    # ! Only if you DONT want to use Log::Log4perl->init(...) explicitly
    log_open('/var/log/application/logfile'); 	# To write to the file instead of a screen 
						# Please read carefully further notes about "HELPER FUNCTIONS"
    # ! Only if you DONT want to use Log::Log4perl->init(...) explicitly
    log_level('INFO');				# Default log-level is "DEBUG"
    
    # Log4perl will be initialised on first call to any of the logger functions if you havent do this yourself earlier
    debug {'Just a %s on the ' . ($_[0] ? 'bus' : 'train') . ' trying to make his way %s', 'stranger'} [1], 'home';
    
    info {'Cept for the %s maybe in %s'}, qw/Pope Rome/;
    
    warn {'Cept for the %s maybe in %s', @_ }, [qw/Pope Rome/];
    
    error_ 'Nothing Is Infinite';
    
    debug_ 'So please stop explaining. %s', q{Don't tell me 'cause it hurts};
    
    debug_ qw/any key be no key/;
    
    # references auto-stringifcation
    info_ 'Main cities in the USA: %s. Last 4 USA presidents: %s', 
    	{"The Capital" => "Washington", "Califronia's main city" => "Los Angeles"},
	[qw/Clinton Bush Obama Tramp/];
	
    
    # = Brief after-hooks overview =
    my $hook_id = after_error_hook_add sub { 
      $redis->publish( 'some_channel' => ${$_[0]} );
      say STDERR ">>>> ${$_[0]} <<<<";
    };
    
    # This message will be logged, published to Redis, printed to STDERR with say
    error_ 'Some error';
    
    # Imagine, that now after-hook is no longer needed: deactivate it!
    after_error_hook_del $hook_id;
    
    # Hook were deactivated, so the message will be logged only
    error_ 'Some other error'; 

# DESCRIPTION

**Log::Log4perl::KISS** is a tiny (<200 rows of code) wrapper for [Log::Log4perl](http://search.cpan.org/perldoc/Log::Log4perl) provides simple,
but very powerful logging functions such as debug, trace, info, fatal, logdie,
which format your message or doing nothing but not both.

It is... just simplest than [EASY](http://search.cpan.org/~mschilli/Log-Log4perl-1.49/lib/Log/Log4perl.pm#Stealth_loggers)!

## WHY

* Performance: Using code block as a first argument garantie that your output string will be computed only if target log level is enabled
* Clean syntax: `debug {'Now i want to say "Good bye" for the summer'}` and `debug_ 'You were just a prototype'` - looks clear and obvious
* Lightweight and fast by design: this is Log::Log4perl wrapper only, not yet-another-logging framework. This is a very compact package that help you work with the best perl logging framework in a comfort manner.
* Absolute minimum of initialisation: `use Log::Log4perl::KISS` is enough to output clever-formatted messages. No bull shit! Write faster code, that can log more
* Rich functional possibilities: you can do it so:
  * `debug {'Something %s %s'} "very", "useful"`
  or so:
  * `warn {"Are you $_[0] how %s songs?"} ["hear"], "blackbird"`
  or just so:
  * `info_ "I have located the %s myself", "barrel of Ambrosia"`.
  * Simply `error_ 'Something awful','goes','wrong'` works well too :)
* References and objects auto-stringification: you dont have to worry about what you pass to the logging function: reasonable solution to render your value as some string will be applied in all cases;
* You can set and unset hooks to be fired after write to log. Hooks will receive reference to a message, which was logged (only message, without Log4perl layout formatting and headers)

# HELPER FUNCTIONS

You can use special helper functions log_open to set target log file instead of stderr and log_level - to set desired log level
But remember that this functions is a simply wrappers around Log::Log4perl initialisation in case you didnt initialise it before 
first call of any of the log-writers (debug_, info_, trace_, etc...)

So you can use it only before any log output and only if you didnt initialise Log4perl properly by yourself.

In other words, log_open and log_level is a helpers for simplifying initial Log4perl configuration - do not expect that log_open() 
can be used to switch log file "on the fly" or log_level() - to change log level at run time. It is not intended to do so, this is
only a "sugar" for VERY lazy people. Like me, for example :)

# LICENSE

Copyright (C) Andrey A. Konovalov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Andrey A. Konovalov <drvtiny@gmail.com>
