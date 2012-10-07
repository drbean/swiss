#!/usr/bin/perl

## TODO: Sicherheitschecks, damit Skript nicht in endloser Schleife landet?
## TODO: Sicherheitschecks, damit Skript nicht endlos in 'tmpfile' loggt!
## TODO: I have to add some code to prevent that the list of players
##       couldn't be changed (perhaps accidentally) once the tournament is
##       started. An exception would be to remove a player from the
##       tournament.
## TODO: Paarungen fuer Runden aufheben
## TODO: Paarungen manuell aendern
## TODO: Sicherheitschecks beim Lesen und Schreiben der Datei
## TODO: Doppelten Code mit select_tournament.pl abgleichen 
##       eventuell in ein Skript integrieren?
## TODO: complete and structure perldoc
## TODO: Disable CGI::Carp for productive use.
## TODO: PBP anwenden
##       * 3 argument form of open()
## TODO: kampflose Punkte! (Gewinner und Verlierer)

use strict;
use warnings;

## TODO: PBP anwenden: Versionsnummerierung
my $VERSION = '0.0.10';

## adjust this settings for your site

## CGI script resides here
my $CGIDIR = '/home/greg/bin/pairing';
# my $CGIDIR = '/home/pacs/mih01/users/cb02/doms/aglaz.de/cgi/swiss-pairing';

## directory for tournaments
my $TOURNAMENTBASEDIR = '/home/greg/public_html/pairing/';
# my $TOURNAMENTBASEDIR = '/home/pacs/mih01/users/cb02/doms/aglaz.de/subs/www/swiss-pairing/tournaments';

## perl modules in non-standard places
# use lib qw(/home/pacs/mih01/users/cb02/lib);

## we use the following modules 

## the script is based on CGI.pm
use CGI qw(:standard *table *Tr *th *td);
## TODO: disable this for productive use
use CGI::Carp qw(fatalsToBrowser); 
## i18n, 'perldoc Locale::Maketext::Simple'
use Locale::Maketext::Simple (   
    Path => './language_files',
    Style => 'gettext'
);

## the following is related to Games::Tournament::Swiss
use Games::Tournament::Swiss::Config;

## we need this to load Games::Tournament::Swiss
my $roles = [qw/Black White/];
my $scores = { win => 1, loss => 0, draw => 0.5, absent => 0, bye => 1 };
my $algorithm = 'Games::Tournament::Swiss::Procedure::FIDE';
@Games::Tournament::Swiss::Config::roles = @$roles;
%Games::Tournament::Swiss::Config::scores = %$scores;
$Games::Tournament::Swiss::Config::algorithm = $algorithm;

require Games::Tournament::Contestant::Swiss;
require Games::Tournament::Swiss;

## TODO: PBP -- constants?
my $DATAFILE = 'tournament_data';        ## contains tournament data
my $CGISCRIPT = 'tournament.pl';         ## CGI script to manage tournament
my $CGISELECT = 'select_tournament.pl';  ## CGI script to select tournaments

my @LANGUAGES = qw(en de);              ## defined languages

my $q = new CGI;      ## new CGI object

my $language = set_language();
my $action = get_action();

## some other variables
my $lineup;     ## list of all players
my $member;     ## index variable for several players within YAML data
my $round;
my %Black;
my %ResBlack;
my %White;
my %ResWhite;
my $board;
my @Bye;
my @scores;

my $t_dir = get_tournament_dir();
my $TOURNAMENTDIR = "$TOURNAMENTBASEDIR/$t_dir";

my ($t_name, $rounds, $status) =  get_tournament_data();

my @all_players = read_players_from_data_file();

## print HTML headers
print $q->header;            

## manage participants
if ($action eq 'manage_participants') { 
    print $q->start_html( -title => loc("(Participants)") ), "\n",
          $q->h1( loc("(Manage participants for tournament %1)", $t_name) ),
          "\n", $q->hr, "\n";
    show_page_for_managing_participants();
} 
## add participants
elsif ($action eq 'add_participant') {
    print $q->start_html( -title => loc("(Participants)") ), "\n",
          $q->h1( loc("(Manage participants for tournament %1)", $t_name) ),
          "\n", $q->hr, "\n";
    add_participant(@all_players);
    show_page_for_managing_participants();
} 
## delete participants
elsif ($action eq 'delete_participant') {
    print $q->start_html( -title => loc("(Participants)") ), "\n",
          $q->h1( loc("(Manage participants for tournament %1)", $t_name) ),
          "\n", $q->hr, "\n";
    delete_participant(@all_players);
    show_page_for_managing_participants();
} 
## we've got new results
elsif ($action eq 'new_results') {
    print $q->start_html( -title => loc( "(Pairings and Results)" ) ), "\n",
          $q->h1( loc( "(Pairings and Results)" ) ), "\n";
    $round = get_round_number();
    read_pairings_from_file($round);
    my @results = get_new_results_from_cgi_params();
    write_new_results_to_file($round,@results);
    read_results_from_file_and_display_them($round);
    print_button_main_page();
    print $q->end_html;
} 
## pairings or results are requested
elsif ($action eq 'pairings_or_results') {
    print $q->start_html( -title => loc( "(Pairings and Results)" ) ), "\n",
          $q->h1( loc( "(Pairings and Results)" ) ), "\n";
    $round = get_round_number();
    my $prevround = $round-1;

    ## there are results for this round
    if (-e "$TOURNAMENTDIR/rd_${round}_results") {
        ## read results from file and print them
        read_results_from_file_and_display_them($round);
    }
    ## there are no results, but pairings for this rounds
    elsif (-e "$TOURNAMENTDIR/rd_${round}_pairings") {
        ## read pairings and print form to input results
        read_pairings_from_file($round);
        print_form_save_results($round);
    }
    ## no results, no pairings for this round, but results for prev. round
    elsif ((-e "$TOURNAMENTDIR/rd_${prevround}_results") or ($round == 1)) {
        ## generate pairings, and print form to input results
        print $q->p( loc("(There are no pairings for round %1. Trying to generate them.)", $round) );
        generate_pairings($round,$rounds);
        read_pairings_from_file($round);
        print_form_save_results($round);
    }
    ## no results, no pairings for this round, no results for prev. round
    else {
        ## print error message
        print $q->p( loc("(Round %1 cannot be paired yet. Please check results of previous rounds.)", $round) );
    }
    print_button_main_page();
    print $q->end_html;
} 
## current standing
elsif ($action eq 'standings') {
    $round = get_round_number();
    print_crosstable($round,$rounds);
} 
## pairing table after current round
elsif ($action eq 'pairing_table') {
    $round = get_round_number();
    compute_and_print_pairingtable($round,$rounds);
} 
## debug (view log of pairing procedure)
elsif ($action eq 'debug') {
    $round = get_round_number();
    read_and_display_log_file($round);
} 
## main page for tournament management
else {
    print $q->start_html( -title => loc("(Management of tournament)") ), "\n";
    print_language_menu();
    print $q->h1( loc("(Management for tournament %1)", $t_name) ), 
          "\n", $q->hr;
    print_button_manage_participants();
    print_pairings_or_results_menu();
    print_standings_menu();
    print_pairing_table_menu();
    print_debugging_output_menu();
    print_button_tournament_selection();
    print $q->end_html;
}

