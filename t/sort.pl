#perl

use strict;
use warnings;

# my @words = qw(1.5 1.5Remainder 1 1Remainder 1Bye);
my @words = qw(A B C D);

# my @ongoingperms = ( ['A'] );
my @ongoingperms;
foreach my $n ( 0 .. $#words )
{
	# my @ongoingperms ||= ();
	my @perms;
	do
	{
		my $perm = shift @ongoingperms;
		my @perm = @ongoingperms? @$perm: ();
		my $last = @perm? $#perm: 0;
		foreach my $pos ( 0 .. $last )
		{
			my @forextended;
			@forextended[0..$pos-1] = @perm[0..$pos-1];
			$forextended[$pos] = $words[$n];
			foreach my $other ( $pos+1 .. $#perm )
			{
				last unless defined $perm[$other];
				$forextended[$other+1] = $perm[$other];
			}
			push @perms, \@forextended;
			my @aftextended;
			@aftextended[0..$pos] = @perm[0..$pos];
			$aftextended[$pos+1] = $words[$n];
			foreach my $other ( $pos+1 .. $#perm )
			{
				last unless defined $perm[$other];
				$aftextended[$other+1] = $perm[$other];
			}
			push @perms, \@aftextended;
		}
	} while @ongoingperms;
	# print @$_ , "\t" for @perms;
	@ongoingperms = @perms;
	# print "\n";
}
print @$_ , "\t" for @ongoingperms;
