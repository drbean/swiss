use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'Swiss' }
BEGIN { use_ok 'Swiss::Controller::Web' }

ok( request('/web')->is_success, 'Request should succeed' );


