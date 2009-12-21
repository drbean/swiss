package Swiss::Model::GTS;

# Last Edit: 2009  8月 27, 11時20分28秒
# $Id$

use strict;
use warnings;
use parent 'Catalyst::Model';

use CGI::Simple::Util qw/escape unescape/;
use List::MoreUtils qw/any all notall/;

=head1 NAME

Swiss::Model::GTS - Games::Tournament::Swiss Catalyst Swiss App Model backend

=head1 DESCRIPTION

Catalyst Model.

=cut

use Games::Tournament::Swiss::Config;

my $swiss = Games::Tournament::Swiss::Config->new;

my $roles = [qw/White Black/];
my $abbrev = { W => 'White', B => 'Black', 1 => 'Win', 0 => 'Loss',
	0.5 => 'Draw', '=' => 'Draw'  };
my $scoring = { win => 1, loss => 0, draw => 0.5, forfeit => 0, bye => 1 };
my $firstround = 1;
my $algorithm = 'Games::Tournament::Swiss::Procedure::FIDE';

$swiss->frisk($scoring, $roles, $firstround, $algorithm, $abbrev);

$Games::Tournament::Swiss::Config::firstround = $firstround;
%Games::Tournament::Swiss::Config::scores = %$scoring;
%Games::Tournament::Swiss::Config::abbreviation = %$abbrev;
@Games::Tournament::Swiss::Config::roles = @$roles;
$Games::Tournament::Swiss::Config::algorithm = $algorithm;

require Games::Tournament::Swiss;
require Games::Tournament::Contestant::Swiss;

=head2 roles

Roles

=cut

sub roles { return \@Games::Tournament::Swiss::Config::roles; }


=head2 setupTournament

Passing round a tournament, with players, is easier.

=cut

sub setupTournament {
	my ($self, $args) = @_;
	my $players = $args->{entrants};
	my @entrants = map { Games::Tournament::Contestant::Swiss->new(%$_) }
			@$players;
	$args->{entrants} = \@entrants;
	my $tournament = Games::Tournament::Swiss->new( %$args );
	$tournament->assignPairingNumbers;
	return $tournament;
}


=head2 turnIntoCookies

Prepare cookies for a tournament's players with ids, names, ratings, and perhaps later, preference histories, float histories, and scores. The cookie name for the player ids is 'tournament_ids' (where 'tournament' is the name of the tournament) and the values are a list of the players ids. The tournament name is to distinguish different tournaments being paired from the same browser.

=cut

sub turnIntoCookies {
	my ($self, $tourname, $playerlist) = @_;
	my %cookie;
	for my $key ( qw/id name rating firstround/ ) {
		my @keylist = map { $_->{$key} } @$playerlist;
		my $keystring = join "&", map { escape( $_ ) } @keylist;
		$cookie{$tourname . '_' . $key . 's'} = $keystring;
	}
	return %cookie;
}


=head2 makeCookies

Prepare cookies for a tournament's players accessors. The cookie name for the player fields is 'tournament_fields' (where 'tournament' is the name of the tournament and 'field' is 'opponents', etc) and the values are a list of the players ids. The tournament name is to distinguish different tournaments being paired from the same browser.

=cut

sub makeCookies {
	my ($self, $tournament, $playerlist, $fields, $hash) = @_;
	my %cookie;
	for my $key ( @$fields ) {
		my @keylist = map { $_->{$key} } @$playerlist;
		my $keystring = join "&", map { escape( $_ ) } @keylist;
		$cookie{$tournament . '_' . $key . 's'} = $keystring;
	}
	return %cookie;
}


=head2 historyCookies

Prepare cookies for a tournament's players opponent, preference and float histories, and scores. The cookie name for the player fields is 'tournament_fields' (where 'tournament' is the name of the tournament and 'field' is 'opponents', etc) and the values are listed by player id, in the same order as in 'tournament_ids'.
	# my %cookies = $self->makeCookies( $tourney, $players, $keys, $history);
