package Post;

use Moose;
use namespace::autoclean;
use DB_Backend;

use Digest::SHA qw(sha1_hex);

has "article", isa => "Article", is => "rw", required => 1;
has "is_hidden", isa => "Bool", is => "rw", required => 1, default => '0';

has "comments", isa => "ArrayRef[Comment]", is => "rw", required => 0, default => sub { [] };

sub store_to_db {
	my $self = shift;
	my $kioku = DB_Backend->kioku;
	my $s = $kioku->new_scope;

	# Returns UUID
	return $kioku->store($self);
}

sub am_i_author {
    my ($self, $username) = @_;
    return $self->article->author->username eq $username;
}

__PACKAGE__->meta->make_immutable;

1;