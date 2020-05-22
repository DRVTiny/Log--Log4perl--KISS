package Log::Log4perl::KISS;
use constant LOG_SEVERITIES => qw/trace debug info warn error fatal/;
use constant DONE => 1;
use constant NIL  => '<Nil>';
use constant TRUE=> 1;
use constant FALSE=> ! TRUE;

use 5.16.1;
use strict;
use warnings;
use utf8;
use JSON;
use Ref::Util qw(is_ref is_plain_coderef is_plain_scalarref is_plain_arrayref is_plain_coderef is_plain_hashref is_plain_refref);
use Data::Dumper qw(Dumper);
use Scalar::Util qw(refaddr weaken);
use Carp qw(confess);
use Exporter qw(import);
use Log::Log4perl qw(:no_extra_logdie_message);
use Log::Log4perl::Level;
use Log::Log4perl::Layout;

use subs qw(log_);
my (@logSevs, %logMethodDefs, @logMethods, %logSev2N);
BEGIN {
    binmode $_, ':utf8' for *STDOUT, *STDERR;


    @logSevs = LOG_SEVERITIES;
    %logMethodDefs = (
        'logdie' => [undef, sub { confess($_[1]) }, $FATAL]
    );
    @logMethods = keys %logMethodDefs;

    no strict 'refs';
    %logSev2N = map { my $U = uc($_); ($_ => $$U, uc($_) => $$U) } @logSevs;

    for (@logSevs, @logMethods) {
        my $methodFQName = __PACKAGE__ . '::' . $_;
        *{$methodFQName . '_'} = eval sprintf('sub      { log_( q{%s}, @_ ) }', $_);
        *{$methodFQName} = eval sprintf('sub (&@) { log_( q{%s}, @_ ) }', $_);
    }
}

our @EXPORT = our @EXPORT_OK = (
    (map 'log_' . $_, qw/open hook level/),
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
    '>'         => 'clobber',
    '>>'        => 'append',
    'write'     => 'clobber',
    '|-'        => 'pipe',
    'append'    => 'append',
    'clobber'   => 'clobber',
    'pipe'      => 'pipe'
);

my $useAppender = 'Screen';
my $layPattern = q(%d{HH:mm:ss.SSS} | %d{dd.MM.yyyy} | euid=%U pid=%P | %p | %m%n);
my $layPackage = 'Log::Log4perl::Layout::PatternLayout';
Log::Log4perl::Layout::PatternLayout::add_global_cspec('U', sub { getlogin || scalar(getpwuid $<) });
my $logLevel   = 'DEBUG';
my %L4PAppenders = (
    'default' => {
        'layout'                => $layPackage,
        'layout.ConversionPattern'  => $layPattern
    },
    'Screen' => {
        'stderr'=> 1,
    },
    'File' => {
        'filename'=> undef,
        'mode'=> undef,
        'autoflush'     => 1,
        'recreate'=> 1,
        'recreate_check_signal' => 'XFSZ',
        'utf8'=> 1
    },
);

sub log_hook {
    my $coderef = $_[0];
    $L4PAppenders{$useAppender ='Sub'}{'code'} = (
        is_plain_coderef($coderef) and $coderef
or
        !ref($coderef) and $coderef and $coderef =~ /^sub\s+\{.+\}\s*$/ and eval($coderef)
                or die 'log_hook first parameter must be coderef or correct subroutine definition text'
    )
}

sub log_open {
    my ($mode, $filePath)=
    (@_ == 2)
        ? @_
        : (@_ == 1)
            ? ('append', $_[0])
            : confess 'Wrong number of arguments';
    defined($mode) and $mode = $fileOpenModes{lc $mode}
        or confess "Invalid log open mode specified: $mode";
    @{$L4PAppenders{$useAppender = 'File'}}{qw/filename mode/} = ($filePath, $mode)
}