sub set_language {
    my $lang;
    if ($q->param('lang')) {
        $lang = $q->param('lang');
    } else {
        $lang = 'en';
    }
    loc_lang("$lang");
    return $lang;
}

sub get_action {
    if ( $q->param('action') ) {
        return $q->param('action');
    } else {
        return 'no_action';
    }
}

sub get_tournament_dir {
    unless ($q->param('t_dir')) {
        print_error_no_tournament_selected();
        die;
    } else {
        unless ($q->param('t_dir') =~ /(\w+)$/) {
            print_error_no_tournament_selected();
            die;
        } else {
            return $1;
        }
    }
}

sub get_tournament_data {
    my @t_data;
    ## TODO: error handling
    open (TDATA, "$TOURNAMENTDIR/$DATAFILE") || die "Couldn't open file $TOURNAMENTDIR/$DATAFILE";
    while (<TDATA>) {
        if (/^tournament name: (.*)$/) {
            $t_data[0] = $1;
        }
        if ((/^rounds: (\d+)$/) and ($1 > 2) and ($1 < 10)) {
            $t_data[1] = $1;
        }
        if (/^status: (.*)$/) {
            $t_data[2] = $1;
        }
    }
    close(TDATA);
    return @t_data;
}

sub compute_and_print_pairingtable {
    my $round = shift;
    my $rounds_total = shift;
    my $table;

    print $q->start_html( -title => loc("(Pairing Table)") ), "\n",
          $q->h1( loc("(Pairing Table)") ), "\n"; 

    ## TODO: check whether we have results for this round
    ## TODO: try to factor out duplicate code from crosstable,
    ##       generate_pairing and pairingtable 

    ## map actual results and numerical results for internal use
    my %map = ('Win','1','Bye','1','Draw','0.5','Loss','0','Absent','0');

    ## get players
    my @players = read_players_from_data_file();

    ## create tournament object
    my $tourney = Games::Tournament::Swiss->new( rounds => $rounds_total, 
                                                 entrants => \@players );

    ## IMPORTANT: assing pairing numbers and initialize preferences
    ## otherwise $tourney->formBrackets doesn't work (see below)
    $tourney->assignPairingNumbers( @players );
    $tourney->initializePreferences;
    $tourney->round(0);

    ## if there are earlier rounds: add games to our tournament
    foreach my $round_number (1..$round) {
        ## get games (list of hash references) 
        my @games = read_games_from_file($tourney,$round_number);

        ## taken from t/three.t of Games::Tournament::Swiss
        ## not sure what it does exactly
        $tourney->collectCards(@games);

        ## get colors and floats from game data
        foreach my $game ( @games ) {
            if ( $game->{contestants}->{Bye} ) { 
                my $bye = $game->{contestants}->{Bye};
                my $id = $bye->id;
                $table->{$id}->{id} = $id;
                my $opponent = 
                   Games::Tournament::Contestant->new(name=>"Bye",id=>"-");
                $table->{$id}->{opponents} .= $opponent->id . ",";
                my $role = '-';
                $table->{$id}->{roles} .= $role;
            }
            else {
                ## get players for this game
                my $white = $game->{contestants}->{White};
                my $black = $game->{contestants}->{Black};
    
                ## get colors (roles) and add them to player objects
                $white->roles( $game->myRole($white) );
                $black->roles( $game->myRole($black) );
    
                ## check for floats and add them to player objects
                my $result_white = $map{$game->{result}->{White}};
                my $result_black = $map{$game->{result}->{Black}};
    
                ## white had higher score before game 
                if ( ( $white->score - $result_white ) 
                       > ( $black->score - $result_black ) ) {
                    ## white floats down, black floats up
                    $white->floats( $round_number, 'Down' );
                    $black->floats( $round_number, 'Up' );
                }
                ## white had lower score before game 
                elsif ( ( $white->score - $result_white ) 
                       < ( $black->score - $result_black ) ) {
                    ## white floats down, black floats up
                    $white->floats( $round_number, 'Up' );
                    $black->floats( $round_number, 'Down' );
                }
    
                ## taken from 'pairtable' script
                my $id_white = $white->id;
                my $id_black = $black->id;
                $table->{$id_white}->{id} = $id_white;
                $table->{$id_black}->{id} = $id_black;
                my $opponent_black = $black->myOpponent($game);
                my $opponent_white = $white->myOpponent($game);
                $table->{$id_white}->{opponents} .= $opponent_white->id . ",";
                $table->{$id_black}->{opponents} .= $opponent_black->id . ",";
                my $role_white = $game->myRole($white);
                my $role_black = $game->myRole($black);
                $role_white =~ s/^(.).*$/$1/;
                $role_black =~ s/^(.).*$/$1/;
                $table->{$id_white}->{roles} .= $role_white;
                $table->{$id_black}->{roles} .= $role_black;
            }
        }

        ## taken from t/three.t of Games::Tournament::Swiss
        ## not sure what it does exactly
        $tourney->round($round_number);
    }

    ## form brackets with equal total scores
    my %brackets = $tourney->formBrackets;

    ## taken from 'pairtable' script
    my $playerN = 0;

    my @rounds = (1..$round);
    print "<pre>\n";

    print "
                Round @{[$#rounds+2]} Pairing Groups
-------------------------------------------------------------------------
Place  No  Opponents     Roles     Float Score
";
    for my $index ( reverse sort keys %brackets )
    {
            $playerN++;
            my $place = $playerN;
            my @members = @{$brackets{$index}->members};
            $place .= '-' . ($playerN+$#members) if $#members;
            $playerN += $#members;
            print "$place\n";
            foreach my $member ( @members )
            {
                    my $id = $member->id;
                    chop $table->{$id}->{opponents};
                    my $floats = $member->floats;
                    my $float = '';
                    $float = 'd' if $floats->[-2] and $floats->[-2] eq 'Down';
                    $float = 'u' if $floats->[-2] and $floats->[-2] eq 'Up';
                    $float .= 'D' if $floats->[-1] and $floats->[-1] eq 'Down';
                    $float .= 'U' if $floats->[-1] and $floats->[-1] eq 'Up';
    
            format STDOUT =
@<<<<< @<< @<<<<<<<<<<<<< @<<<<<<<< @<< @<<<
"", $id,  $table->{$id}->{opponents}, $table->{$id}->{roles}, $float, $member->score
.
            write;
            }
    }
    print "</pre>\n";
    print_button_main_page();
    print $q->end_html;
}

sub print_crosstable {
    my $round = shift;
    my $rounds_total = shift;

    print $q->start_html( -title => loc("(Standings)") ), "\n",
          $q->h1( loc("(Standings)") ), "\n"; 

    ## map actual results and symbols for use in table
    my %map = ('Win','+','Bye','+','Draw','=','Loss','-','Absent','-');

    ## TODO: check whether we have results for this round
    my @players = read_players_from_data_file();
    my $tourney = Games::Tournament::Swiss->new( entrants => \@players );
    ## get games
    foreach my $round_number (1..$round) {
        my @games = read_games_from_file($tourney,$round_number);
        $tourney->collectCards(@games);
    }

    ## rank players 
    my @players_ranked = $tourney->rank(@{$tourney->{entrants}});

    ## create hash with names of players (keys) and ranks (values)
    my $number_of_players = @players_ranked;
    my %players_rank;
    foreach my $rank (1..$number_of_players) {
        $players_rank{$players_ranked[$rank-1]->{name}} = $rank;
    }

    ## start output
    print $q->start_table( { -class => 'standings' } ), "\n";

    ## table header
    print $q->start_Tr(), "\n";
    print $q->start_th(), loc("(Rank)"), $q->end_th, "\n";
    print $q->start_th(), loc("(No)"), $q->end_th, "\n";
    print $q->start_th(), loc("(Name)"), $q->end_th, "\n";
    print $q->start_th(), loc("(Rating)"), $q->end_th, "\n";
    ## columns for all rounds (played an coming)
    foreach my $round_number (1..$rounds_total) { 
        print $q->start_th(), $round_number, $q->end_th, "\n";
    }
    print $q->start_th(), loc("(Points)"), $q->end_th, "\n";
    print $q->end_Tr(), "\n";

    ## rows for players and results
    my $rank = 1;
    foreach my $player (@players_ranked) {
        print $q->start_Tr(), "\n";
        print $q->start_td(), $rank, $q->end_td, "\n";
        print $q->start_td(), $player->{pairingnumber}, $q->end_td, "\n";
        print $q->start_td(), $player->{name}, $q->end_td, "\n";
        print $q->start_td(), $player->{rating}, $q->end_td, "\n";

        ## result and opponent for rounds played 
        foreach my $round_number (1..$round) {
            ## determine opponent
            ## TODO: is this error-prone? (e.g. no opponent found?)
            my $opp = $player->myOpponent(
                          $tourney->{play}->{$round_number}->{$player->{id}}
                      );

            ## print result and rank of opponent
            print $q->start_td(),
                  $map{$player->{scores}->{$round_number}},
                  $players_rank{$opp->{name}},
                  $q->end_td(), "\n";
        }

        ## mark future rounds with a simple dot
        if ( $round < $rounds_total ) {
            foreach my $round_number ($round+1..$rounds_total) {
                print $q->start_td(), ".", $q->end_td, "\n";
            }
        }

        print $q->start_td(), $player->score, $q->end_td, "\n";

        print $q->end_Tr(), "\n";
        $rank++;
    }

    print $q->end_table, "\n";

    print_button_main_page();
    print $q->end_html;
}

sub read_games_from_file {
    my $tourney = shift;
    my $r = shift;
    my $ResWhite;
    my $ResBlack;
    my $game;
    my @games;
    open(GAMES,"$TOURNAMENTDIR/rd_${r}_results");
    while (<GAMES>) {
        if ( /^Board \d+: (.*)$/ ) {
            my ($White,$Black,$result) = split (/\t/,$1);
            if ( $result eq '= : =' ) {
                $ResWhite = 'Draw';
                $ResBlack = 'Draw';
            } elsif ( $result eq '1 : 0' ) {
                $ResWhite = 'Win';
                $ResBlack = 'Loss';
            } elsif ( $result eq '0 : 1' ) {
                $ResWhite = 'Loss';
                $ResBlack = 'Win';
            }
            $game = Games::Tournament::Card->new(
                round => $r,
                contestants => { Black => $tourney->named($Black),
                                 White => $tourney->named($White) },
                result => { Black => $ResBlack, White => $ResWhite },
            );
            push(@games,$game);
        }
        if ( /^Bye: (.*)$/ ) {
            $game = Games::Tournament::Card->new(
                round => $r,
                contestants => { Bye => $tourney->named($1) },
                result => { Bye => 'Bye' }
            );
            push(@games,$game);
        }
    }
    close(GAMES);
    return @games;
}

sub get_round_number {
    my $round;
    if ($q->param('round') =~ /(\d+)/) { $round = $1; }
    return($round);
}

sub read_pairings_from_file {
    my $r = shift;
    undef(@Bye);
    undef(%White);
    undef(%Black);
    open(PAIRING,"$TOURNAMENTDIR/rd_${r}_pairings");
    while (<PAIRING>) {
        ## player with a bye
        if (/^Bye: (.*)\n$/) {        
            push (@Bye, $1);
        }
        ## normal line with White and Black
        elsif (/^Board (\d+): (.*)\t(.*)\n$/) {        
            $board = $1;
 			$White{$board} = $2;
            $Black{$board} = $3;
        }
    }
	close(PAIRING);
}

sub get_new_results_from_cgi_params {
    my $board = 1;
    my @results;
    while ($q->param("Board$board")) {
        $results[$board] = $q->param("Board$board");
        $board++;
    }
    return @results;
}

## TODO: Besser Dokumentieren
sub write_new_results_to_file {
    my $round = shift;
    my @results = @_;
    open(RESULTS_NEW, ">$TOURNAMENTDIR/rd_${round}_results");
    foreach $board ( sort {$a <=> $b} keys(%White)) {
        print RESULTS_NEW "Board $board: ",
                          "$White{$board}",
                          "\t",
                          "$Black{$board}",
                          "\t",
                          "$results[$board]",
                          "\n";
    }
    if ( @Bye ) {
        foreach ( @Bye ) {
            print RESULTS_NEW "Bye: $_\n";
        }
    }
    close(RESULTS_NEW);
}

sub get_result {
	my $Player = shift();
	foreach (@scores) {
		if (/^'$Player': (\w+)$/) {
			if ($1 eq "Win") { return "1"; }
			if ($1 eq "Draw") { return "="; }
			if ($1 eq "Loss") { return "0"; }
		}
	}
}

sub generate_pairings {
    my $round = shift;
    my $rounds_total = shift;

    ## TODO: check whether we have results for this round

    ## map actual results and numerical results for internal use
    my %map = ('Win','1','Bye','1','Draw','0.5','Loss','0','Absent','0');

    ## get players
    my @players = read_players_from_data_file();

    ## create tournament object
    my $tourney = Games::Tournament::Swiss->new( rounds => $rounds_total, 
                                                 entrants => \@players );

    ## IMPORTANT: assing pairing numbers and initialize preferences
    ## otherwise $tourney->formBrackets doesn't work (see below)
    $tourney->assignPairingNumbers( @players );
    $tourney->initializePreferences;
    $tourney->round(0);

    ## if there are earlier rounds: add games to our tournament
    if ( $round ne '1' ) {
        foreach my $round_number (1..$round-1) {
            ## get games (list of hash references) 
            my @games = read_games_from_file($tourney,$round_number);

            ## taken from t/three.t of Games::Tournament::Swiss
            ## not sure what it does exactly
            $tourney->collectCards(@games);

            ## get colors and floats from game data
            foreach my $game ( @games ) {
                if ( $game->{contestants}->{Bye} ) { 
                    ## do we have to do something?
                }
                else {
                    ## get players for this game
                    my $white = $game->{contestants}->{White};
                    my $black = $game->{contestants}->{Black};
    
                    ## get colors (roles) and add them to player objects
                    $white->roles( $game->myRole($white) );
                    $black->roles( $game->myRole($black) );
    
                    ## check for floats and add them to player objects
                    my $result_white = $map{$game->{result}->{White}};
                    my $result_black = $map{$game->{result}->{Black}};
    
                    ## white had higher score before game 
                    if ( ( $white->score - $result_white ) 
                        > ( $black->score - $result_black ) ) {
                        ## white floats down, black floats up
                        $white->floats( $round_number, 'Down' );
                        $black->floats( $round_number, 'Up' );
                    }
                    ## white had lower score before game 
                    elsif ( ( $white->score - $result_white ) 
                        < ( $black->score - $result_black ) ) {
                        ## white floats down, black floats up
                        $white->floats( $round_number, 'Up' );
                        $black->floats( $round_number, 'Down' );
                    }
                }
            }

            ## taken from t/three.t of Games::Tournament::Swiss
            ## not sure what it does exactly
            $tourney->round($round_number);
        }
    }

    ## specify log file and select LOGFILE
    open(LOGFILE, ">$TOURNAMENTDIR/rd_${round}_logfile");
    select (LOGFILE);

    ## form brackets with equal total scores
    my %brackets = $tourney->formBrackets;

    ## get a Games::Tournament::Swiss::Procedure object with given brackets
    my $pairing = $tourney->pairing( \%brackets );

    ## be verbose about pairing process
    $pairing->loggingAll;

    ## pair new round
    my $paired = $pairing->matchPlayers;

    ## select STDOUT and close log file
    select (STDOUT);
    close(LOGFILE);

    ## prepare computed pairings for output
    my $matches = $paired->{matches};
    my @games;
    ## dirty hack to get the order of matches right (added by CB 2008-07-11)
    ## keys from %$matches are named "2.5", "2", "2Remainder", "0Bye" and so on
    for my $bracket ( reverse sort {
            if ( $a =~ /Bye$/ ) {
                return -1;
            }
            elsif ( $b =~ /Bye$/ ) {
                return 1;
            }
            elsif ( $a =~ /^(\d+\.?5?)Remainder$/ ) { 
                if ( $1 eq $b ) {
                    return -1;
                }
                else { 
                    my $numbers_a = $1;
                    if ( $b =~ /^(\d+\.?5?)Remainder$/ ) {
                        return $numbers_a cmp $1;
                    }
                    else {
                        return $numbers_a cmp $b; 
                    }
                }
            }
            elsif ( $b =~ /^(\d+\.?5?)Remainder$/ ) { 
                if ( $1 eq $a ) {
                    return 1;
                }
                else { 
                    my $numbers_b = $1;
                    if ( $a =~ /^(\d+\.?5?)Remainder$/ ) {
                        return $1 cmp $numbers_b;
                    }
                    else {
                        return $a cmp $numbers_b; 
                    }
                }
            }
            else { return $a cmp $b; }
        } keys %$matches )
    {
        my $bracketmatches = $matches->{$bracket};
        push @games, grep { $_ if ref eq 'Games::Tournament::Card' }
            @$bracketmatches;
    }

    open(PAIRINGS, ">$TOURNAMENTDIR/rd_${round}_pairings");
    my $n = 1;
    foreach my $game (@games) {
        if ( $game->{contestants}->{Bye} ) {
            my $bye = $game->{contestants}->{Bye};
            print PAIRINGS "Bye: $bye->{name}\n";
        }
        else {
            my $white = $game->{contestants}->{White};
            my $black = $game->{contestants}->{Black};
    
            print PAIRINGS "Board $n: ",
                           "$white->{name}",
                           "\t",
                           "$black->{name}",
                           "\n";
        }
        $n++;
    }
    close(PAIRINGS);
}

sub read_and_display_log_file {
    my $round = shift; 

    ## TODO: error handling
    print $q->start_html;
    open(LOGFILE, "$TOURNAMENTDIR/rd_${round}_logfile");
    while (<LOGFILE>) {
        print $_, $q->br;
    }
    close(LOGFILE);
    print_button_main_page();
    print $q->end_html;
}

## TODO: Is there a cleaner way to do this?
sub sort_and_assign_pairingnumbers {
    my $players = shift;
    # my $tourney = Games::Tournament->new( entrants => \@players );
    # @players = $tourney->rank(@players);
    my $lineup;
    my $pairingnumber;
    my @ratings;
    for $member ( @{$players->{member} } ) {
        push(@ratings,$member->{rating});
    }
    my @list = reverse sort { $a <=> $b } @ratings;
    my %registered;
    foreach (@list) {    ## checking existing ratings from @list
        for $member ( @{$players->{member} } ) { ## checking players
            if (($member->{rating} >= $_)           ## high rating?
                and ($registered{$member} != '1')) { ## not marked?
                    push @$lineup, $member;     ## add this one!
                    ## assigning pairingnumber
                    $member->{pairingnumber} = ++$pairingnumber;
                    $registered{$member} = 1;           ## mark player
            }
        }
    }
    ## put players from $lineup in YAML data structure and return them
    return $players = { member => $lineup };
}

sub read_players_from_data_file {
    my @players;
    my $new_player;
    my $firstname;
    my $surname;
    my $rating;
    my $id;
    my $pairingNumber;
    ## TODO: error handling
    if (-e "$TOURNAMENTDIR/players") {
        open(FILE,"$TOURNAMENTDIR/players");
        while (<FILE>) {
            chomp();
            ($id,$pairingNumber,$surname,$firstname,$rating) = split(/\t/);
            $new_player = Games::Tournament::Contestant::Swiss->new(
                surname => $surname,
                firstname => $firstname,
                name => $surname . ", " . $firstname,
                rating => $rating,
                id => $id,
                pairingnumber => $pairingNumber,
                preference =>
                    Games::Tournament::Contestant::Swiss::Preference->new
            );
            push(@players,$new_player);
        }
        close(FILE);
    }
    return(@players);
}

sub new_player_from_cgi_data {
    my $id = shift;
    my $firstname = $q->param('firstname');
    my $surname = $q->param('surname');
    my $rating = $q->param('dwz');
    my $new_player = Games::Tournament::Contestant::Swiss->new( 
        surname => $surname,
        firstname => $firstname,
        name => $surname . ", " . $firstname,
        rating => $rating,
        id => $id
    );
    return $new_player;
}

sub write_players_to_file_and_assign_pairing_number {
    my @players = @_;
    my $tourney = Games::Tournament->new( entrants => \@players );
    @players = $tourney->rank(@players);
    ## TODO: Is there a cleaner way to assign pairing numbers?
    ## TODO: $tourney->assignPairingNumbers seems to expect other things
    open(FILE,">$TOURNAMENTDIR/players");
    my $n = 1;
    foreach (@players) {
        $_->pairingNumber($n);
        print FILE "$_->{id}\t",
                   "$_->{pairingNumber}\t",
                   "$_->{surname}\t",
                   "$_->{firstname}\t",
                   "$_->{rating}\n";
        $n++;
    }
    close(FILE);
}

sub add_participant {
    my @players = @_;
    if ($q->param('firstname') and $q->param('surname')) {
        my $maxid = 0;
        foreach (@players) {
            if ( $_->{id} >= $maxid) { $maxid = $_->{id}; }
        }
        ## TODO: securing input?
        my $new_player = new_player_from_cgi_data($maxid+1);
        push(@players,$new_player);
        write_players_to_file_and_assign_pairing_number(@players);
    } else { 
        print $q->p( loc("(Incomplete data.)") ),
              $q->p( loc("(Please insert firstname and surname!)") );
    }
}

sub delete_participant {
    my @players = @_;
    my @left_players;
    foreach (@players) {
        unless ( $_->{id} eq $q->param('id') ) {
            push(@left_players,$_);
        }
    }
    write_players_to_file_and_assign_pairing_number(@left_players);
}

sub print_form_save_results {
    my $round = shift;

    print $q->p( loc("(Please enter results of round %1:)", $round) ),
          $q->start_form( -action => "./$CGISCRIPT",
                          -method => 'post' );

    ## print HTML table with form elements for input of results
    print_results_as_table('print_form');

    print $q->p,
          $q->hidden( -name => 'action', -default => 'new_results',
                      -override => 'true' ), "\n",
          $q->hidden( -name => 't_dir', 
                       -default => "$t_dir" ), "\n",
          $q->hidden( -name => 'round', 
                       -default => "$round" ), "\n",
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc( "(save results)" ) ), "\n",
          $q->end_form, "\n";
}

## read results from file and display them
sub read_results_from_file_and_display_them {
    my $round = shift;

    undef(@Bye);

    ## read results from file
    open(RESULTS,"$TOURNAMENTDIR/rd_${round}_results");
    while (<RESULTS>) {
        if ( /^Board (\d+): (.*)$/ ) {
            my $board = $1;
            my $result;
            ($White{$board},$Black{$board},$result) = split (/\t/,$2);
            ($ResWhite{$board},$ResBlack{$board}) = split (/ : /,$result);
        }
        elsif ( /^Bye: (.*)$/ ) {
            push (@Bye, $1);
        }
    }
    close(RESULTS);

    ## print HTML table with given results (no form elements for input)
    print $q->p( loc("(Results of round %1:)", $round) );
    print_results_as_table('print_given_results');
}

sub print_results_as_table {
    ## shall we print form elements for new results or show given results?
    my $form_or_given_results = shift;

    ## start table
    print $q->start_table( { -class => 'results' } ), "\n";
    print $q->start_Tr(), "\n";
    print $q->start_th(), loc("(Board)"), $q->end_td, "\n";
    print $q->start_th(), loc("(White)"), $q->end_td, "\n";
    print $q->start_th(), loc("(Black)"), $q->end_td, "\n";
    print $q->start_th(), loc("(Result)"), $q->end_td, "\n";
    print $q->end_Tr(), "\n";

    ## print table rows for played games
    foreach $board (sort {$a <=> $b} keys(%White)) {
        print $q->start_Tr(), "\n";
        print $q->start_td(), $board, $q->end_td, "\n";
        print $q->start_td(), $White{$board}, $q->end_td, "\n";
        print $q->start_td(), $Black{$board}, $q->end_td, "\n";
        print $q->start_td();
        if ( $form_or_given_results eq 'print_form' ) {
            print $q->popup_menu( -name => "Board$board", 
                                  -values => [('1 : 0', '= : =', '0 : 1')]);
        }
        elsif ( $form_or_given_results eq 'print_given_results' ) {
            print "$ResWhite{$board} : $ResBlack{$board}";
        }
        print $q->end_td, "\n";
        print $q->end_Tr(), "\n";
    }

    ## print table rows for byes
    foreach my $player_with_bye ( @Bye ) { 
        print $q->start_Tr(), "\n";
        print $q->start_td(), "-", $q->end_td, "\n";
        print $q->start_td(), $player_with_bye, $q->end_td, "\n";
        print $q->start_td(), $q->end_td, "\n";
        print $q->start_td(), loc("(Bye)"), $q->end_td, "\n";
        print $q->end_Tr(), "\n";
    }

    ## end table
    print $q->end_table, "\n";
}

sub show_page_for_managing_participants {
    display_form_for_new_participant();
    display_participants();
    print_button_main_page();
    print $q->end_html;
}

sub display_form_for_new_participant {
    print $q->h3 ( loc("(New Participant)") ), "\n",
          $q->start_form( -action => "./$CGISCRIPT",
                          -method => 'post' ),
          loc("(Firstname: )"), $q->textfield( -name => 'firstname' ), "\n",
          loc("(Surname: )"), $q->textfield( -name => 'surname' ), "\n",
          loc("(Rating: )"), $q->textfield( -name => 'dwz' ), "\n",
          $q->hidden( -name => 'action', 
                      -default => 'add_participant',
                      -override => 'true' ), "\n",
          $q->hidden( -name => 't_dir', -default => "$t_dir" ), "\n",
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc("(add participant)") ), "\n",
          $q->end_form, "\n",
          $q->hr, "\n";
}

sub display_participants {
    my @players = read_players_from_data_file();
    print $q->h3 ( loc("(List of Participants)") ), "\n";
    print $q->start_table( { -border => 2, -cellpadding => 4, 
                             -cellspacing => 2 } ), "\n",
          $q->Tr( [ $q->th ( [ loc("(Nr.)"), loc("(Name)"), 
                               loc("(Rating)"), '' ] ) ] ), "\n";
    foreach ( @players ) {
        print $q->start_TR,
              $q->td( "$_->{pairingnumber}"),
              $q->td( "$_->{name}"),
              $q->td( "$_->{rating}"),
              $q->start_td, "\n",
              $q->start_form ( -action => "./$CGISCRIPT",
                               -method => 'post' ), "\n",
              $q->hidden( -name => 'action', -default => 'delete_participant',
                          -override => 'true' ), "\n",
              $q->hidden( -name => 't_dir', -default => "$t_dir" ), "\n",
              $q->hidden( -name => 'id', -default => "$_->{id}",
                          -override => 'true' ), "\n",
              $q->hidden( -name => 'lang', -default => "$language",
                          -override => 'true' ), "\n",
              $q->submit( -value => loc("(delete)") ), "\n",
              $q->end_td,
              $q->end_TR,
              $q->end_form, "\n";
    }
    print $q->end_table;
}

sub print_button_main_page {
    print $q->hr,
          $q->start_form( -action => "./$CGISCRIPT",
                          -method => "post"),
          $q->hidden( -name => 't_dir', -default => "$t_dir" ), "\n",
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc("(back to management of tournament)") ),
          "\n",
          $q->end_form;
}

