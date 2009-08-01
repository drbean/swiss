#!/usr/bin/perl -w

## TODO: Sicherheitschecks, damit Skript nicht in endloser Schleife landet?
## TODO: Sicherheitschecks, damit Skript nicht endlos in 'tmpfile' loggt!
## TODO: Sicherung einbauen, damit nicht nach Turnierstart noch
##       Teilnehmer hinzugefügt werden.
## TODO: Paarungen für Runden aufheben
## TODO: Sicherheitschecks beim Lesen und Schreiben der Datei
## TODO: use perldoc

use strict;
use warnings;

=head1 NAME

tournament.pl

=head1 VERSION

Version 0.04

=head1 DESCRIPTION

This small CGI script is part of a project to create a perl-based web
interface for management of swiss chess tournaments. It is used for adding and
removing participants, creating pairings and displaying crosstables. That is,
it allows to do the basic things of tournament management.

=head1 DOCUMENTATION

=head2 Setup

=over 8

Adjust the following settings for your site.

=item C<$CGIDIR>

Directory where CGI scripts reside.

=item C<$TOURNAMENTBASEDIR>

Directory where tournaments are stored.

=item C<$PAIRSCRIPTDIR>

Directory where pair scripts from Games::Tournament::Swiss reside.

=cut

my $CGIDIR = '/home/pacs/mih01/users/cb02/doms/aglaz.de/cgi/swiss-pairing';
# my $CGIDIR = '/home/christian/bin/pairing';
my $TOURNAMENTBASEDIR = '/home/pacs/mih01/users/cb02/doms/aglaz.de/subs/www/swiss-pairing/tournaments';
# my $TOURNAMENTBASEDIR = '/home/christian/public_html/pairing/';
my $PAIRSCRIPTDIR = '/home/pacs/mih01/users/cb02/lib/bin';
# my $PAIRSCRIPTDIR = '/opt/perl_modules/Games-Tournament-Swiss-0.08/script_files';

=item C<Local Modules>

Set the directory where perl modules are installed. Only needed if you
installed modules in non standard directories (e.g. because you didn't have
permissions to installed them system wide).

use lib qw(/path/to/modules/directory);

=back

=cut

use lib qw(/home/pacs/mih01/users/cb02/lib);

=head2 Modules

=over 8

The script depends on the following modules.

=item C<CGI>

Needed because the script is used via a web frontend.

=item C<YAML>

Needed because Games::Tournament::Swiss uses YAML files.

=item C<Locale::Maketext::Simple>

Used for internationalization. (See I18n below.)

=item C<Games::Tournament::Swiss::Config>

Module by Dr Bean for Swiss Tournaments. See http://search.cpan.org/dist/Games-Tournament-Swiss/

=back

=cut

use CGI;
use YAML qw(LoadFile DumpFile);
use Locale::Maketext::Simple (   ## i18n, 'perldoc Locale::Maketext::Simple'
    Path => './language_files',
    Style => 'gettext'
);
use Games::Tournament::Swiss::Config;

=head2 I18n

=over 8

The script uses Locale::Maketext::Simple for internationalization. 

Language files like 'en.po' or 'de.po' are in the subdirectory
'./language_files'. For more informations see
http://search.cpan.org/~audreyt/Locale-Maketext-Simple-0.18/

=back

=cut

my $DATAFILE = 'tournament_data';        ## contains tournament data
my $PARTICIPANTS = 'league.yaml';        ## file with participants
my $SCORES = 'scores';                   ## directory to enter scores
my $CGISCRIPT = 'tournament.pl';         ## CGI script to manage tournament
my $CGISELECT = 'select_tournament.pl';  ## CGI script to select tournaments

## An Version 0.08 angepasst (pairingtable -> pairtable2yaml, pair)
## compare README for Games::Tournament::Swiss
my $PAIRSCRIPT = "$PAIRSCRIPTDIR/pair";
my $PAIRTABLE2YAMLSCRIPT = "$PAIRSCRIPTDIR/pairtable2yaml";
my $PAIRINGTABLESCRIPT = "$PAIRSCRIPTDIR/pairingtable";
my $CROSSTABLESCRIPT = "$PAIRSCRIPTDIR/crosstable";
my $PAIRINGTABLE = "pairingtable.txt";
my $PAIRTABLEYAML = "pairtable.yaml";
my @LANGUAGES = qw(en de);              ## defined languages

my $t_dir;            ## directory, CGI param (hidden) to identify tournament
my $t_name;           ## tournament name
my $rounds;           ## number of rounds

my $q = new CGI;      ## new CGI object

my $language = set_language();
my $action = get_action();

