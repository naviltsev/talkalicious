package Comment;

use Moose;
use namespace::autoclean;

use DB_Backend;
use Date::Manip;

use Digest::SHA qw(sha1_hex);

has "title", isa => "Str", is => "rw", required => 1;
has "body", isa => "Str", is => "rw", required => 1;

has "date" => (
	isa => "Str",
	is => "rw",
	default => sub { UnixDate('now', "%Y-%m-%d, %H:%M") },
);

has 'user', isa => "Str", is => "rw", required => 1;
has 'is_author', isa => "Bool", is => "rw", required => 1, default => 0;
has 'author', isa => "User", is => "rw", required => 0;

has 'parent_comment', isa => 'Comment', is => "rw", required => 1;
has 'post', isa => 'Post', is => "rw", required => 1;

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