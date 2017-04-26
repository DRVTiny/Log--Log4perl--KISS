package Log4perl::KISS;
use 5.16.1;
use strict;
use warnings;
use utf8;
binmode $_, ':utf8' for *STDOUT, *STDERR;
use Exporter qw(import);

use Log::Log4perl;
use Log::Log4perl::Level;

my @logSevs;
BEGIN {
    eval 'sub '.join('; sub ',map $_.'_', @logSevs=qw/trace debug info warn error fatal/);
}

our @EXPORT=our @EXPORT_OK=('set_logger', map { $_.'_', $_ } 'log', @logSevs);
Log::Log4perl->wrapper_register(__PACKAGE__);

my %logSev2N;
{
    no strict 'refs';
    %logSev2N=map {my $U=uc($_); $_=>$$U } @logSevs;
}
use Data::Dumper;
my %pkgLoggers;
sub log_ {
    state $dfltL4PConf=\<<'EOLOGCONF';
log4perl.rootLogger     =       DEBUG, Screen

log4perl.appender.Screen = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.stderr = 1
log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = %d{HH:mm:ss} | %d{dd.MM.yyyy} | %P | %p | %m%n
EOLOGCONF
    return unless my $logger=$pkgLoggers{scalar caller(1)}||=(Log::Log4perl->initialized() || Log::Log4perl->init($dfltL4PConf)) && Log::Log4perl->get_logger();

    return unless my $logSev=shift;
    return unless my $logSevN=$logSev2N{$logSev=lc $logSev};
    return 1 if $logSevN<$logger->level;
    my ($firstMsg,$nShift)=ref($_[0]) eq 'CODE'
        ? (join(' '=>$_[0]->(ref($_[1]) eq 'ARRAY'?@{$_[1]}:())), 1+(ref $_[1] eq 'ARRAY'))
        : ($_[0],1);
    splice(@_,0,$nShift);
    $logger->log($logSevN => 
        @_ 
            ? $firstMsg=~/(?<!%)%[sdfg]/
                ? sprintf($firstMsg, @_)
                : join(' ' => $firstMsg, @_)
            : $firstMsg
    );
}

{    
    no strict 'refs';
    for (@logSevs) {
        *{__PACKAGE__.'::'.$_.'_'}=eval sprintf('sub { log_(q{%s}, @_) }', $_);
        *{__PACKAGE__.'::'.$_}=eval sprintf('sub (&@) { log_(q{%s}, @_) }', $_);
    }
}

sub set_logger {
    my $L=shift;
    return $L
        ? (($L and ref($L) and blessed($L) and !(grep !$L->can($_), qw/debug info warn error fatal logdie/)) && ($pkgLoggers{scalar caller}=$L))
        : ($pkgLoggers{scalar caller}=Log::Log4perl::initialized()?Log::Log4perl->get_logger():undef)
}

1;