2,-,     1,-,
2%2C-%2C 1%2C-%2C
2%2C-%2C&1%2C-%2C
2%252C-%252C%261%252C-%252C

3,1 4,2 1,3 2,4
3%2C1&4%2C2&1%2C3&2%2C4
3%252C1%264%252C2%261%252C3%262%252C4

2,3,,-, 1,4,,-, -,1,,-, -,2,,-,
2%2C3%2C%2C-%2C%261%2C4%2C%2C-%2C%26-%2C1%2C%2C-%2C%26-%2C2%2C%2C-%2C

=cut

sub historyCookies {
	my ($self, $tourney, $history) = @_;
	my %cookie;
	my $players = $tourney->entrants;
	my $tourname = $tourney->{name};
	my $types = [ qw/pairingnumber opponent role float score/ ];
	my @ids = map { $_->{id} } @$players;
	for my $type ( @$types ) {
		my %expando = reverse %$abbrev if $type eq 'roles';
		my $historicaltype = $history->{$type};
		my @historicalvalues;
		my @typeids = keys %$historicaltype;
		die "Not all players, @ids have a $type history in $tourname Tourney"
			unless all { my $id=$_; any {$_ eq $id} @typeids } @ids;
		for my $id ( @ids ) {
			my $values = $historicaltype->{$id};
			my $string;
			if ( $type eq 'opponent') {
				$string = join ',', @$values if defined $values
					and ref $values eq 'ARRAY';
			}
			elsif ( $type eq 'role' or $type eq 'float' ) {
				$string = join '', map { defined $_ and
					$_ eq 'Bye'? '-' : substr $_, 0, 1}
						@$values if defined $values and
							ref $values eq 'ARRAY';
			}
			elsif( $type eq 'score' ) { $string = $values || 0 }
			elsif( $type eq 'pairingnumber' ) {
				my $player = $tourney->ided($id);
				$string = $player->pairingNumber;
			}
			push @historicalvalues, $string;
		}
		$cookie{"${tourname}_${type}s"} = join '&', @historicalvalues;
	}
	return %cookie;
}


=head2 turnIntoPlayers

Inflate a tournament's players' cookies with ids, names, ratings, and perhaps later, preference histories, float histories, and scores and return as an array of hashes for each individual player.

=cut

sub turnIntoPlayers {
	my ($self, $tourney, $cookies) = @_;
	my @playerlist;
	my $fields = [ qw/id name rating firstround/ ];
	return $self->breakCookie($tourney, $cookies, $fields);
}


=head2 breakCookie

Decode the cookie into an array of hashes representing the values (as array refs) for each of the fields of a list of players.

=cut

sub breakCookie {
	my ($self, $tourney, $cookies, $fields) = @_;
	my @playerlist;
	my @cookieNames = map { "${tourney}_${_}s" } @$fields;
	for my $name ( @cookieNames ) {
		next unless exists $cookies->{$name};
		my $playercookie = $cookies->{$name};
		next unless $playercookie and
				$playercookie->isa('CGI::Simple::Cookie');
		(my $fieldname = $name ) =~ s/^${tourney}_(.*)s$/$1/;
		my $playerstring = $playercookie->value;
		my @values = $self->destringCookie( $playerstring );
		for my $n ( 0 .. @values-1 ) {
			$playerlist[$n]->{$fieldname} = $values[$n];
		}
	}
	return @playerlist;
}


=head2 stringifyCookie

The value of a CGI::Simple::Cookie, a string, can represent an array or a hash of strings. Join the array/hash of strings into a string suitable as a cookie value after encoding/escaping the strings. I don't know why CGI::Simple::Cookie isn't doing this for me.

=cut

sub stringifyCookie {
	my ($self, @values) = @_;
	my $value = join '&', map { escape($_) } @values;
	return $value;
}


=head2 destringCookie

