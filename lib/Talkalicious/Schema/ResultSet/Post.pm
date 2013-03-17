package Talkalicious::Schema::ResultSet::Post;

use strict;
use base 'DBIx::Class::ResultSet';

sub all_published_posts {
    return shift->search({published => 1})->all;
}

sub posts_by_author {
    my ($self, %params) = @_;
    return shift->search({author_id => $params{author_id}})->all;
}

1;