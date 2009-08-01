#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

select_tournament.pl

=head1 VERSION

Version 0.06

=head1 DESCRIPTION

This small CGI script is part of a project to create a perl-based web
interface for management of swiss chess tournaments. It is used for setting up
new tournaments and selecting/deleting existing tournaments.

=head1 DOCUMENTATION

=head2 Setup

=over 8

Adjust the following settings for your site.

=item C<$TOURNAMENTBASEDIR>

Set the directory where tournaments are stored.

$TOURNAMENTBASEDIR = '/path/to/directory/with/tournaments';

=cut

my $TOURNAMENTBASEDIR = '/home/pacs/mih01/users/cb02/doms/aglaz.de/subs/www/swiss-pairing/tournaments';
# my $TOURNAMENTBASEDIR = '/home/christian/public_html/pairing';

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

=item C<Locale::Maketext::Simple>

Used for internationalization. (See I18n below.)

=back

=cut

use CGI qw(:standard);
use Locale::Maketext::Simple (   ## i18n, 'perldoc Locale::Maketext::Simple'
    Path => './language_files',
    Style => 'gettext'
);

=head2 I18n

=over 8

The script uses Locale::Maketext::Simple for internationalization. 

Language files like 'en.po' or 'de.po' are in the subdirectory
'./language_files'. For more informations see
http://search.cpan.org/~audreyt/Locale-Maketext-Simple-0.18/

=back

=cut

my $CGISCRIPT = 'tournament.pl';        ## CGI script to manage tournament
my $CGISELECT = 'select_tournament.pl'; ## CGI script to select tournament
my $DATAFILE = 'tournament_data';       ## contains tournament data
my $PARTICIPANTS = 'league.yaml';       ## file with participants
my $SCORES = 'scores';                  ## directory to save scores
my $PASSWORD = 'temp';                  ## password for deleting tournament
my @LANGUAGES = qw(en de);              ## defined languages

my $t_dir;                              ## directory of new tournament
my $t_name;                             ## name of new tournament
my $rounds;                             ## number of rounds of new tournament

my $q = CGI->new();       ## new CGI object

print $q->header;         ## print HTML header

my @tournaments = get_tournaments();
my $language = set_language();
my $action = get_action();

if ($action eq 'create') {
    unless ( create_params_okay() ) {
        print_error_bad_create_params();
    } else {   
        ($t_dir, $t_name, $rounds) = get_create_params();
        if (-e "$TOURNAMENTBASEDIR/$t_dir") {
            print_error_tournament_exists();
        } else { 
            create_tournament();
            print_confirmation_successful_setup();
        }
    }
} elsif ($action eq 'delete') {
    unless ( password_okay() ) {
        print_error_wrong_password();
    } else {
        unless ( delete_params_okay() ) {
            print_problems_deleting_tournament();
        } else {
            $t_dir = get_delete_params();
            delete_tournament();
            print_confirmation_tournament_deleted();
        }
    }
} else { 
    print $q->start_html( -title => loc( "(Select tournament)" ) );
    print_language_menu();
    print_new_tournament_menu();
    print_select_tournament_menu();
    print_delete_tournament_menu();
    print $q->end_html;
}

=head2 Functions

=head3 Program Functions (for executing "real" program code)

=item C<get_tournaments>

Returns a list with existing tournaments in $TOURNAMENTBASEDIR. Used for tournament
selection.

=cut

sub get_tournaments {
    my @tm;
    for ( glob "$TOURNAMENTBASEDIR/*" ) { 
        $_ =~ s#.*/##;   ## remove part of filename before last slash
        if ( ( -d "$TOURNAMENTBASEDIR/$_" ) and ( $_ ne 'language_files' ) ) {
            push( @tm, $_ ); 
        }
    }
    return @tm;
}

=item C<get_action>

Returns the 'action' parameter defined via CGI-form. 'action' is one of
('create', 'delete', '').

=cut

sub get_action {
    if ( $q->param('action') ) { 
        return $q->param('action');
    } else {
        return 'no_action';
    }
}

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