## checking which tournament we want to work on
unless ($q->param('t_dir')) {    ## no tournament selected
    print_error_no_tournament_selected();
    die;
} else {
    unless ($q->param('t_dir') =~ /(\w+)$/) { ## got strange dir via CGI
        print_error_no_tournament_selected();
        die;
    } else {   ## everything seems okay
        ## untainting $t_dir (securing user input)
        $t_dir = $1;
    }
}


## tournament directory we work on
my $TOURNAMENTDIR = "$TOURNAMENTBASEDIR/$t_dir";

## TODO: error handling
open (TDATA, "$TOURNAMENTDIR/$DATAFILE") || die "Couldn't open file $TOURNAMENTDIR/$DATAFILE";
while (<TDATA>) {
    if (/^tournament name: (.*)$/) {
        $t_name = $1;
    }
    if ((/^rounds: (\d+)$/) and ($1 > 2) and ($1 < 10)) {
        $rounds = $1;
    }
}
close(TDATA);

## some other variables
my $title;
my $league;     ## all players in YAML data structure
my $lineup;     ## list of all players
my $member;     ## index variable for several players within YAML data
my $message;
my $round;
my $prevround;
my %Black;
my %ResBlack;
my %White;
my %ResWhite;
my $board;
my @results;
my @scores;
my $Player;

print $q->header;            ## print HTML headers

## Read participants from .yaml-file $PARTICIPANTS
## TODO: error handling
$league = LoadFile "$TOURNAMENTDIR/$PARTICIPANTS";

