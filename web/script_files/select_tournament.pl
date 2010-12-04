#!/usr/bin/perl -w

use strict;
use warnings;

use version; our $VERSION = qv('0.0.8');

use Readonly;

## some constants

## TODO: adjust this for your site!
## directory which contains different tournaments
# Readonly my $TOURNAMENTBASEDIR => '/home/pacs/mih01/users/cb02/doms/aglaz.de/subs/www/swiss-pairing/tournaments';

Readonly my $TOURNAMENTBASEDIR => '/home/greg/public_html/pairing';

Readonly my $EMPTY_STR => q{};

## CGI script to manage tournament
Readonly my $CGISCRIPT => 'tournament.pl';
## CGI script to select tournament
Readonly my $CGISELECT => 'select_tournament.pl';
## file with tournament data
Readonly my $DATAFILE  => 'tournament_data';
## password for deleting tournament
Readonly my $PASSWORD  => 'temp';
## defined languages
Readonly my @LANGUAGES => qw(en de);
## directory with language files
Readonly my $DIR_WITH_LANGUAGE_FILES => 'language_files';

my $t_dir;             ## directory of new tournament
my $t_name;            ## name of new tournament
my $total_rounds;      ## number of rounds of new tournament

## TODO: adjust this for your site!
# use lib qw(/home/pacs/mih01/users/cb02/lib);

use CGI qw(:standard);
## TODO: disable this for productive use
use CGI::Carp qw(fatalsToBrowser);
## i18n, 'perldoc Locale::Maketext::Simple'
use Locale::Maketext::Simple (
    Path  => './language_files',
    Style => 'gettext',
);

my $q = CGI->new();    ## new CGI object

## print HTML header
print $q->header;

my @dirs_with_tournaments = get_list_of_dirs_of_existing_tournaments();
my $language              = set_language(get_param('lang'));
my $action                = get_param('action');

if ($action eq 'create') {
    if ( create_params_are_valid() ) {
        ($t_dir, $t_name, $total_rounds) = get_create_params();
        if (! -e "$TOURNAMENTBASEDIR/$t_dir") {
            create_tournament();
            print_confirmation_successful_setup();
        }
        else {
            print_error_tournament_exists();
        }
    }
    else {
        print_error_bad_create_params();
    }
}
elsif ($action eq 'delete') {
    if ( password_is_valid() ) {
        if ( delete_params_are_valid() ) {
            $t_dir = get_delete_params();
            delete_tournament();
            print_confirmation_tournament_deleted();
        }
        else {
            print_problems_deleting_tournament();
        }
    }
    else {
        print_error_wrong_password();
    }
}
else {
    print $q->start_html( -title => loc( '(Select tournament)' ) );
    print_language_menu();
    print_new_tournament_menu();
    print_select_tournament_menu();
    print_delete_tournament_menu();
    print $q->end_html;
}

sub get_list_of_dirs_of_existing_tournaments {
    my @dirs_of_existing_tournaments;

    ## record tournaments (they reside in sub dirs of $TOURNAMENTBASEDIR)
    CHECK:
    foreach my $dir_with_tournament ( glob "$TOURNAMENTBASEDIR/*" ) {
        ## remove part of filename before last slash
        $dir_with_tournament =~ s{.*/}{$EMPTY_STR}xms;

        ## skip the sub directory for language files!
        if ( $dir_with_tournament eq $DIR_WITH_LANGUAGE_FILES ) {
            next CHECK;
        }

        ## record all other sub directories as tournament directories
        if ( -d "$TOURNAMENTBASEDIR/$dir_with_tournament" ) {
            push @dirs_of_existing_tournaments, $dir_with_tournament;
        }
    }

    ## return list of dirs of existing tournament
    return @dirs_of_existing_tournaments;
}

## return given parameters or empty string
sub get_param {
    my $parameter = shift;
    if ( $q->param($parameter) ) {
        return $q->param($parameter);
    } else {
        return $EMPTY_STR;
    }
}