sub log_level {
    confess 'Unknown log level specified' unless !ref($_[0]) and $_[0] and exists $logSev2N{lc $_[0]};
    $logLevel = uc($_[0])
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

sub l4p_config {
    my ($apndrType, $apndrConfigs) = @_;
    my %apndrConfig = (
        %{$apndrConfigs->{'default'}},
        %{$apndrConfigs->{$apndrType}},
    );
    my ($layPackage, $layPattern) = delete @apndrConfig{qw/layout layout.ConversionPattern/};
    my $layout = $layPackage->new($layPattern);
    my $apndr = Log::Log4perl::Appender->new(
        'Log::Log4perl::Appender::' . $apndrType,
        %apndrConfig
    );
    $apndr->layout($layout);
    my $logger = Log::Log4perl->get_logger();
    $logger->add_appender($apndr);
    $logger->level($logLevel);
    $logger
}

sub pkg_logger {
    state $pkgLoggers = +{};
    my ($pkg_name, $logger_def, $fl_reset_if_defined) = @_;
    ($#_ > 0 && (! $pkgLoggers->{$pkg_name} || $fl_reset_if_defined))
        ? ( $pkgLoggers->{$pkg_name} = ( is_plain_coderef($logger_def) and &{$logger_def} or defined($logger_def) and $logger_def or l4p_config($useAppender, \%L4PAppenders) ) )
        : $pkgLoggers->{$pkg_name}
}

sub log_ {
    state $pkgLoggers = +{};
    return unless my $logSev = shift;
    my $opts =
        (is_plain_refref($_[$#_]) && is_plain_hashref(${$_[$#_]}) and ${+pop(@_)} or undef);
    my $logger = pkg_logger(scalar caller(1), undef) or return;
    my ($doBeforeLog, $doAfterLog);
    my $logSevN = $logSev2N{$logSev = lc $logSev}
                 || ($logMethodDefs{$logSev}
                     ? do { ($doBeforeLog,$doAfterLog,$_)=@{$logMethodDefs{$logSev}}; $_ }
                     : undef)
                         or return;

    return DONE if $logSevN < $logger->level;

    if ( is_plain_coderef($_[0]) ) {
        my $arg1_is_arr = is_plain_arrayref($_[1]) ? 1 : 0;
        splice(  @_,  0,  1 + $arg1_is_arr,  $_[0]->($arg1_is_arr ? @{$_[1]} : ()) );
    }

    push @_, \[] if $opts and $opts->{'inline_structs'};

    my $logMsg =
        $#_
            ? ( !ref($_[0]) and defined($_[0]) and $_[0] =~ /(?<!%)%\d*[.-]?\d*[sdfgo]/ )
                ? do {
                    my $pattern = shift;
                    sprintf($pattern => &stringify_list_elems)
                  }
                : join(' '=> &stringify_list_elems)
            : (&stringify_list_elems)[0];

    $doBeforeLog and $doBeforeLog->($logMsg);

    my $ret = $logger->log($logSevN => $logMsg);

    if ( exists $afterLogHooks{$logSev}{'ord'} ) {
        ${$_}->(\$logMsg) for @{$afterLogHooks{$logSev}{'ord'}}
    }

    return $doAfterLog ? $doAfterLog->($ret, $logMsg) : $ret;
}

sub stringify_list_elems {
    state $json = JSON->new;
    $json->pretty($#_ > 0 && is_plain_refref($_[$#_]) ? do { pop @_; FALSE } : TRUE);
    map
        is_ref($_)
            ? is_plain_scalarref($_)
                ? ${$_}
                : ( is_plain_arrayref($_) or is_plain_hashref($_) )
                    ? $json->encode($_)
                    : Dumper($_)
            : defined($_)
                ? $_
                : NIL,
        @_
}

sub set_logger {
    my $L = shift;
    return $L
        ? ( (blessed($L) and !(grep !$L->can($_), LOG_SEVERITIES(), 'logdie')) and pkg_logger(scalar caller, $L) )
        : pkg_logger(scalar caller, undef, 1)
}

1;
