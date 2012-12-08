package Article;

use Moose;
use namespace::autoclean;

use DB_Backend;
use Date::Manip;

use Digest::SHA qw(sha1_hex);

has "title", isa => "Str", is => "rw", required => 1;

has 'excerpt' => (
	isa 	=> "Str",
	is 		=> "rw"
);

has "body", isa => "Str", is => "rw", required => 1;

has "author", isa => "User", is => "rw", required => 1;

has "date" => (
	isa => "Str",
	is => "rw",
	default => sub { UnixDate('now', "%Y-%m-%d, %H:%M") },
);

# returns UUID
sub store_to_db {
	my $self = shift;
	my $kioku = DB_Backend->kioku;
	my $s = $kioku->new_scope;

	# my $id = sha1_hex($self);

	return $kioku->store($self);
}

__PACKAGE__->meta->make_immutable;

1;