## set language for Locale::Maketext::Simple -- defaults to 'en'
sub set_language {
    my $lang = shift;

    ## at the moment we have only 'de' und 'en' (the latter is a default)
    if ( $lang ne 'de' ) {
        $lang = 'en';
    }

    ## set language via Locale::Maketext::Simple and return language
    loc_lang($lang);
    return $lang;
}

sub create_params_are_valid {
    if (($q->param('t_name'))
             and ($q->param('t_rounds'))
             and ($q->param('t_rounds') =~ /^(\d+)$/xms)
             and ($q->param('t_rounds') > 2 )
             and ($q->param('t_rounds') < 10 )
             and ($q->param('t_dir'))
             and ($q->param('t_dir') =~/(\w+)$/xms)) {
         return 1;
     } else {
         return 0;
     }
}

sub get_create_params {
    my $directory;
    if ($q->param('t_dir') =~/(\w+)$/xms) {
        $directory = $1;
    }
    my @params = ($directory, $q->param('t_name'), $q->param('t_rounds'));
    return @params;
}

sub get_t_data_for_output {
    my $t_name       = shift;
    my $t_dir        = shift;
    my $total_rounds = shift;

    return <<"END_OF_TOURNAMENT_DATA";
tournament name: $t_name
directory: $t_dir
rounds: $total_rounds
status: tournament created
END_OF_TOURNAMENT_DATA
}

sub create_tournament {
    ## TODO: weitere Tests (z.B. Schreibrechte etc.)
    mkdir "$TOURNAMENTBASEDIR/$t_dir"
        or croak "Couldn't create directory $TOURNAMENTBASEDIR/$t_dir!";
    open my $DATAFILE, '>', "$TOURNAMENTBASEDIR/$t_dir/$DATAFILE"
        or croak "Couldn't open file $TOURNAMENTBASEDIR/$t_dir/$DATAFILE!";
    print {$DATAFILE} get_t_data_for_output($t_name,$t_dir,$total_rounds)
        or croak "Couldn't write file $TOURNAMENTBASEDIR/$t_dir/$DATAFILE!";
    close $DATAFILE
        or croak "Couldn't close file $TOURNAMENTBASEDIR/$t_dir/$DATAFILE!";
    return;
}

sub password_is_valid {
    ## is a valid password specified via CGI Form?
    if (($q->param('password')) and ($q->param('password') eq $PASSWORD)) {
        return 1;
    } else {
        return 0;
    }
}

sub delete_params_are_valid {
    if ( ($q->param('t_dir')) and ($q->param('t_dir') =~ /(\w+)$/xms)
          and (-d "$TOURNAMENTBASEDIR/$1")) {
        return 1;
     } else {
        return 0;
     }
}

sub get_delete_params {
    my $directory;
    if ($q->param('t_dir') =~/(\w+)$/xms) {
        $directory = $1;
    }
    return ($directory);
}

sub delete_tournament {
    ## TODO: weitere Tests (z.B. Schreibrechte etc.)
    ## TODO: error handling
    open my $DATAFILE, '<', "$TOURNAMENTBASEDIR/$t_dir/$DATAFILE"
        or croak "Couldn't open file $TOURNAMENTBASEDIR/$t_dir/$DATAFILE";
    while (my $line = <$DATAFILE>) {
        if ( $line =~ /\Atournament\sname:\s(.*)\z/xms ) {
            $t_name = $1;
        }
    }
    close $DATAFILE
        or croak "Couldn't close file $TOURNAMENTBASEDIR/$t_dir/$DATAFILE";
    system "rm -rf $TOURNAMENTBASEDIR/$t_dir";
    return;
}

sub print_button_to_tournament_selection {
    print $q->hr, "\n",
          $q->start_form( -action => "./$CGISELECT",
                          -method => 'post'),
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc('(back to tournament selection)') ), "\n",
          $q->end_form, "\n";
    return;
}

