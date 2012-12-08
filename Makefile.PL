use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  VERSION   => '0.01',
  PREREQ_PM => {
  	'Mojolicious' => '3.64',
  	'KiokuDB' => '0',
  	'KiokuDB::Backend::DBI' => '0',
  	'MojoX::Validator' => 0,
  	'MooseX::Singleton' => 0,
  	'Date::Manip' => 0
  },
  test      => {TESTS => 't/*.t'}
);