=item C<create_params_okay>

Checks whether values for tournament creation are complete and sane. If so,
returns 1. If not, returns 0.

=cut

sub create_params_okay {
    if (($q->param('t_name')) 
             and ($q->param('t_rounds')) 
             and ($q->param('t_rounds') =~ /^(\d+)$/)
             and ($q->param('t_rounds') > 2 )
             and ($q->param('t_rounds') < 10 )
             and ($q->param('t_dir')) 
             and ($q->param('t_dir') =~/(\w+)$/)) {
         return 1;    
     } else {
         return 0;
     }
}

=item C<get_create_params>

Returns values for tournament creation for list ($t_dir, $t_name, $rounds).
Value for $t_dir is untainted.

=cut

sub get_create_params {
    my $directory;
    if ($q->param('t_dir') =~/(\w+)$/) { 
        $directory = $1;
    }
    my @params = ($directory, $q->param('t_name'), $q->param('t_rounds'));
    return @params;
}

=item C<create_tournament>

Creates directory $TOURNAMENTBASEDIR/$t_dir with tournament data. In particular the
following files and directories are created:
 * file 'tournament_data' containing infos about the tournament
 * empty file 'league.yaml' for data of participants
 * empty directory 'scores' for score files of single rounds
 * empty directories '1 .. $rounds' for single rounds

=cut

sub create_tournament {
    ## TODO: weitere Tests (z.B. Schreibrechte etc.)
    ## TODO: error handling
    mkdir("$TOURNAMENTBASEDIR/$t_dir") 
        || die "Couldn't create directory $TOURNAMENTBASEDIR/$t_dir!\n";
    open(TDATA, ">$TOURNAMENTBASEDIR/$t_dir/$DATAFILE") 
        || die "Couldn't open file $TOURNAMENTBASEDIR/$t_dir/$DATAFILE!\n";
    print TDATA "tournament name: $t_name\n";
    print TDATA "directory: $t_dir\n";
    print TDATA "rounds: $rounds\n";
    close(TDATA);
    system("touch $TOURNAMENTBASEDIR/$t_dir/$PARTICIPANTS");
    mkdir("$TOURNAMENTBASEDIR/$t_dir/$SCORES");
    for (1 .. $rounds) { mkdir ("$TOURNAMENTBASEDIR/$t_dir/$_"); }
}

=item C<password_okay>

Checks whether password is correct. If so, returns 1. If not, returns 0.

=cut

sub password_okay {
    if (($q->param('password')) and ($q->param('password') eq $PASSWORD)) {
        return 1;
    } else {
        return 0;
    }
}

=item C<delete_params_okay>

Checks whether values for tournament deletion are complete and sane. If so,
returns 1. If not, returns 0.

=cut

sub delete_params_okay {
    my $directory;
    if ( ($q->param('t_dir')) and ($q->param('t_dir') =~/(\w+)$/)
          and (-d "$TOURNAMENTBASEDIR/$1")) {
        return 1;    
     } else {
        return 0;
     }
}

=item C<get_delete_params>

Returns untainted value of $t_dir for tournament deletion. 

=cut

sub get_delete_params {
    my $directory;
    if ($q->param('t_dir') =~/(\w+)$/) { 
        $directory = $1;
    }
    return ($directory);
}

=item C<delete_tournament>

Deletes directory $t_dir with tournament data from $TOURNAMENTBASEDIR.

=cut

sub delete_tournament {
    ## TODO: error handling
    open (TDATA, "$TOURNAMENTBASEDIR/$t_dir/$DATAFILE") || die "Couldn't open file $TOURNAMENTBASEDIR/$t_dir/$DATAFILE";
    while (<TDATA>) {
        if (/^tournament name: (.*)$/) {
            $t_name = $1;
        }
    }
    close (TDATA);
    system("rm -rf $TOURNAMENTBASEDIR/$t_dir");
}

=head3 Output Functions (for printing HTML code)