sub print_button_tournament_selection {
    print $q->hr, "\n",
          $q->start_form( -action => "./$CGISELECT",
                          -method => 'post'),
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc("(tournament selection)") ), "\n",
          $q->end_form, "\n",
}

sub print_error_no_tournament_selected {
    print $q->header,
          $q->start_html( -title => 
                          loc( "(Error while selecting tournament)" ) ), "\n",
          $q->h1( loc("(Error while selecting tournament)") ), "\n",
          $q->p(loc("(You didn't select a tournament.)")), "\n",
          $q->p(loc("(Please click below to return to tournament selection.)"));
    print_button_tournament_selection();
    print $q->end_html;
}

sub print_language_menu {
    print $q->start_form( -method => 'post',
                          -action => "./$CGISCRIPT" ),
          $q->popup_menu ( -name => 'lang',
                           -values => [@LANGUAGES] ),
          $q->hidden( -name => 't_dir', -default => "$t_dir" ),
          $q->submit( -value => loc("(select language)") ),
          $q->end_form, $q->hr, "\n";
}

sub print_button_manage_participants {
    print $q->start_form( -action => "./$CGISCRIPT",
                          -method => 'post' ),
          $q->hidden( -name => 'action', -default => 'manage_participants' ),
          $q->hidden( -name => 't_dir', -default => "$t_dir" ),
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc("(Participants)") ),
          $q->end_form, "\n", $q->hr, "\n";
}

