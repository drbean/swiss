package dic::Controller::Exercises;

use Moose;
BEGIN { extends 'Catalyst::Controller'; }

use Dictionary;
use FirstLast;
use Ctest;
use Total;
use Kwic;
use Last;
use Lingua::Stem qw/stem/;
use Net::FTP;

=head1 NAME

dic::Controller::Exercises - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 form_create

Display form to collect information for exercise to create

=cut

sub form_create : Local {
	my ($self, $c) = @_;
	$c->stash->{template} = 'exercises/form_create.tt2';
}


=head2 list

Fetch all Exercise objects and pass to exercises/list.tt2 in stash to be displayed

=cut
 
sub list : Local {
    # Retrieve the usual perl OO '$self' for this object. $c is the Catalyst
    # 'Context' that's used to 'glue together' the various components
    # that make up the application
    my ($self, $c) = @_;
    my $leagueid = $c->session->{league};
    my $league = $c->model('DB::League')->find({id=>$leagueid});
    my $genre = $c->model('DB::Leaguegenre')->search({league=>$leagueid})
    					->next->genre;
    # my $genre = $league->genre->genre;
    # Retrieve all of the text records as text model objects and store in
    # stash where they can be accessed by the TT template
    $c->stash->{exercises} = [$c->model('DB::Exercise')->search(
	    { genre => $genre })];
    # Set the TT template to use.  You will almost always want to do this
    # in your action methods (actions methods respond to user input in
    # your controllers).
    my $player = $c->session->{player_id};
    my @play = $c->model('DB::Play')->search(
	    { league => $league, player => $player },
		{ select => [ 'exercise', { sum => 'correct' } ],
		'group_by' => [qw/exercise/],
		as => [ qw/exercise letters/ ],
		});
    my %letterscores = map { $_->exercise => $_->get_column('letters') } @play;
    $c->stash->{letters} = \%letterscores;
    my @quiz = $c->model('DB::Quiz')->search(
	    { league => $league, player => $player },
		{ select => [ 'exercise', { sum => 'correct' } ],
		'group_by' => [qw/exercise/],
		as => [ qw/exercise questions/ ],
		});
    my %quizscores = map { $_->exercise => $_->get_column('questions') } @quiz;
    $c->stash->{questions} = \%quizscores;
    $c->stash->{league} = $league->name;
    $c->stash->{genre} = $genre;
    $c->stash->{template} = 'exercises/list.tt2';
}


=head2 create

http://server.school.edu/dic/exercises/create/textId/exerciseType/exerciseId

Create comprehension questions and cloze exercise. If 2 different leagues have the same genre, ie their texts are the same, will creating an exercise for one league also create it for the other? Apparently, so. Also, can leagues with different genres use the same texts? Remember texts have genres assigned to them.

=cut

sub create : Local {
	my ($self, $c, $textId, $exerciseType, $exerciseId) = @_;
	my $text = $c->model('DB::Text')->find( { id=>$textId } );
	my $genre = $text->genre;
	$c->stash->{text} = $text;
	$c->stash->{genre} = $genre;
	$c->forward('clozecreate');
	$c->forward('questioncreate');
	$c->stash->{exercise_id} = $exerciseId;
	$c->stash->{template} = 'exercises/list.tt2';
}
			
=head2 clozecreate

Take text from database and output cloze exercise. We create an id for each Word of the Exercise, and the first Word has id 1, so 0 can be used as a link for unlinked Questionwords to show there is no link. (SQL Server wasn't allow NULL strings in INT column.)

=cut

sub clozecreate : Private {
	my ($self, $c, $textId, $exerciseType, $exerciseId) = @_;
	my $text = $c->stash->{text};
	my $description = $text->description;
	my $content = $text->content;
	my $unclozeables = $text->unclozeables;
	my $genre = $c->stash->{genre};
	my $index=0;
	my $clozeObject = $exerciseType->parse($unclozeables, $content);
	my $cloze = $clozeObject->cloze;
	my $newWords = $clozeObject->dictionary;
	my (@wordRows, @dictionaryList, %wordCount, @wordstemRows);
	my $dictionary = $c->model('DB::Dictionary')->search;
	my $id = 1;
	my @columns = $c->model('DB::Word')->result_source->columns;
	foreach my $word ( @$cloze )
	{
		my $token = $word->{published};
		if ( $token and $newWords->{$token} )
		{
			(my $initial = $token) =~ s/^(.).*$/$1/;
			my $entry = $dictionary->find(
				{ genre => $genre, word => $token });
			my $count = $entry? $entry->count: 0;
			my $stem = (stem $token)->[0];
			my $suffix;
			if ( $stem =~ m/.i$/ )
			{
				my $istem = $stem;
				chop $istem;
				($suffix = lc $token) =~ s/^$istem.(.*)$/$1/;
			}
			else { ($suffix = lc $token) =~ s/^$stem(.*)$/$1/; }
			$dictionary->update_or_create({
				genre => $genre,
				word => $token,
				initial => $initial,
				stem => $stem || '',
				suffix => $suffix || '',
				count =>++$count});
		}
		my $class = ref $word;
		my %row = map { $_ => $word->{$_} } @columns;
		$row{genre} = $genre;
		$row{exercise} = $exerciseId;
		$row{id} = $id++;
		$row{class} = $class;
		push @wordRows, \%row;
	}
	$c->model('DB::Word')->populate( \@wordRows );
	#@dictionaryList = map { m/^(.).*$/;
	#		{ exercise => $exerciseId, word => $_, initial => $1,
	#		count => $newWords->{$_} } } keys %$newWords;
	my $exercise = $c->model('DB::Exercise')->create({
				id => $exerciseId,
				text => $textId,
				genre => $genre,
				description => $description,
				type => $exerciseType
			});
	$c->stash->{exercise} = $exercise;
}


=head2 questioncreate

http://server.school.edu/dic/exercises/create/textId/exerciseType/exerciseId

Create comprehension questions. NOT NECESSARY. WILL TRACK LATER: For a set of related exercises on the same material, choose exerciseIds that have a lexicographic order that corresponds to the progression in the material through the different exercises, allowing tracking of the player through the material.

=cut

sub questioncreate : Private {
	my ($self, $c, $textId, $exerciseType, $exerciseId) = @_;
	my $genre = $c->stash->{genre};
	my $text = $c->stash->{text};
	my $exercise = $c->stash->{exercise};
	my $questions = $text->questions;
	my @wordRows;
	my $questionwords = $c->model('DB::Questionword');
	my $ftp = Net::FTP->new('web.nuu.edu.tw') or die "web.nuu.edu.tw? $@";
	$ftp->login('greg', '1514') or die "web.nuu.edu.tw login? $@";
	$ftp->cwd('public_html') or die "web.nuu.edu.tw/~greg/public_html? $@";
	$ftp->binary;
	my $voice = 'voice_cmu_us_bdl_arctic_hts';
	while ( my $question = $questions->next )
	{		
		my $questionId = $question->id;
		die unless defined $questionId;
		my $content = $question->content;
		my $remote = "$genre$exerciseId$questionId.mp3";
		my $local = "/tmp/$remote";
		system( "echo \"$content\" |
			text2wave -eval \"($voice)\" -otype wav |
			lame -h -V 0 - $local" ) == 0 or die "speech file? $!";
		$ftp->put($local) or die
			"put $remote on web.nuu.edu.tw? $@";
		my $answer = $question->answer;
		my $punctuation = qr/([^A-Za-z0-9\\n]+)/;
		my @words = split $punctuation, $content;
		my $clozewords = $exercise->words;
		my $id;
		foreach my $word ( @words )
		{
			my $cloze = $clozewords->search(
				{ published => $word })->next;
			my $link = $cloze? $cloze->id: 0;
			my $row = {
				genre => $genre,
				text => $textId,
				question => $questionId,
				id => $id++,
				content => $word,
				link => $link };
			push @wordRows, $row;
		}
	}
	$questionwords->populate( \@wordRows );
}
			

=head2 delete

Delete an exercise. Delete of Questions and Questionwords done here too. TODO But delete of Questionwords not appearing to be done!

=cut

sub delete : Local {
	my ($self, $c, $id) = @_;
	my $exercise = $c->model('DB::Exercise');
	my $words = $exercise->find({id => $id})->words;
	my %entries;
	while (my $word = $words->next)
	{
		my $token = $word->published;
		my $entry = $word->dictionary;
		if ( $entry )
		{
			my $count = $entry->count;
			$entry->update( {count => --$count} );
		}
	}
	$exercise->search({id => $id})->delete_all;
	$c->stash->{status_msg} = "Exercise deleted.";
       $c->response->redirect($c->uri_for('list',
                   {status_msg => "Exercise deleted."}));
}


=head2 index 

=cut

sub index : Private {
    my ( $self, $c ) = @_;

    $c->response->body('Matched dic::Controller::Players in Players.');
}


=head1 AUTHOR

Dr Bean,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