The value of a CGI::Simple::Cookie, a string, can represent an array or a hash of strings. Split the cookie into an array/hash of strings and decode the (escaped) strings. I don't know why CGI::Simple::Cookie isn't doing this for me.

=cut

sub destringCookie {
	my ($self, $string) = @_;
	my @values = map { unescape( $_ ) } split /[&;]/, $string;
	return @values;
}


=head2 readHistory

Inflate a tournament's players' opponent, role and float history and score (and pairing number) cookies, and return arrays of these 5 items over the rounds of the tournament indexed by player id. For example, represented as a YAML structure:

	pairingnumber:
	  1: 3
	  2: 4
	  3: 1
	  6: 2
	opponent:
	  1: [6 4 2 5] 
	  2: [7 3 1 4] 
	  3: [8 2 6 7] 
	  6: [1 5 3 9]
	role:
	  1: [qw/White Black White Black/] 
	  2: [qw/Black White Black White/] 
	  3: [qw/White Black White Black/] 
	  6: [qw/Black White Black White/] 
	float:
	  1: ['Up' 'Down'] 
	  2: [undef 'Down'] 
	  3: ['Down' undef] 
	  6: [undef undef] 
	score:
	  1: 3.5 
	  2: 3.5 
	  3: 2.5 
	  6: 2.5 
	
=cut

sub readHistory {
	my ($self, $tourname, $playerlist, $cookies, $round) = @_;
	my %histories;
	my $fields = [ qw/pairingnumber opponent role float score/ ];
	my @playerData = $self->breakCookie($tourname, $cookies, $fields);
	my $n=0;
	for my $player ( @playerData ) {
		my $id = $playerlist->[$n]->{id};
		for my $field ( qw/opponent role float/ ) {
			my $values = $playerData[$n]->{$field};
			my @values = split //, $values;
			@values = split /,/, $values if $field eq 'opponent';
			@values = map { $abbrev->{$_} || $_ } split //, $values
				if $field eq 'role';
			for my $rounds ( 0 .. $round-1 ) {
				# $histories{$field}->[$n]= \@values;
				$histories{$field}->{$id}->[$rounds] =
					$values[$rounds];
			}
		}
		for my $rounds ( 0 .. $round-1 ) {
			if ( $histories{role}->{$id}->[$rounds] eq '-'
				and $histories{opponent}->{$id}->[$rounds] eq
				'Bye') {
				$histories{role}->{$id}->[$rounds] = 'Bye';
			}
		}
		$histories{score}->{$id} = $playerData[$n]->{score};
		$histories{pairingnumber}->{$id} =
			$playerData[$n]->{pairingnumber};
		$n++;
	}
	return %histories;
}


=head2 parsePlayers

Parse the line of ids, names and ratings (AND firstround) into a list of hashes. Any extra fields, 1..n-3 are joined together to make one name. Long IDs, names and ratings are chomped to 7, 20 and 4 characters, respectively.

=cut

sub parsePlayers {
	my ($self, $tourney, $records) = @_;
	my @playerlist;
	my @records = split /\n/, $records;
	for my $line ( @records ) {
		next if $line =~ m/^$/;
		my %player;
		chomp $line;
		my @fields = split ' ', $line;
		my $n;
		if ( $n = @fields and $n > 4 ) {
			my $name = join ' ', @fields[1..$n-3];
			splice @fields, 1, $n-3, $name;
		}
		@player{qw/id name rating firstround/} = @fields;
		$player{id} = substr $player{id}, 0, 7;
		$player{name} = substr $player{name}, 0, 20;
		$player{rating} = substr $player{rating}, 0, 4;
		push @playerlist, \%player;
	}
	return @playerlist;
}


=head2 parseTable

Parse the textarea pairing table and return it in the same format as readHistory above. As a convenience, add pairing number information from the entrants to allow writing this directly back to historyCookies, in the absence of history changes.

