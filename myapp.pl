#!/usr/bin/env perl
use Mojolicious::Lite;
use lib qw(lib);

use DB_Backend;
use Post;
use Article;
use User;

use Data::Dumper;

# Documentation browser under "/perldoc"
plugin 'PODRenderer';

helper kioku => sub {
	return DB_Backend->kioku;
};

get '/' => sub {
  my $self = shift;

  my @all_posts = DB_Backend->find_all_posts;
  $self->render('index', posts => \@all_posts);
};


any ['GET', 'POST'] => '/login' => sub {
	my $self = shift;

	if ($self->req->method eq 'POST') {	
		my $username = $self->param('login');
		my $user = DB_Backend->find_user_by_username($username);
		
		$self->app->log->debug(Dumper $user);

		if ($user && $user->is_password_correct($self->param('password'))) {
			$self->session(logged_in_username => $username);
			$self->redirect_to($self->url_for('post_list'));
		} else {
			$self->stash(error => 'User does not exist');
		}
	}

	$self->render('login');
} => 'login';

get '/logout' => sub {
	my $self = shift;

	$self->session(logged_in_username => undef);
	$self->redirect_to('/');
};

#
# Auth
#
under sub {
	my $self = shift;
	if ($self->session('logged_in_username')) {
		return 1;
	}
	
	return $self->redirect_to('login');
};

get '/my_posts' => sub {
	my $self = shift;

	my @posts = DB_Backend->find_posts_by_author($self->session('logged_in_username'));;
	$self->render('my_posts', posts => \@posts);
} => 'post_list';

any ['GET', 'POST'] => '/edit_post' => sub {
	my $self = shift;

	my $post_id = $self->param('post_id') || return;

	my $s = $self->kioku->new_scope;
	my $post = $self->kioku->lookup($post_id);

	return $self->render(text => '404')
		unless $post;

	if ($self->req->method eq 'POST') {
		$post->article->title($self->param('title'));
		$post->article->body($self->param('body'));

		$self->kioku->deep_update($post);
		$self->redirect_to($self->url_for('post_list'));
	}

	$self->stash(post => $post);
	$self->render('edit_post');
};

get '/delete_post/:post_id' => sub {
	my $self = shift;
	my $post_id = $self->param('post_id');

	# TODO: I would also check if this post is mine - random user can not just delete any post

	my $s = $self->kioku->new_scope;
	my $post = $self->kioku->lookup($post_id);

	if ($post) {
		$self->kioku->delete($post);
	}

	return $self->redirect_to('post_list');
};

get '/post_set_visibility/:post_id/:should_hide' => sub {
	my $self = shift;
	my $post_id = $self->param('post_id');
	my $should_hide = $self->param('should_hide');

	$self->app->log->debug($post_id);
	$self->app->log->debug($should_hide);

	return $self->render(text => '404')
		unless ($should_hide eq '0' || $should_hide eq '1');

	my $s = $self->kioku->new_scope;

	my $post = $self->kioku->lookup($post_id);
	if ($post) {
		$post->is_hidden($should_hide);
		$self->kioku->store($post);
		$self->app->log->debug('Storing POST >>>>>');
	}

	$self->redirect_to('post_list');
};

any ['GET', 'POST'] => '/new_post' => sub {
	my $self = shift;

	if ($self->req->method eq 'POST') {
		my $title = $self->param('title');
		my $body = $self->param('body');

		my $article = Article->new(title => $title, body => $body, author => DB_Backend->find_user_by_username($self->session('logged_in_username')));
		my $post = Post->new(article => $article);
		$post->store_to_db;

		$self->redirect_to($self->url_for('post_list'));
	}

	$self->render('new_post');
};


app->start;
