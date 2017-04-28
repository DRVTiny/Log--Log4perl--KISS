# NAME

Log4perl::KISS - Human-friendly logging functions out-of-the-box. Just use it!  

# SYNOPSIS

    use Log4perl::KISS;
    debug {'Just a %s on the '.($_[0]?'bus':'train').' trying make his way %s...', 'stranger'} [1], 'home';
    info {'Cept for the %s maybe in %s'}, qw/Pope Rome/;
    warn {'Cept for the %s maybe in %s', @_ }, [qw/Pope Rome/];
    error_ 'Nothing Is Infinite';
    debug_ 'So please stop explaining. %s', q{Don't tell me 'cause it hurts};
    debug_ qw/any key be no key/;

# DESCRIPTION

Log4perl::KISS is a tiny (<100 rows of code) wrapper for Log::Log4perl provides simple,
but very powerful logging functions such as debug, trace, info, fatal, logdie,
which format your message or doing nothing but not both.

It is... just simplest than EASY!

## WHY

* Performance: Using code block as a first argument garantie that your output string will be computed only if target log level is enabled
* Clean syntax: `debug {'Now i want to say "Good bye" for the summer'}` and `debug_ 'You were just a prototype'` - looks clear and obvious
* Lightweight and fast by design: this is Log::Log4perl wrapper only, not yet-another-logging framework. 89 lines of code that help you work with the best perl logging framework in a comfort manner.
* Absolute minimum of initialisation: `use Log4perl::KISS` is enough to output clever-formatted messages. No bull shit! Write faster code, that can log more
* Rich functional possibilities: you can do it so:
  *`debug {'Something %s %s'} "very", "useful"`
  or so:
  * `warn {"Are you $_[0] how %s songs?"} ["hear"], "blackbird"`
  or just so:
  * `info_ "I have located the %s myself", "barrel of Ambrosia"`.
  * Simply `error_ 'Something awful','goes','wrong'` works well too :)

# LICENSE

Copyright (C) Andrey A. Konovalov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Andrey A. Konovalov <drvtiny@gmail.com>