sub print_pairings_or_results_menu {
    print $q->h3( loc("(Pairings and Results)") ),
          $q->start_form( -action => "./$CGISCRIPT",
                          -method => 'post' ),
          $q->popup_menu( -name => 'round', -values => [(1..$rounds)] ),
          $q->hidden( -name => 'action', -default => 'pairings_or_results' ),
          $q->hidden( -name => 't_dir', -default => "$t_dir" ),
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc("(select round)") ),
          $q->end_form, "\n", $q->hr, "\n";
}

sub print_standings_menu {
    print $q->h3( loc("(Standings)") ),
          $q->start_form( -action => "./$CGISCRIPT",
                          -method => 'post' ),
          $q->popup_menu( -name => 'round', -values => [(1..$rounds)] ),
          $q->hidden( -name => 'action', -default => 'standings' ),
          $q->hidden( -name => 't_dir', -default => "$t_dir" ),
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc("(select round)") ),
          $q->end_form, "\n", $q->hr, "\n";
}

sub print_pairing_table_menu {
    print $q->h3( loc("(Pairing Tables)") ),
          $q->start_form( -action => "./$CGISCRIPT",
                          -method => 'post' ),
          $q->popup_menu( -name => 'round', -values => [(1..$rounds)] ),
          $q->hidden( -name => 'action', -default => 'pairing_table' ),
          $q->hidden( -name => 't_dir', -default => "$t_dir" ),
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc("(select round)") ),
          $q->end_form, "\n", $q->hr, "\n";
}

