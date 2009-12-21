#!/usr/bin/perl

=head1 NAME

deleteRows.pl - Emulate cli db tool, dbtool.pl with DB schema

=head1 SYNOPSIS

script_files/deleteRows.pl Player player =~/eq/ne/gt ^19300
Columns:        league  exercise        player  question        answer  correct
=============================================
Deleting        dic     crocodile1      193001  3       Don't know      0

=head1 DESCRIPTION

Deletes all rows from the table associated with the ARGV[0] schema for which sub { ARGV[0] ARGV[2] ARGV[3] } returns true. Now using DBIC::Row's delete. Before was NOT using DBIC::ResultSet's delete_all, because play needs to be kept even after players are gone. Players will come back.

=head1 AUTHOR

Dr Bean C<drbean @ an at sign cpan, dot, a dot, org>

=head1 COPYRIGHT


This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use lib 'lib';

use Config::General;

my @MyAppConf = glob( '*.conf' );
die "Which of @MyAppConf is the configuration file?"
			unless @MyAppConf == 1;
my %config = Config::General->new($MyAppConf[0])->getall;
my $name = $config{name};
require $name . ".pm";
my $model = "${name}::Schema";
my $modelfile = "$name/Model/DB.pm";
my $modelmodule = "${name}::Model::DB";
# require $modelfile;

my $connect_info = $modelmodule->config->{connect_info};
my $d = $model->connect( @$connect_info );
my $s = $d->resultset(shift @ARGV);
my @columns = $s->result_source->columns;
$, = "\t";
print "Columns: ", @columns,
	"\n=============================================\n";
my $callback = callback( @ARGV );
while ( my $r = $s->next )
{
	my %values = map { $_ => $r->get_column($_) } @columns;
	if ( $callback->( %values ) )
	{
		$r->delete;
		print "Deleting";
		print "\t" . $values{$_} for @columns;
		print "\n";
	}
}

sub callback {
	my @token = @_;
	my $regex = qr/$token[2]/;
	my %callbacks = (
		'=~' => sub { my %r=@_; return ( $r{$token[0]} =~ $regex ) },
		'eq' => sub { my %r=@_; return ( $r{$token[0]} eq $token[2] ) },
		'ne' => sub { my %r=@_; return ( $r{$token[0]} ne $token[2] ) },
		'gt' => sub { my %r=@_; return ( $r{$token[0]} gt $token[2] ) },
		);
	return $callbacks{$token[1]};
}
