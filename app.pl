#!/usr/bin/env perl
use Mojolicious::Lite;
use lib qw(lib);

use DB_Backend;
use Post;
use Article;
use User;

use Data::Dumper;
use Digest::SHA qw(sha1_hex);

# Documentation browser under "/perldoc"
# plugin 'PODRenderer';

plugin 'validator';
plugin 'mail' => {
	from => 'www@mkdb-blog-perl',
	type => 'text/html'
};
plugin 'recaptcha' => {
	public_key => '6LeqINoSAAAAAPiP1RACGh5rilIkHTDsxwusQRjn',
	private_key => '6LeqINoSAAAAACQA5S9QqMneHkO0E0omPHMP1MVQ', # keep this in secret!
	lang => 'en'
};

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
		my $user = DB_Backend->find_user(username => $username, is_active => 1);

		if ($user && $user->is_password_correct($self->param('password'))) {
			$self->session(logged_in_username => $username);
			$self->redirect_to($self->url_for('post_list'));
		} else {
			$self->stash(error => 'User does not exist');
		}
	}

	$self->render('login');
} => 'login';

get '/confirmation' => sub {
	my $self = shift;
	my $confirmation_key = $self->param('key');

	return unless $confirmation_key;

	$self->app->log->debug($confirmation_key);

	my $user = DB_Backend->find_user(confirmation_key => $confirmation_key);
	if ($user) {
		$self->flash(flash => 'Thanks for registering with us. Your account is now active and you can sign in.');

		$self->kioku->new_scope && $user->is_active(1) && $self->kioku->deep_update($user);
		
		$self->redirect_to('login');
	} else {
		$self->redirect_to('/');
	}
};

any ['GET', 'POST'] => '/signup' => sub {
	my $self = shift;

	return unless $self->req->method eq 'POST';

	$self->recaptcha;

	my $val = $self->create_validator;
	$val->field([qw/fullname username password1 password2 email/])->each(sub { shift->required(1)->length(1,64) });
	$val->group('equal_passwords' => [qw/password1 password2/])->equal;
	$val->field('email')->email;

	if (!$self->validate($val)) {
		$self->stash(error => 'Please correct following errors');
		return;
	}

	if (DB_Backend->find_user(username => $self->param('username'))) {
		$self->stash(error => 'This username is taken, please choose another one');
		return;	
	}
	
	if (DB_Backend->find_user(email => $self->param('email'))) {
		$self->stash(error => 'This email address is taken, please choose another one');
		return;	
	}
	
	if ($self->stash('recaptcha_error')) {
		$self->stash(error => 'reCAPTCHA error, please try again');
		return;	
	}
		

	# send email first!

	my $user = User->new(
		username => $self->param('username'), 
		password => sha1_hex($self->param('password1')),
		email => $self->param('email'),
		fullname => $self->param('fullname'),
		is_active => 0,
		confirmation_key => sha1_hex(localtime . rand())
	);

	$user->store_to_db;

	my $username = $user->fullname;
	my $link = "http://mkdb-blog-perl.herokuapp.com/confirmation?key=".$user->confirmation_key;

	$self->mail(
		to => $self->param('email'),
		subject => 'Account confirmation on mkdb-blog-perl',
		data => "
		Dear $username.

		You've just registered an account on mkdb-blog-perl.
		In order to activate your account please follow the link:
		<a href='$link'>$link</a>

		Sincerely yours, 
		mkdb-blog-perl team.
		"
	);

	$self->redirect_to($self->url_for('confirmation'));
};


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

get '/posts' => sub {
	my $self = shift;

	my @posts = DB_Backend->find_posts_by_author($self->session('logged_in_username'));;
	$self->render('posts', posts => \@posts);
} => 'post_list';

get '/post' => sub {
	my $self = shift;

	my $post_id = $self->param('post_id');

	if ($post_id) {
		my $s = $self->kioku->new_scope;
		my $post = $self->kioku->lookup($post_id);

		$self->stash(post => $post);

		return $self->render(text => '404')
			unless $post;
	}
};

post '/post' => sub {
	my $self = shift;

	my $post_id = $self->param('post_id');

	my $val = $self->create_validator;
	$val->field([qw/title excerpt body/])->each(sub {shift->required(1)} );

	return unless $self->validate($val);

	if ($post_id) { # edit post
		my $s = $self->kioku->new_scope;
		my $post = $self->kioku->lookup($post_id);

		return $self->render(text => '404')
			unless $post;

		$post->article->title($self->param('title'));
		$post->article->excerpt($self->param('excerpt'));
		$post->article->body($self->param('body'));
		$self->kioku->deep_update($post);
	} else { # new post
		my $title = $self->param('title');
		my $body = $self->param('body');
		my $excerpt = $self->param('excerpt');

		my $article = Article->new(
			title => $title, 
			body => $body, 
			excerpt => $excerpt,
			author => DB_Backend->find_user(username => $self->session('logged_in_username'))
		);
		my $post = Post->new(article => $article);
		$post->store_to_db;
	}

	$self->redirect_to($self->url_for('post_list'));
} => 'post';

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

app->start;