sub print_debugging_output_menu {
    print $q->h3( loc("(Output of pairing routines -- for debugging)") ),
          $q->start_form( -action => "./$CGISCRIPT",
                          -method => 'post' ),
          $q->popup_menu( -name => 'round', -values => [(1..$rounds)] ),
          $q->hidden( -name => 'action', -default => 'debug' ),
          $q->hidden( -name => 't_dir', -default => "$t_dir" ),
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc("(select round)") ),
          $q->end_form, "\n";
}

__END__

##############################################################################
##    POD for perl applications                                             ##
##    Derived from Example 7.2 from Chapter 7 of "Perl Best Practices"      ##
##    by Damian Conway. Copyright (c) O'Reilly & Associates, 2005.          ##
##############################################################################

=head1 NAME

tournament.pl - CGI script for managing swiss chess tournaments
 
=head1 VERSION

Version 0.0.10

=head1 USAGE
 
Used as a CGI script in combination with select_tournament.pl
 
=head1 DESCRIPTION

This CGI script is part of a project to create a perl-based web interface for
management of swiss chess tournaments. It is used for adding and removing
participants, creating pairings and displaying crosstables. That is, it allows
to do the basic things of tournament management.

=head2 REQUIRED ARGUMENTS

Required arguments
 
=head2 OPTIONS

