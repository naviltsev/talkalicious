package DB_Backend;
# use Moose;

use KiokuDB;
use MooseX::Singleton;

use Search::GIN::Query::Class;
use Search::GIN::Query::Manual;
use Search::GIN::Extract::Callback;

use Data::Dumper;

has kioku => (
	isa => 'KiokuDB',
	is => 'ro',
	default => sub { 
		KiokuDB->connect("dbi:SQLite:dbname=blog.db", 
			create => 1, 
			columns => [
				username => {
					data_type => 'varchar',
					is_nullable => 1,
				},
				email => {
					data_type => 'varchar',
					is_nullable => 1,
				},
				is_active => {
					data_type => 'bool',
					is_nullable => 1,
				},
				confirmation_key => {
					data_type => 'varchar',
					is_nullable => 1,
				}
			],
			# This gets called against each object being added into database, building gin_index table with entries.
			# Later on it will be possible to build simple queries with Search::GIN::Query
			extract => Search::GIN::Extract::Callback->new(
				extract => sub {
					my ($obj, $extractor, @args) = @_;

					if ($obj->isa("Post")) {
						return {
							type => 'post',
							class => 'Post',
							post_author => $obj->article->author->username,
						};
					}

					if ($obj->isa("User")) {
						return {
							type => 'user',
							class => 'User',
						}
					}

					return;
				},
			),
		);
	} # end default
	
);

# returns User instance
sub find_user {
	my ($self, %condition) = @_;

	unless (grep { $condition{$_} } qw/username fullname email is_active confirmation_key/) {
		warn qq/Can only find by 'username', 'fullname', 'email', 'is_active', 'confirmation_key'/;
		return;
	}

	my $kioku = $self->kioku;
	my $s = $kioku->new_scope;

	my $stream = $kioku->search(\%condition);
	while (my $block = $stream->next) {
		foreach my $obj(@$block) {
			return $obj;
		}
	}	
}

# returns @posts array
sub find_all_posts {
	my $self = shift;

	my $kioku = $self->kioku;
	my $s = $kioku->new_scope;

	my $query = Search::GIN::Query::Class->new(class => 'Post');
	my $stream = $kioku->search($query);

	return $stream->all;

}

sub find_posts_by_author {
	my ($self, $username) = @_;

	my $s = $self->kioku->new_scope;

	my $query = Search::GIN::Query::Manual->new(values => {post_author => $username});
	my $stream = $self->kioku->search($query);

	return $stream->all;
}

1;