=cut

sub parseTable {
	my ($self, $tourney, $table) = @_;
	my %pairingtable;
	my @records = split /\n/, $table;
	for my $line ( @records ) {
		next if $line =~ m/^$/;
		next if $line =~ m/^id \s+ opponents/xi;
		my %player;
		chomp $line;
		my @fields = split ' ', $line;
		die "No spaces allowed between opponents, and between roles. Format is: '2016192 4100026,2805687 BW uD 2'" if @fields <= 3 or @fields > 5;
		if ( @fields == 4 ) {
			$fields[4] = $fields[3];
			$fields[3] = '';
		}
		@player{qw/id opponent role float score/} = @fields;
		my $id = $player{id};
		my @opponents = split ',', $player{opponent};
		$player{opponent} = \@opponents;
		my @roles = map { $abbrev->{$_} || $_ } split //, $player{role};
		$player{role} = \@roles;
		my $float = $player{float};
		my @floats = map {	$float =~ m/$_->[0]/? 'Up':
					$float =~ m/$_->[1]/? 'Down':
					'Not' } (['u', 'd'],['U', 'D']);
		$player{float} = \@floats;
		$pairingtable{$_}->{$id} = $player{$_} for
					qw/opponent role float score/;
		my $entrant = $tourney->ided( $id );
		$pairingtable{pairingnumber}->{$id} = $entrant->pairingNumber;
	}
	return %pairingtable;
}


=head2 assignScores

Get results for the last round from the user and compute latest scores, using  history up until the last round.

=cut

sub assignScores {
	my ($self, $tourney, $history, $params) = @_;
	my @ids = map { $_->id } @{ $tourney->entrants };
	my ($scores, %results);
	PARAM: for my $param ( keys %$params ) {
		my ( $firstroleplayer, $secondroleplayer);
		{
			next PARAM unless $param =~ m/^(.*)_:_(.*)$/;
			$firstroleplayer = $1;
			$secondroleplayer = $2;
		}
		die
	"Either $firstroleplayer or $secondroleplayer not an entrant" unless
				any { $_ eq $firstroleplayer } @ids and
				any { $_ eq $secondroleplayer } @ids, 'Bye';
		$params->{$param} =~ m/^(.*):(.*)$/;
		my $firstresult = $1;
		my $secondresult = $2;
		$results{$firstroleplayer} = $firstresult;
		$results{$secondroleplayer} = $secondresult;
	}
	for my $id ( @ids ) {
		my $result = $results{$id};
		my ($score, $total);
		$score = $scoring->{$result} if defined $result;
		$total = $history->{score}->{$id} + $score if defined $score;
		$history->{score}->{$id} = $total if defined $total;
		$scores->{$id} = $total if defined $total;
	}
	return $scores;
}


=head2 pair

Pair players for the next round of a swiss tournament

=cut

sub pair {
	my ($self, $args) = @_;
	my $tourney = $args->{tournament};
	my $round = $tourney->round;
	my $rounds = $tourney->rounds;
	my $entrants = $tourney->entrants;
	$tourney->idNameCheck;
	my $pairingtable = $args->{history};
	if ( $pairingtable ) {
		my $scores = $pairingtable->{score};
        for my $player ( @$entrants ) {
                my $id = $player->id;
                $player->score( $scores->{$id} );
        }
		my $lastround = $round;
		for my $round ( 1..$lastround ) {
			my $games = $self->postPlayPaperwork(
				$tourney, $pairingtable, $round);
			$tourney->collectCards( @$games );
		}
	}
	$tourney->loggedProcedures('ASSIGNPAIRINGNUMBERS');
	$tourney->assignPairingNumbers;
	$tourney->initializePreferences if $round == 0;
	my $log;
	my %logged = $tourney->catLog;
	$log .= $logged{ASSIGNPAIRINGNUMBERS};
	my %brackets = $tourney->formBrackets;
	my $pairing = $tourney->pairing( \%brackets );
	my $message = $pairing->message;
	$pairing->round(++$round);
	$pairing->loggingAll;
	my $results = $pairing->matchPlayers;
	$log .= $pairing->{logreport};
	my $matches = $results->{matches};
	my @games;
	my %number = map { $_ => $brackets{$_}->number } keys %brackets;
	for my $bracket ( sort { $number{$a} cmp $number{$b} } keys %$matches )
	{
	    my $bracketmatches = $matches->{$bracket};
	    push @games, grep { ref eq 'Games::Tournament::Card' }
		@$bracketmatches;
	}
	my @tables = $tourney->publishCards(@games);
	return ($message, $log, \@tables);
}


