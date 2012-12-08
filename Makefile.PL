use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  VERSION   => '0.01',
  PREREQ_PM => {
  	'Mojolicious' => '3.64',
  	'KiokuDB' => '0',
  	'MojoX::Validator'
  },
  test      => {TESTS => 't/*.t'}
);
