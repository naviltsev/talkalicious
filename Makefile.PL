use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  VERSION   => '0.01',
  PREREQ_PM => {
  	'Mojolicious' => '3.64',
  	'MojoX::Validator' => '0',
  	'Mojolicious::Plugin::Recaptcha' => '0',
  	'Mojolicious::Plugin::Mail' => '0',
  	'KiokuDB' => '0',
  	'KiokuDB::Backend::DBI' => '0',
  	'MooseX::Singleton' => '0',
  	'Date::Manip' => '0',
  	'Email::MIME' => '0',
  	'Email::Sender::Transport::SMTP::TLS' => '0',
  	'Email::Sender::Transport::Sendmail' => '0',
    'DBD::Pg' => '0', # errrr, this is for Heroku
  },
  test      => {TESTS => 't/*.t'}
);