sub print_confirmation_tournament_deleted {
    print $q->start_html( loc('(Tournament deleted)') ),
          $q->h3( loc('(Tournament deleted)') ), "\n",
          $q->p( { -style => 'color:red' },
                 loc('(Tournament %1 has been successfully deleted.)',
                 $q->b( "$t_name" ))), "\n";
    print_button_to_tournament_selection();
    print $q->end_html;
    return;
}

sub print_problems_deleting_tournament {
    print $q->start_html( loc('(Deletion of tournament failed)') ),
          $q->h3( loc('(Deletion of tournament failed)') ), "\n",
          $q->p( loc('(The selected tournament does not exist or it was not possible to delete it.)') ),
          "\n",
          $q->p( loc('(Please retry.)') ), "\n",
          $q->hr, "\n";
    print_button_to_tournament_selection();
    print $q->end_html;
    return;
}

sub print_error_wrong_password {
    print $q->start_html( loc('(Deletion of tournament failed)') ),
          $q->h3( loc('(Deletion of tournament failed)') ), "\n",
          $q->p( loc('(Invalid password.)') ), "\n",
          $q->p( loc('(Please retry.)') ), "\n";
    print_button_to_tournament_selection();
    print $q->end_html;
    return;
}

sub print_error_tournament_exists {
    print $q->start_html( loc('(Creation of tournament failed)') ),
          $q->h3( loc('(Creation of tournament failed)') ), "\n",
          $q->p( loc('(Failed to create new tournament at directory %1.)',
                  $q->b( "$t_dir" )), loc('(There already exists a file or a directory with this name.)')),
          "\n",
          $q->p( loc('(Please choose another directory.)') ), "\n";
    print_button_to_tournament_selection();
    print $q->end_html;
    return;
}

sub print_error_bad_create_params {
    print $q->start_html( loc('(Creation of tournament failed)') ),
          $q->h3( loc('(Creation of tournament failed)') ), "\n",
          $q->p( loc('(Tournament data (tournament name, directory or number of rounds) was incomplete or wrong.)') ),
          "\n",
          $q->p( loc('(Please retry.)') ), "\n";
    print_button_to_tournament_selection();
    print $q->end_html;
    return;
}

sub print_confirmation_successful_setup {
    print $q->start_html( loc('(New tournament created)') ),
          $q->h3( loc('(New tournament created)') ), "\n",
          $q->p( loc('(Tournament %1 with %2 rounds has been created in directory %3.)', $q->b("$t_name"), $q->b("$total_rounds"), $q->b ("$t_dir"))),
          "\n",
          $q->hr,
          $q->start_form( -method => 'post',
                          -action => "./$CGISCRIPT" ),
          $q->hidden( -name => 't_dir', -default => "$t_dir",
                      -override => 'true' ), "\n",
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc('(Manage tournament)') ), "\n",
          $q->end_form,
          $q->end_html;
    return;
}

sub print_new_tournament_menu {
    print $q->h3( loc('(Create new tournament)') ), "\n",
          $q->start_form( -method => 'post',
                          -action => "./$CGISELECT" ),
          $q->p( loc('(tournament name:)'),
                  $q->br, "\n",
                  $q->textarea( -name => 't_name',
                                -cols => '40',
                                -rows => '1')), "\n",
          $q->p( loc('(directory for tournament data:)'),
                  $q->br, "\n",
                  $q->textarea( -name => 't_dir',
                                -cols => '40',
                                -rows => '1')), "\n",
          $q->p( loc('(number of rounds:)'),
                  $q->br, "\n",
                  $q->popup_menu ( -name => 't_rounds',
                                   -values => [qw(3 4 5 6 7 8 9)] )), "\n",
          $q->p( loc('(click here to submit data:)'), "\n",
                  $q->hidden( -name => 'action', -default => 'create',
                              -override => 'true' ), "\n",
                  $q->hidden( -name => 'lang', -default => "$language",
                              -override => 'true' ), "\n",
                  $q->submit( -value => loc('(create tournament)') )), "\n",
          $q->end_form, "\n";
    return;
}

