use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  VERSION   => '0.01',
  PREREQ_PM => {
  	'Mojolicious' => '3.85',
  	'MojoX::Validator' => '0',
  	'Mojolicious::Plugin::Recaptcha' => '0',
  	# 'KiokuDB' => '0.52',
  	# 'KiokuDB::Backend::DBI' => '1.22',
  	# 'MooseX::Singleton' => '0.29',
  	'Date::Manip' => '0',
  	'Email::MIME' => '0',
    'Email::Sender' => '1.300004',
    'Email::Sender::Transport::Sendmail' => '0',
  	'Email::Sender::Transport::SMTP' => '0',
    'DBD::Pg' => '0', # errrr, this is for Heroku :)
    'DBIx::Class' => '0',
    'DateTime::Format::MySQL' => '0',
  },
  test      => {TESTS => 't/*.t'}
);