if ($action eq 'manage_participants') { 
    show_page_for_managing_participants();
} elsif ($action eq 'add_participant') {
    add_participant();
    show_page_for_managing_participants();
} elsif ($action eq 'delete_participant') {
    delete_participant();
    show_page_for_managing_participants();
} elsif ($action eq 'pairings_or_results') {
    print $q->start_html( -title => loc( "(Pairings and Results)" ) ), "\n",
          $q->h1( loc( "(Pairings and Results)" ) ), "\n";
    get_round_number();
    ## get results via CGI data
    ## each result is one of "1 : 0", "= : =", "0 : 1"
    $board = 1;
    while ($q->param("Board$board")) {
        $results[$board] = $q->param("Board$board");
        $board++;
    }
    if ($q->param("Board1")) {      ## are there new results?
        read_pairings();              ## read pairings from file
        open(RESULTS, ">$TOURNAMENTDIR/$SCORES/$round.yaml");
        ## write results to file
        foreach $board (sort {$a <=> $b} keys(%White)) {
            if ($results[$board] =~ /^1 : 0$/) {
                print RESULTS "\'$White{$board}\': Win\n";
                print RESULTS "\'$Black{$board}\': Loss\n";
            } elsif ($results[$board] =~ /^= : =$/) {
                print RESULTS "\'$White{$board}\': Draw\n";
                print RESULTS "\'$Black{$board}\': Draw\n";
            } elsif ($results[$board] =~ /^0 : 1$/) {
                print RESULTS "\'$White{$board}\': Loss\n";
                print RESULTS "\'$Black{$board}\': Win\n";
            }
        }
     close(RESULTS);
    }
    if (! -e "$TOURNAMENTDIR/$round/round.yaml") {
        if ((-e "$TOURNAMENTDIR/$SCORES/$prevround.yaml") or ($round == 1)) {
            print $q->p( loc("(There are no pairings for round %1. Trying to generate them.)", $round) );
            generate_pairings();
        } else {
            print $q->p( loc("(Round %1 cannot be paired yet. Please check results of previous rounds.)", $round) );
        }
    }
    if (-e "$TOURNAMENTDIR/$round/round.yaml") {
        if (-e "$TOURNAMENTDIR/$SCORES/$round.yaml") {
            print $q->p( loc("(Results of round %1:)", $round) );
            print_results();
        } else {
            read_pairings();
            print $q->p( loc("(Please enter results of round %1:)", $round) ),
                  $q->start_form( -action => "./$CGISCRIPT",
                                  -method => 'post' );
            ## print results
            foreach $board (sort {$a <=> $b} keys(%White)) {
                print $q->p,
                      "Brett $board: $White{$board} -- $Black{$board} \n",
                      $q->popup_menu( -name => "Board$board", 
                          -values => [('1 : 0', '= : =', '0 : 1')]), "\n";
            }
            print_button_save_results();
        }
    }
    print_link_to_main_page();
    print $q->end_html;
} elsif ($action eq 'standings') {
    get_round_number();
    print $q->start_html( -title => loc("(Standings)") ), "\n",
          $q->h1( loc("(Standings)") ), "\n"; 
    run_crosstablescript();
    print_link_to_main_page();
    print $q->end_html;
} elsif ($action eq 'pairing_table') {
    get_round_number();
    print $q->start_html( -title => loc("(Pairing Table)") ), "\n",
          $q->h1( loc("(Pairing Table)") ), "\n"; 
    run_pairingtablescript();
    print_link_to_main_page();
    print $q->end_html;
} elsif ($action eq 'debug') {
    get_round_number();
    ## TODO: error handling
    open(TMPFILE, "$TOURNAMENTDIR/$round/tmpfile");
    while (<TMPFILE>) {
        print $_, $q->br;
    }
    close(TMPFILE);
    print_link_to_main_page();
    print $q->end_html;
} else {
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

=head2 Functions

=head3 Program Functions (for executing "real" program code)

=item C<set_language>

Sets language for internationalization (see above) according to CGI parameter
'lang' and returns the language. If no value is specified via CGI param, the
default value 'en' is used. 'lang' is one of ('en', 'de').

=cut

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

=item C<get_action>

Returns the 'action' parameter defined via CGI-form. 'action' is one of
('manage_participants', 'pairings_or_results', 'standings', 'pairing_table',
'debug', 'add_participant', 'delete_participant', '').

=cut

sub get_action {
    if ( $q->param('action') ) {
        return $q->param('action');
    } else {
        return 'no_action';
    }
}

=item C<run_pairingtablescript>

Print the pairing table after a given round. An external script
('pairingtable') is executed and its output is printed as preformatted text.

=cut

sub run_pairingtablescript {
    print "<pre>\n";
    ## TODO: chdir ersetzen?
    ## TODO: error handling
    chdir("$TOURNAMENTDIR");
    print `perl $PAIRINGTABLESCRIPT $round`;
    chdir("$CGIDIR");
    print "</pre>\n";
}

=item C<run_crosstablescript>

Print the crosstable after a given round. An external script ('crosstable') is
executed and its output is printed as preformatted text.

=cut

sub run_crosstablescript {
    print "<pre>\n";
    ## TODO: chdir ersetzen?
    ## TODO: error handling
    chdir("$TOURNAMENTDIR");
    print `perl $CROSSTABLESCRIPT $round`;
    chdir("$CGIDIR");
    print "</pre>\n";
}

=item C<get_round_number>

Sets round number $round according to CGI param 'round'. Value of $round is
untainted. Also sets $prevround = $round-1.

=cut

sub get_round_number {
    if ($q->param('round') =~ /(\d+)/) { $round = $1; }
    $prevround = $round-1;
}

=item C<read_pairings>

Reads pairings from $TOURNAMENTDIR/$round/round.yaml into separate hashes
%White and %Black. Keys for this hashes are the board numbers.

=cut

sub read_pairings {
	open(PAIRING,"$TOURNAMENTDIR/$round/round.yaml");
    while (<PAIRING>) {
        if (/^  (\d+):/) {        ## line with board number
            $board = $1+1;
        }
        if (/Black: '(.*)'/) {    ## player with black pieces
            $Black{$board} = $1;
        }
 		if (/White: '(.*)'/) {    ## player with white pieces
 			$White{$board} = $1;
 		}
    }
	close(PAIRING);
}

=item C<get_result>

Returns "single character value" for literal result. 
 'Win'  -> '1'
 'Draw' -> '='
 'Loss' -> '0'

=cut

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
    ## executing "pairingtable", "pairtable2yaml" and "pair"
    ## as described in README of Games::Tournament::Swiss (v0.08)
    chdir("$TOURNAMENTDIR");
    system("perl $PAIRINGTABLESCRIPT > $PAIRINGTABLE");
    system("perl $PAIRTABLE2YAMLSCRIPT $PAIRINGTABLE");
    system("cp $PAIRTABLEYAML $round/$PAIRTABLEYAML");
    ## TODO: chdir ersetzen?
    ## TODO: error handling
    chdir("$TOURNAMENTDIR/$round");
    system("perl $PAIRSCRIPT 1>tmpfile 2>&1");
    ## Use next line to log standard error only
    # system("perl $PAIRSCRIPT 2>tmpfile");
    chdir("$CGIDIR");
}