sub print_select_tournament_menu {
    print $q->hr, "\n",
          $q->h3( loc('(Select tournament)') ), "\n",
          $q->p( loc('(You can select one of the existing tournaments to manage it:)') ),
          "\n",
          $q->start_form( -method => 'post',
                          -action => "./$CGISCRIPT" ),
          $q->popup_menu ( -name => 't_dir',
                           -values => [@dirs_with_tournaments] ), "\n",
          $q->hidden( -name => 'lang', -default => "$language",
                      -override => 'true' ), "\n",
          $q->submit( -value => loc('(select tournament)') ), "\n",
          $q->end_form, "\n",
          $q->end_html;
    return;
}

sub print_delete_tournament_menu {
    print $q->hr, "\n",
          $q->h3( { -style => 'color:red' }, loc('(Delete tournament)') ),
          "\n",
          $q->p( { -style => 'color:red' },
                 loc('(You can delete one of the existing tournaments:)') ),
          "\n",
          $q->p( $q->start_form( -method => 'post',
                                 -action => "./$CGISELECT" ),
                 $q->popup_menu ( -name => 't_dir',
                                  -values => [@dirs_with_tournaments] ),
                 loc('(password:)'),
                 $q->password_field( -name => 'password' ),
                 $q->hidden( -name => 'action', -default => 'delete',
                             -override => 'true' ),
                 $q->hidden( -name => 'lang', -default => "$language",
                             -override => 'true' ), "\n",
                 $q->submit( -value => loc('(delete tournament)') ),
                 $q->end_form), "\n";
    return;
}

sub print_language_menu {
    print $q->start_form( -method => 'post',
                          -action => "./$CGISELECT" ),
          $q->popup_menu ( -name => 'lang',
                           -values => [@LANGUAGES] ),
          $q->submit( -value => loc('(select language)') ),
          $q->end_form, $q->hr, "\n";
    return;
}

__END__


##############################################################################
##    POD for perl applications                                             ##
##    Derived from Example 7.2 from Chapter 7 of "Perl Best Practices"      ##
##    by Damian Conway. Copyright (c) O'Reilly & Associates, 2005.          ##
##############################################################################

=head1 NAME

select_tournament.pl

=head1 VERSION

Version 0.0.7

=head1 USAGE

TODO: Ausfüllen

=head1 DESCRIPTION

This small CGI script is part of a project to create a perl-based web
interface for management of swiss chess tournaments. It is used for setting up
new tournaments and selecting/deleting existing tournaments.

=head1 DOCUMENTATION

=head2 REQUIRED ARGUMENTS

Required arguments

=head2 OPTIONS

Available options

=head2 SETUP

=over 8

Adjust the following settings for your site.

=item C<$TOURNAMENTBASEDIR>

Set the directory where tournaments are stored.

$TOURNAMENTBASEDIR = '/path/to/directory/with/tournaments';

=item C<Local Modules>

Set the directory where perl modules are installed. Only needed if you
installed modules in non standard directories (e.g. because you didn't have
permissions to installed them system wide).

use lib qw(/path/to/modules/directory);

=head2 MODULES

The script depends on the following modules.

=item C<CGI>

Needed because the script is used via a web frontend.

=item C<CGI::Carp>