=item C<print_button_to_tournament_selection>

Prints simple button 'back to tournament selection'.

=cut

sub print_button_to_tournament_selection {
    print $q->hr, "\n",
          $q->start_form( -action => "./$CGISELECT", 
                          -method => 'post'),
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc("(back to tournament selection)") ), "\n",
          $q->end_form, "\n";
}

=item C<print_confirmation_tournament_deleted>

Prints confirmation page in HTML that tournament was deleted.

=cut

sub print_confirmation_tournament_deleted {
    print $q->start_html( loc("(Tournament deleted)") ),
          $q->h3( loc("(Tournament deleted)") ), "\n",
          $q->p( { -style => 'color:red' },
                 loc("(Tournament %1 has been successfully deleted.)",
                 $q->b( "$t_name" ))), "\n";
    print_button_to_tournament_selection();
    print $q->end_html;
}

=item C<print_problems_deleting_tournament>

Prints error page in HTML that tournament couldn't be deleted.

=cut

sub print_problems_deleting_tournament {
    print $q->start_html( loc("(Deletion of tournament failed)") ),
          $q->h3( loc("(Deletion of tournament failed)") ), "\n",
          $q->p( loc("(The selected tournament doesn't exist or it was not possible to delete it.)") ),
          "\n",
          $q->p( loc("(Please retry.)") ), "\n",
          $q->hr, "\n";
    print_button_to_tournament_selection();
    print $q->end_html;
}

=item C<print_error_wrong_password>

Prints error page in HTML complaining about wrong password for tournament
deletion.

=cut

sub print_error_wrong_password {
    print $q->start_html( loc("(Deletion of tournament failed)") ),
          $q->h3( loc("(Deletion of tournament failed)") ), "\n",
          $q->p( loc("(Invalid password.)") ), "\n",
          $q->p( loc("(Please retry.)") ), "\n";
    print_button_to_tournament_selection();
    print $q->end_html;
}

=item C<print_error_tournament_exists>

Prints error page in HTML, complaining that there already exists a tournament
under the directory given.

=cut

sub print_error_tournament_exists {
    print $q->start_html( loc("(Creation of tournament failed)") ),
          $q->h3( loc("(Creation of tournament failed)") ), "\n",
          $q->p( loc("(Failed to create new tournament at directory %1.)",
                  $q->b( "$t_dir" )), loc("(There already exists a file or a directory with this name.)")),
          "\n",
          $q->p( loc("(Please choose another directory.)") ), "\n";
    print_button_to_tournament_selection();
    print $q->end_html;
}

=item C<print_error_bad_create_params>

Prints error page in HTML, complaining about incomplete or wrong values for
tournament creation.

=cut

sub print_error_bad_create_params {
    print $q->start_html( loc("(Creation of tournament failed)") ),
          $q->h3( loc("(Creation of tournament failed)") ), "\n",
          $q->p( loc("(Tournament data (tournament name, directory or number of rounds) was incomplete or wrong.)") ),
          "\n",
          $q->p( loc("(Please retry.)") ), "\n";
    print_button_to_tournament_selection();
    print $q->end_html;
}

=item C<print_confirmation_successful_setup>

Prints confirmation page in HTML that tournament was created successfully.
Contains button 'Manage tournament' which links to second script $CGISCRIPT.

=cut

sub print_confirmation_successful_setup {
    print $q->start_html( loc("(New tournament created)") ),
          $q->h3( loc("(New tournament created)") ), "\n",
          $q->p( loc("(Tournament %1 with %2 rounds has been created in directory %3.)", $q->b("$t_name"), $q->b("$rounds"), $q->b ("$t_dir"))),
          "\n",
          $q->hr,
          $q->start_form( -method => 'post',
                          -action => "./$CGISCRIPT" ),
          $q->hidden( -name => 't_dir', -default => "$t_dir",
                      -override => 'true' ), "\n",
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc("(Manage tournament)") ), "\n",
          $q->end_form,
          $q->end_html;
}

=item C<print_new_tournament_menu>

Prints a H3 heading and a set of CGI forms for tournament creation. Requested
values are 'tournament name', 'directory for tournament data' and 'number of
rounds. After successfully creating a new tournament, one gets directed to
another script ($CGISCRIPT). CGI parameter 'action' is set to 'create'.

=cut

sub print_new_tournament_menu {
    print $q->h3( loc("(Create new tournament)") ), "\n",
          $q->start_form( -method => 'post',
                          -action => "./$CGISELECT" ),
          $q->p( loc("(tournament name:)"), 
                  $q->br, "\n",
                  $q->textarea( -name => 't_name',
                                -cols => '40',
                                -rows => '1')), "\n",
          $q->p( loc("(directory for tournament data:)"), 
                  $q->br, "\n",
                  $q->textarea( -name => 't_dir',
                                -cols => '40',
                                -rows => '1')), "\n",
          $q->p( loc("(number of rounds:)"),
                  $q->br, "\n",
                  $q->popup_menu ( -name => 't_rounds', 
                                   -values => [qw(3 4 5 6 7 8 9)] )), "\n",
          $q->p( loc("(click here to submit data:)"), "\n",
                  $q->hidden( -name => 'action', -default => 'create',
                              -override => 'true' ), "\n",
                  $q->hidden( -name => 'lang', -default => "$language",
                              -override => 'true' ), "\n",
                  $q->submit( -value => loc("(create tournament)") )), "\n",
          $q->end_form, "\n";
}

=item C<print_select_tournament_menu>

Prints a H3 heading, a short description and a CGI form for tournament
selection. Available values are presented as a dropdown menu and are taken from
@tournaments. Selected tournament is handled via another script ($CGISCRIPT).

=cut

sub print_select_tournament_menu {
    print $q->hr, "\n",
          $q->h3( loc("(Select tournament)") ), "\n",
          $q->p( loc("(You can select one of the existing tournaments to manage it:)") ),
          "\n",
          $q->start_form( -method => 'post',
                          -action => "./$CGISCRIPT" ),
          $q->popup_menu ( -name => 't_dir',
                           -values => [@tournaments] ), "\n",
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc("(select tournament)") ), "\n",
          $q->end_form, "\n",
          $q->end_html;
}

=item C<print_delete_tournament_menu>

Prints a H3 heading, a short description and a CGI form for tournament
deletion. Available values are presented as a dropdown menu and are taken from
@tournaments. Deletion is password protected -- password is defined as
$PASSWORD. CGI parameter 'action' is set to 'delete'.

=cut

sub print_delete_tournament_menu {
    print $q->hr, "\n",
          $q->h3( { -style => 'color:red' }, loc("(Delete tournament)") ),
          "\n",
          $q->p( { -style => 'color:red' },
                 loc("(You can delete one of the existing tournaments:)") ),
          "\n",
          $q->p( $q->start_form( -method => 'post',
                                 -action => "./$CGISELECT" ),
                 $q->popup_menu ( -name => 't_dir',
                                  -values => [@tournaments] ),
                 loc("(password:)"),
                 $q->password_field( -name => 'password' ),
                 $q->hidden( -name => 'action', -default => 'delete',
                             -override => 'true' ),
                 $q->hidden( -name => 'lang', -default => "$language",
                             -override => 'true' ), "\n",
                 $q->submit( -value => loc("(delete tournament)") ),
                 $q->end_form), "\n";
}

=item C<print_language_menu>

Prints a "select language" menu as a CGI form. Available values are presented
as a dropdown menu and are taken from @LANGUAGES. CGI paramter 'lang' is set
to selected language.

=cut

sub print_language_menu {
    print $q->start_form( -method => 'post',
                          -action => "./$CGISELECT" ),
          $q->popup_menu ( -name => 'lang',
                           -values => [@LANGUAGES] ),
          $q->submit( -value => loc("(select language)") ),
          $q->end_form, $q->hr, "\n";
}

=head1 AUTHOR

Bartolin

=cut