=head2 postPlayPaperwork

The details of who played who, what roles they took and their floats in some round, taken from a pairing table found somewhere and recreated into game cards for crunching by the pairing procedure.

=cut

sub postPlayPaperwork {
	my ($self, $tourney, $pairingtable, $round) = @_;
	my $lastround = $tourney->round;
	my @ids = map { $_->id } @{ $tourney->entrants };
	my ( $opponents, $roles, $floats, $score ) =
		@$pairingtable{qw/opponent role float score/};
	my %opponents = map { $_ => $opponents->{$_}->[$round-1] } @ids;
	my %roles = map { $_ => $roles->{$_}->[$round-1] } @ids;
	my %floats = map { $_ => $floats->{$_}->[$round-$lastround-1] } @ids;
	my @games = $tourney->recreateCards( {
		round => $round, opponents => \%opponents,
		roles => \%roles, floats => \%floats } );
	return \@games;
}


=head2 changeHistory

Update the opponent, preference and float data for the round. A lot of this stuff is 'View', eg abbreviations and player score being '-' or 0.

=cut

sub changeHistory {
	my ($self, $tourney, $history, $games) = @_;
	$tourney->collectCards( @$games );
	my $round = $tourney->round;
	my $players = $tourney->entrants;
	for my $player ( @$players ) {
		my $id = $player->id;
		my $game = $tourney->myCard(round => $round, player => $id);
		if ( defined $game ) {
			my $opponent = $player->myOpponent($game)
			|| Games::Tournament::Contestant->new(
				name => "Bye", id => "Bye" );
			my $opponents = $history->{opponent}->{$id};
			push @$opponents, $opponent->id;
			$history->{opponent}->{$id} = $opponents;
			my $role = $game->myRole($player);
			if ( $role eq 'Bye' ) { $role = '-'; }
			else                  { $role =~ s/^(.).*$/$1/; }
			my $roles = $history->{role}->{$id};
			push @$roles, $role;
			$history->{role}->{$id} = $roles;
		}
		else {
			push @{ $history->{opponent}->{$id} }, "-,";
			push @{ $history->{role}->{$id} }, "-";
		}
		my $floats = $player->floats;
		my $float = '';
		$float = 'd' if $floats->[-2] and $floats->[-2] eq 'Down';
		$float = 'u' if $floats->[-2] and $floats->[-2] eq 'Up';
		$float = 'n' if $floats->[-2] and $floats->[-2] eq 'Not';
		$float .= 'D' if $floats->[-1] and $floats->[-1] eq 'Down';
		$float .= 'U' if $floats->[-1] and $floats->[-1] eq 'Up';
		$float .= 'N' if $floats->[-1] and $floats->[-1] eq 'Not';
		$history->{float}->{$id} = $floats;
		$history->{score}->{$id} = $player->score;
		$history->{pairingnumber}->{$id} = $player->pairingNumber ||
									'-';
	}
	return $history;
}


=head2 allFieldCheck

Does the same thing as idCheck in Games::Tournament but returns an error message instead of dying.

=cut