## subroutine to sort players according to rating and 
## assign pairingnumbers
## TODO: Is there a cleaner way to do this?
sub sort_and_assign_pairingnumbers {
    my $players = shift;
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

## this subroutine adds a new participant to file $PARTICIPANTS
## and returns a message which player was added
sub add_participant {
    if ($q->param('firstname') and $q->param('surname')) {
        ## get highest ID of "old" players
        my $maxid = 0;
        for $member ( @{$league->{member} } ) {
            if ($member->{id} >= $maxid) { $maxid = $member->{id}; }
        }
        $maxid++;
        ## TODO: securing input?
        ## add data for new player (yaml data structure)
        ## to list of players $league
        my $new_player = { 
            id => $maxid, 
            name => $q->param('surname') . ", " . $q->param('firstname'),
            rating => $q->param('dwz') };
        push @{$league->{member} }, $new_player;
        $league = sort_and_assign_pairingnumbers($league);
        ## save list of all players to $PARTICIPANTS
        DumpFile("$TOURNAMENTDIR/$PARTICIPANTS", $league);
    } else { 
        ## incomplete data via CGI form
        print $q->p( "Angaben unvollständig. Bitte Vor- 
            und Nachnamen eingeben!" );
    }
}

## this subroutine adds a new participant to file $PARTICIPANTS
## and returns a message which player was added
sub delete_participant {
	for $member ( @{$league->{member} } ) {
	    unless ($member->{id} eq $q->param('id')) {
            push @$lineup, $member;
        }
    }
    ## put players from $lineup in YAML data structure
    $league = { member => $lineup };
    $league = sort_and_assign_pairingnumbers($league);
    ## save list of all players to $PARTICIPANTS
    DumpFile("$TOURNAMENTDIR/$PARTICIPANTS", $league);
}

=head3 Output Functions (for printing HTML code)

=item C<print_button_save_results>

Prints a button to save the results.

=cut

sub print_button_save_results {
    print $q->p,
          $q->hidden( -name => 'action', 
                       -default => 'pairings_or_results' ), "\n",
          $q->hidden( -name => 't_dir', 
                       -default => "$t_dir" ), "\n",
          $q->hidden( -name => 'round', 
                       -default => "$round" ), "\n",
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc( "(save results)" ) ), "\n",
          $q->end_form, "\n";
}

## subroutine to print results
sub print_results {
	open(RESULTS,"$TOURNAMENTDIR/$SCORES/$round.yaml");
		@scores = <RESULTS>;
	close(RESULTS);
	open(PAIRING,"$TOURNAMENTDIR/$round/round.yaml");
	while (<PAIRING>) {
        if (/^  (\d+):/) {          ## line with board number
            $board = $1+1;
        }
        if (/Black: '(.*)'/) {      ## player with black pieces
            $Black{$board} = $1;
            $ResBlack{$board} = get_result($Black{$board});
        }
        if (/White: '(.*)'/) {      ## player with white pieces
            $White{$board} = $1;
            $ResWhite{$board} = get_result($White{$board});
        }
    }
    foreach $board (sort {$a <=> $b} keys(%White)) {
		print $q->p( loc("(Board)"), " $board: $White{$board} -- $Black{$board} 
                                  $ResWhite{$board} : $ResBlack{$board}" );
    }
}


## this subroutine displays the main page for management of participants
## it includes a form to add a new participant, 
## a list of all actual participants
## and finally buttons to delete them
sub show_page_for_managing_participants {
    print $q->start_html( -title => loc("(Participants)") ), "\n",
          $q->h1( loc("(Manage participants for tournament %1)", $t_name) ),
          "\n", $q->hr, "\n";
    display_form_for_new_participant();
    display_participants();
    print_link_to_main_page();
    print $q->end_html;
}

## this subroutine displays a CGI form for a new participant
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

## print relevant data for all participants
## also print a "delete" button for each participant
sub display_participants {
    print $q->h3 ( loc("(List of Participants)") ), "\n";
    print $q->start_table( { -border => 2, -cellpadding => 4, 
                             -cellspacing => 2 } ), "\n",
          $q->Tr( [ $q->th ( [ loc("(Nr.)"), loc("(Name)"), loc("(Rating)"), '' ] ) ] ), "\n";
    for $member ( @{$league->{member} } ) {
        print $q->start_TR,
              $q->td( "$member->{pairingnumber}"),
              $q->td( "$member->{name}"),
              $q->td( "$member->{rating}"),
              $q->start_td, "\n",
              $q->start_form ( -action => "./$CGISCRIPT",
                               -method => 'post' ), "\n",
              $q->hidden( -name => 'action', -default => 'delete_participant',
                          -override => 'true' ), "\n",
              $q->hidden( -name => 't_dir', -default => "$t_dir" ), "\n",
              $q->hidden( -name => 'id', -default => "$member->{id}",
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

## print link to main page
sub print_link_to_main_page {
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

## print link to page for tournament selection
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

=item C<print_language_menu>

Prints a "select language" menu as a CGI form. Available values are presented
as a dropdown menu and are taken from @LANGUAGES. CGI paramter 'lang' is set
to selected language.

=cut

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
    print $q->h3( loc("(Output of script pair -- for debugging purposes)") ),
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

=head1 AUTHOR

Bartolin

=cut

# vim: set tw=78 ts=4 sw=4 et:
