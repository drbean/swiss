use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'Swiss' }
BEGIN { use_ok 'Swiss::Controller::Search' }

ok( request('/search')->is_success, 'Request should succeed' );