Available options
 
=head2 SETUP

Adjust the following settings for your site.

=item C<$CGIDIR>

Directory where CGI scripts reside.

=item C<$TOURNAMENTBASEDIR>

Directory where tournaments are stored.

=item C<Local Modules>

Set the directory where perl modules are installed. Only needed if you
installed modules in non standard directories (e.g. because you didn't have
permissions to installed them system wide).

use lib qw(/path/to/modules/directory);

=head2 I18n

The script uses Locale::Maketext::Simple for internationalization. 

Language files like 'en.po' or 'de.po' are in the subdirectory
'./language_files'. For more informations see
http://search.cpan.org/~audreyt/Locale-Maketext-Simple-0.18/

=head2 Functions

=head3 Program Functions (for executing "real" program code)

=item C<set_language>

Sets language for internationalization (see above) according to CGI parameter
'lang' and returns the language. If no value is specified via CGI param, the
default value 'en' is used. 'lang' is one of ('en', 'de').

=item C<get_action>

Returns the 'action' parameter defined via CGI-form. 'action' is one of
('manage_participants', 'pairings_or_results', 'new_results', 'standings',
'pairing_table', 'debug', 'add_participant', 'delete_participant', '').

=item C<get_tournament_dir>

Checks which tournament we want to work on (CGI param 't_dir'). If no value
is specified or if it doesn't match (\w+) prints an error and die. Otherwise
returns value for $t_dir. $t_dir is untainted in this subroutine.