sub allFieldCheck {
	my ($self, @playerlist) = @_;
	my $message;
	for my $player ( @playerlist ) {
		if ( notall { $player->{$_} } qw/id name rating/ ) {
			$message ||=
			"Each entrant must have an id, name and rating. ";
			$message .=
"Player $player->{name}, id: $player->{id}, missing id, name or rating. ";
		}
	}
	return $message;
}


=head2 idDupe

Does the same thing as idCheck in Games::Tournament but returns an error message instead of dying.

=cut

sub idDupe {
	my ($self, @playerlist) = @_;
	my %idcheck;
	for my $player ( @playerlist ) {
		my $id = $player->{id};
		my $name = $player->{name};
		if ( defined $idcheck{$id} ) {
		    return $name . " and $idcheck{$id} have the same id: $id";
	}
	$idcheck{$id} = $name;
	}
	return;
}


__END__

=head1 SYNOPSIS

pair

=head1 OPTIONS

=over 8

=item B<--man> A man page

=item B<--help> This help message

=back

=head1 DESCRIPTION

=over 8

=item B<SCRIPTS>

The scripts in script_files/ need to be installed somewhere so that they can be run in the directory in which pairing of each round is done.

=item B<DIRECTORY LAYOUT>

The scripts assume that there is a directory in which a configuration file, called league.yaml, with data about the players exists. The rounds are paired in subdirectories, named 1,2,3,.. in this directory. A file called pairtable.yaml in the subdirectory allows pairing of the round to take place. This file can be created from a pairing table, eg pairing.txt, by running B<pairtable2yaml pairing.txt>

=item B<DATA FILES>

Do B<NOT> use tabs in these YAML files. The level of indentation is significant. Follow the examples closely. The first, league.yaml has lines of the form:

member:
  - id: 1
    name: Laver, Rod
    rating: 2810
    title: Grandmaster
  - id: 2
    name: Sampras, Pete
    rating: 2800
    title: Unknown
  - id: 3
    name: McEnroe, John
    rating: 2780
    title: Unknown

Late entries are separate.

If you are using your own scoring scheme, and colors (called, roles), see the example in t/tennis in the distribution. You can add your own data to the member and late records. A pairing number is generated for the players, so don't include a pairing number. The new id (ie pairing number) is added to league.yaml. This is a bit tricky. I am working with names here (eg with the absentees and the pairings left in round.yaml). TODO Configuration of your own scoring scheme looks like it is broken.

B<pairtable.yaml> is of the form:

---
opponents:
 1 : [6,4,2,5]
 2 : [7,3,1,4]
 6 : [1,5,3,9]
roles:
 1 : [White,Black,White,Black]
 2 : [White,Black,White,Black]
 6 : [White,Black,White,Black]
floats:
 1 : [Up,Down]
 2 : [~,Down]
 6 : [~,~]
score:
 1: 3.5
 2: 3.5
 6: 2.5

Or its equivalent. As for league.yaml, indentation (no tabs) is important.

=item B<GENERATING PAIRINGS>

Starting with an empty main directory, create league.yaml, and an empty subdirectory for the first round. Run the script, 'pair' in the empty round subdirectory. A log of the pairing is printed and 'round.yaml' in the directory contains the matches. A number of other yaml files are created to store state for the round. (These will probably go away in a later version of this script).

After the games in the round are complete, create a pairing table for the next round. (Perhaps you can use B<pairingtable>. This currently uses the yaml serialization files in the round subdirectory and score files in the scores subdirectory. Enter the scores for the players in the file, '1.yaml', or whatever the round is. A template file is generated in the round subdirectory. Then you can run 'crosstable' or 'pairingtable' in the original directory above the subdirectory, to get current standings.) If there is a next round, make another empty subdirectory named after it, put pairtable.yaml (created by hand or by B<pairtable2yaml>) in it and continue as before. You add late-entering players in league.yaml in the main directory.

=back

=cut

# vim: set ts=8 sts=4 sw=4 noet:
=head1 AUTHOR

A clever guy

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