Used to redirect error messages (in this case, fatalsToBrowser is used and so
fatal errors are printed to the Browser. Warning: This is not safe, since it
reveals details about the programm!

=item C<Locale::Maketext::Simple>

Used for internationalization. (See I18n below.)

=head2 I18n

The script uses Locale::Maketext::Simple for internationalization.

Language files like 'en.po' or 'de.po' are in the subdirectory
'./language_files'. For more informations see
http://search.cpan.org/~audreyt/Locale-Maketext-Simple-0.18/

=head2 Functions

=head3 Program Functions (for executing "real" program code)

=item C<get_list_of_dirs_of_existing_tournaments>

Returns a list with existing tournaments in $TOURNAMENTBASEDIR. Used for tournament
selection.

=item C<set_language>

Sets language for internationalization (see above) according to CGI parameter
'lang' and returns the language. If no value is specified via CGI param, the
default value 'en' is used. 'lang' is one of ('en', 'de').

=item C<create_params_okay>

Checks whether values for tournament creation are complete and sane. If so,
returns 1. If not, returns 0.

=item C<get_create_params>

Returns values for tournament creation for list ($t_dir, $t_name, $total_rounds).
Value for $t_dir is untainted.

=item C<create_tournament>

Creates directory $TOURNAMENTBASEDIR/$t_dir with tournament data. In particular the
following files and directories are created:
 * file 'tournament_data' containing infos about the tournament

=item C<password_is_valid>

Checks whether password is correct. If so, returns 1. If not, returns 0.

=item C<delete_params_are_valid>

Checks whether values for tournament deletion are complete and sane. If so,
returns 1. If not, returns 0.

=item C<get_delete_params>

Returns untainted value of $t_dir for tournament deletion.

=item C<delete_tournament>

Deletes directory $t_dir with tournament data from $TOURNAMENTBASEDIR.

=head3 Output Functions (for printing HTML code)

=item C<print_button_to_tournament_selection>

Prints simple button 'back to tournament selection'.

=item C<print_confirmation_tournament_deleted>

Prints confirmation page in HTML that tournament was deleted.

=item C<print_problems_deleting_tournament>

Prints error page in HTML that tournament couldn't be deleted.

=item C<print_error_wrong_password>

Prints error page in HTML complaining about wrong password for tournament
deletion.

=item C<print_error_tournament_exists>

Prints error page in HTML, complaining that there already exists a tournament
under the directory given.

=item C<print_error_bad_create_params>

Prints error page in HTML, complaining about incomplete or wrong values for
tournament creation.

=item C<print_confirmation_successful_setup>

Prints confirmation page in HTML that tournament was created successfully.
Contains button 'Manage tournament' which links to second script $CGISCRIPT.

=item C<print_new_tournament_menu>

Prints a H3 heading and a set of CGI forms for tournament creation. Requested
values are 'tournament name', 'directory for tournament data' and 'number of
rounds. After successfully creating a new tournament, one gets directed to
another script ($CGISCRIPT). CGI parameter 'action' is set to 'create'.

=item C<print_select_tournament_menu>

Prints a H3 heading, a short description and a CGI form for tournament
selection. Available values are presented as a dropdown menu and are taken from
@dirs_with_tournaments. Selected tournament is handled via another script ($CGISCRIPT).

=item C<print_delete_tournament_menu>

Prints a H3 heading, a short description and a CGI form for tournament
deletion. Available values are presented as a dropdown menu and are taken from
@dirs_with_tournaments. Deletion is password protected -- password is defined as
$PASSWORD. CGI parameter 'action' is set to 'delete'.

=item C<print_language_menu>

Prints a "select language" menu as a CGI form. Available values are presented
as a dropdown menu and are taken from @LANGUAGES. CGI paramter 'lang' is set
to selected language.

=head2 DIAGNOSTICS

A list of every error and warning message that the application can generate
(even the ones that will "never happen"), with a full explanation of each
problem, one or more likely causes, and any suggested remedies. If the
application generates exit status codes (e.g. under Unix) then list the exit
status associated with each error.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this application.
Please report problems to Christian Bartolomaeus  (<bartolin@gmx.de>)

=head1 AUTHOR

Christian Bartolomaeus  (<bartolin@gmx.de>)

=head1 LICENCE AND COPYRIGHT

Copyright (c) <2007> <Christian Bartolomaeus> (<bartolin@gmx.de>), all rights reserved.

This application is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
