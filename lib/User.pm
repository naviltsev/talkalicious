package User;

use Moose;
use DB_Backend;
use Data::Dumper;
use namespace::autoclean;

use Digest::SHA qw(sha1_hex);

has "username", isa => "Str", is => "rw";
has "password", isa => "Str", is => "rw";
has "fullname", isa => "Str", is => "rw";

sub store_to_db {
	my $self = shift;
	my $kioku = DB_Backend->kioku;
	my $s = $kioku->new_scope;

	# Check if user exists
	my $existing_user = DB_Backend->find_user_by_username($self->username);
	if ($existing_user) {
		warn "User " . $self->username . " exists, won't add another one";
		return;
	}

	# returns UUID
	return $kioku->store($self);
}

sub update {
	...;
}

sub is_password_correct {
	my ($self, $password) = @_;
	
	if ($self->password eq sha1_hex($password)) {
		return 1;
	}
	return 0;
}

__PACKAGE__->meta->make_immutable;

1;