=item C<get_tournament_data>

Returns the following values read from $DATAFILE:
 * tournament name
 * number of rounds
 * status of tournament

=item C<compute_and_print_pairingtable>

Print the pairing table after a given round. An external script
('pairingtable') is executed and its output is printed as preformatted text.

=item C<print_crosstable>

Print the crosstable after a given round. Rankings and SINGLE results are
computed and presented as a simple table (CSS: class="standings").

=item C<read_games_from_file>

Reads games from file $TOURNAMENTDIR/rd_$round_results and returns corresponding
list of Games::Tournament::Card objects.

=item C<get_round_number>

Returns current round number according to CGI param 'round'.
Value of $q->param('round') is untainted.

=item C<read_pairings_from_file>

Reads pairings from $TOURNAMENTDIR/$r/round.yaml into separate hashes
%White and %Black. Keys for this hashes are the board numbers. $r must be
passed to this function as an argument.

=item C<get_new_results_from_cgi_params>

Returns @results, which are taken from CGI params 'Board1' to 'BoardN'. Each
result is one of 
 * "1 : 0" 
 * "= : ="
 * "0 : 1"

=item C<write_new_results_to_file>

Writes results to file.

=item C<get_result>

Returns "SINGLE character value" for literal result. 
 'Win'  -> '1'
 'Draw' -> '='
 'Loss' -> '0'

