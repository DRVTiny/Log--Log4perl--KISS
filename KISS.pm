package Log4perl::KISS;
use 5.16.1;
use strict;
use warnings;
use utf8;
use constant DONE => 1;
binmode $_, ':utf8' for *STDOUT, *STDERR;
use Exporter qw(import);

use Log::Log4perl;
use Log::Log4perl::Level;
use Scalar::Util qw(refaddr weaken);
use Carp qw(confess);

my @logSevs = qw/trace debug info warn error fatal/;
my %logMethodDefs = (
    'logdie'=>[undef,sub { confess($_[1]) }, $FATAL]
);
my @logMethods = keys %logMethodDefs;
my %logSev2N = do {
    no strict 'refs';
    map {my $U=uc($_); ($_=>$$U, uc($_)=>$$U) } @logSevs;
};

our @EXPORT = our @EXPORT_OK = (
    qw/log_open log_level/,
    map { 
        my $sev = $_;
        (
            $sev . '_',
            $sev,
            map sprintf('after_%s_hook_%s', $sev, $_), qw/add del/
        )
    } @logSevs, @logMethods);

Log::Log4perl->wrapper_register(__PACKAGE__);
my %fileOpenModes = (
    '>' => 'clobber',
    '>>' => 'append',
    'write' => 'clobber',
    '|-' => 'pipe',
    'append' => 'append',
    'clobber' => 'clobber',
    'pipe' => 'pipe'
);

my $useAppender = 'Screen';
my $layPattern = q(%d{HH:mm:ss} | %d{dd.MM.yyyy} | %P | %p | %m%n);
my $layPackage ='Log::Log4perl::Layout::PatternLayout';
my $logLevel   = 'DEBUG';
my %L4PAppenders=(
    'Screen' => {
        'stderr' 		=> 1,
        'layout'                => $layPackage,
        'layout.ConversionPattern' => $layPattern
    },
    'File' => {
        'filename' 		=> undef,
        'mode'			=> undef,
        'layout'		=> $layPackage,
        'layout.ConversionPattern' => $layPattern,
        'recreate'		=> 1,
        'recreate_check_signal' => 'XFSZ',
        'utf8'			=> 1
    },
);

sub log_open {
    my ($mode, $filePath)=
        (@_==2) ? @_ : (@_==1) ? ('append', $_[0]) : confess 'Wrong number of arguments';
    confess 'Invalid log open mode specified: '.$mode if $mode and !($mode=$fileOpenModes{lc $mode});
    @{$L4PAppenders{$useAppender='File'}}{qw/filename mode/}=($filePath,$mode)
}

sub log_level {
    confess 'Unknown log level specified' unless !ref($_[0]) and $_[0] and exists $logSev2N{lc $_[0]};
    $logLevel=uc($_[0])
}

my %afterLogHooks;
{
    no strict 'refs';
    for my $sev ( @logSevs, @logMethods ) {
        *{__PACKAGE__ . '::after_' . $sev . '_hook_add'} = sub {
            my $handler = $_[0];
            my $p_handler = refaddr($handler);
            $afterLogHooks{$sev}{'cb'}{$p_handler} or weaken(
                $afterLogHooks{$sev}{'ord'}[$#{$afterLogHooks{$sev}{'ord'}} + 1] = 
                \($afterLogHooks{$sev}{'cb'}{$p_handler} = $handler)
            );
            return $p_handler
        };
        *{__PACKAGE__ . '::after_' . $sev . '_hook_del'} = sub {
            return unless exists $afterLogHooks{$sev}{'cb'}{$_[0]};
            delete $afterLogHooks{$sev}{'cb'}{$_[0]};
            @{$afterLogHooks{$sev}{'ord'}} = grep defined($_), @{$afterLogHooks{$sev}{'ord'}};
            return DONE
        };
    }
}

sub getL4PConfig {
    my ($appndrType, $appndrConfig)=@_;
    my $ptrn="log4perl.appender.${appndrType}";
    my $l4pConf=join("\n" =>
        "log4perl.rootLogger=${logLevel},${appndrType}"	,
        "${ptrn}=Log::Log4perl::Appender::${appndrType}",
        map sprintf("${ptrn}.%s=%s", each $appndrConfig->{$appndrType}),
                1..keys($appndrConfig->{$appndrType})
    );
    return \$l4pConf
}        

my %pkgLoggers;
sub log_ {
    return unless my $logSev=shift;
    my $logger=$pkgLoggers{scalar caller(1)}||=(
                Log::Log4perl->initialized() 
                 || Log::Log4perl->init(getL4PConfig($useAppender, \%L4PAppenders))
               ) && Log::Log4perl->get_logger() 
                     or return;
    my ($doBeforeLog,$doAfterLog);
    my $logSevN = $logSev2N{$logSev = lc $logSev} 
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
    my $ret = $logger->log($logSevN => $logMsg);
    if ( exists $afterLogHooks{$logSev}{'ord'} ) {
        ${$_}->(\$logMsg) for @{$afterLogHooks{$logSev}{'ord'}}
    }
    return $doAfterLog ? $doAfterLog->($ret, $logMsg) : $ret;
}

{    
    no strict 'refs';
    for (@logSevs,@logMethods) {
        my $methodFQName = __PACKAGE__ . '::' . $_;
        *{$methodFQName . '_'} 	= eval sprintf('sub      { log_( q{%s}, @_ ) }', $_);
        *{$methodFQName} 	= eval sprintf('sub (&@) { log_( q{%s}, @_ ) }', $_);
    }
}

sub set_logger {
    my $L = shift;
    return $L
        ? (($L and ref($L) and blessed($L) and !(grep !$L->can($_), qw/debug info warn error fatal logdie/)) && ($pkgLoggers{scalar caller}=$L))
        : ($pkgLoggers{scalar caller}=Log::Log4perl::initialized()?Log::Log4perl->get_logger():undef)
}

1;
