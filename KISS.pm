package Log4perl::KISS;
use 5.16.1;
use strict;
use warnings;
use utf8;
binmode $_, ':utf8' for *STDOUT, *STDERR;
use Exporter qw(import);

use Log::Log4perl;
use Log::Log4perl::Level;
use Carp qw(confess);

my @logSevs=qw/trace debug info warn error fatal/;
my %logMethodDefs=(
    'logdie'=>[undef,sub { confess($_[1]) }, $FATAL]
);
my @logMethods=keys %logMethodDefs;
my %logSev2N=do {
    no strict 'refs';
    map {my $U=uc($_); $_=>$$U } @logSevs;
};

our @EXPORT=our @EXPORT_OK=(map { $_.'_', $_ } @logSevs, @logMethods);

Log::Log4perl->wrapper_register(__PACKAGE__);

my %pkgLoggers;
sub log_ {
    state $dfltL4PConf=\<<'EOLOGCONF';
log4perl.rootLogger     =       DEBUG, Screen

log4perl.appender.Screen = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.stderr = 1
log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = %d{HH:mm:ss} | %d{dd.MM.yyyy} | %P | %p | %m%n
EOLOGCONF
    return unless my $logSev=shift;
    my $logger=$pkgLoggers{scalar caller(1)}||=(
                Log::Log4perl->initialized() 
                 || Log::Log4perl->init($dfltL4PConf)
               ) && Log::Log4perl->get_logger() 
                     or return;
    my ($doBeforeLog,$doAfterLog);
    my $logSevN=$logSev2N{$logSev=lc $logSev} 
                 || ($logMethodDefs{$logSev}
                     ? do { ($doBeforeLog,$doAfterLog,$_)=@{$logMethodDefs{$logSev}}; $_ }
                     : undef) 
                         or return;
                         
    return 1 if $logSevN<$logger->level;
    
    splice(  @_,  0,  1+(ref $_[1] eq 'ARRAY'),  $_[0]->(ref $_[1] eq 'ARRAY'?@{$_[1]}:())  )
        if ref $_[0] eq 'CODE';
        
    my $logMsg=$#_
                ? $_[0]=~/(?<!%)%[sdfg]/
                    ? sprintf($_[0] => @_[1..$#_])
                    : join(' ' => @_)
                : $_[0];
    $doBeforeLog and $doBeforeLog->($logMsg);
    my $ret=$logger->log($logSevN => 
        $#_
            ? $_[0]=~/(?<!%)%[sdfg]/
                ? sprintf($_[0] => @_[1..$#_])
                : join(' ' => @_)
            : $_[0]
    );
    return $doAfterLog?$doAfterLog->($ret,$logMsg):$ret;
}

{    
    no strict 'refs';
    for (@logSevs,@logMethods) {
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