=item C<generate_pairings>

Generates pairings. At the moment this is done by starting an external script.
For security reasons there is a time limit for this script to finish. If it
takes longer, we are dying.

=item C<sort_and_assign_pairingnumbers

Sorts players and assigns pairing numbers accoring to rating.

=item C<read_players_from_data_file>

Reads players from file $TOURNAMENTDIR/players as
Games::Tournament::Contestant::Swiss-> new objects and returns list of all
players.

=item C<new_player_from_cgi_data>

Creates new player as Games::Tournament::Contestant::Swiss-> new object and
returns reference to that object. Values are read from CGI params
'firstname', 'surname', 'dwz'.

=item C<write_players_file_and_assign_pairing_number>

Assigns pairing numbers to list of players and writes list of players to file
'players' afterwards. Uses a simple tab-delimited format -- one player per
line with the following values: 
 * id 
 * pairing number 
 * surname 
 * firstname 
 * rating

=item C<add_participant>

Adds a new participant to file $PARTICIPANTS. Data are read from CGI params
'firstname', 'surname' and 'rating' (the last param is optional). The id of
the new player is 1 greater than the highest id of 'old players'.

=item C<delete_participant>

Removes one player from list of participants and write the new list to file
$PARTICIPANTS.

=head3 Output Functions (for printing HTML code)

=item C<print_form_save_results>

Prints all pairings together with pull-down menues for the results. Pairings
are stored in %White and %Black. Byes are stored in @Bye.

=item C<read_results_from_file_and_display_them>

Prints results for a given round. The round number must be passed as an
argument to this funktion. Pairings are read from file "$round/round.yaml".
Results are read from file "scores/$round.yaml".

=item C<show_page_for_managing_participants>

Displays the main page for management of participants. This consists of 
 * a form to add a new participant, 
 * a list of all actual participants with buttons to delete them

=item C<display_form_for_new_participant>

Prints a CGI form for adding a new participants. Requested values are
 * firstname
 * surname
 * rating (DWZ)

=item C<display_participants>

Prints relevant data for all participants. Also prints a "delete" button for
each participant. Data is printed as a table (one participant per row).

=item C<print_button_main_page>

Prints a button to return to main page for this tournament.

=item C<print_button_tournament_selection>

Prints a button to return to page for tournament selection.

=item C<print_error_no_tournament_selected>

Prints error message if no tournament is selected. (This may occur when the
script is called without correct values for CGI param 't_dir'.) 

=item C<print_language_menu>

Prints a "select language" menu as a CGI form. Available values are presented
as a dropdown menu and are taken from @LANGUAGES. CGI paramter 'lang' is set
to selected language.

=item C<print_button_manage_participants>

Prints a button which sets the CGI param 'action' to 'manage_participants'.

=item C<print_pairings_or_results_menu>

Prints a menu to display pairings or results for a certain round. 

=item C<print_standings_menu>

Prints a menu to display standings for a certain round. 

=item C<print_pairing_table_menu>

Prints a menu to display the pairing table for a certain round. 

=item C<print_debugging_output_menu>

Prints a menu to display the output of script 'pair' for a certain round. This
is used for debugging purpose only.



=head2 DIAGNOSTICS
 
A list of every error and warning message that the application can generate
(even the ones that will "never happen"), with a full explanation of each 
problem, one or more likely causes, and any suggested remedies. If the
application generates exit status codes (e.g. under Unix) then list the exit
status associated with each error.
 
=head1 DEPENDENCIES
 
The script depends on the following modules.

=item C<CGI>

Needed because the script is used via a web frontend.

=item C<Locale::Maketext::Simple>

Used for internationalization. (See I18n below.)

=item C<Games::Tournament::Swiss::Config>

Module by Dr Bean for Swiss Tournaments. See http://search.cpan.org/dist/Games-Tournament-Swiss/

 
=head1 BUGS AND LIMITATIONS
 
There are no known bugs in this application. 
Please report problems to Christian Bartolomaeus  (<bartolin@gmx.de>)
 
=head1 AUTHOR
 
Christian Bartolomaeus  (<bartolin@gmx.de>)

=head1 ACKNOWLEDGMENTS

This script took a lot of ideas and some code from different parts of
Games::Tournament::Swiss (written by DrBean,
http://search.cpan.org/~drbean/Games-Tournament-Swiss/)
 
=head1 LICENCE AND COPYRIGHT
 
Copyright (c) <2008> <Christian Bartolomaeus> (<bartolin@gmx.de>), all rights reserved.
 
This application is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

# vim: set tw=78 ts=4 sw=4 et:
