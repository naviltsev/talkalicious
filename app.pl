#!/usr/bin/env perl
use Mojolicious::Lite;
use lib qw(lib vendor/Mojolicious-Plugin-Email/lib);

use 5.010;
# use Plack::Builder;

use DB_Backend;
use Post;
use Article;
use User;
use Comment;

use Data::Dumper;
use Digest::SHA qw(sha1_hex);
use Email::Sender::Transport::SMTP::TLS;

use Mojo::Util qw(url_unescape);

app->secret('aVerySecretThingHere');

my $mode = app->mode || 'development';
require "./config/$mode.pl" 
	unless $ENV{running_within_heroku}; # we don't want local config vars override Heroku config vars 

plugin 'validator';
plugin 'email' => {
	from => $ENV{email_from},
	transport => "$ENV{email_transport_module}"->new(
					host => $ENV{email_transport_host},
					username => $ENV{email_transport_username},
					password => $ENV{email_transport_password},
					port => $ENV{email_transport_port}
				)
};

plugin 'recaptcha' => {
	public_key => $ENV{recaptcha_public_key},
	private_key => $ENV{recaptcha_private_key},
	lang => $ENV{recaptcha_lang}
};

helper kioku => sub {
	return DB_Backend->kioku;
};

# Hooks
hook before_dispatch => sub {
	my $self = shift;
	
	# TODO: instead passing every single setting, pass entire $config object into the view?
	$self->stash(preference_blog_name => $ENV{preference_blog_name});
	$self->stash(disable_comments => $ENV{disable_comments});

	return unless $self->session('logged_in_username');

	# TODO refactor searching user so that we don't need to get user for each request
	my $user = DB_Backend->find_user(username => $self->session('logged_in_username'));
	return unless $user;

	$self->stash(preference_theme => $user->get_preference('theme'));
	
};

# Routes
get '/' => sub {
  my $self = shift;

  my @all_posts = DB_Backend->find_all_posts;
  $self->render('posts', posts => \@all_posts);
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

	$self->recaptcha 
		unless $ENV{debug_disable_recaptcha};

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
	my $base_url = $self->req->url->base || 'http://localhost:3000';
	my $link = "$base_url/confirmation?key=".$user->confirmation_key;

	if ($ENV{debug_disable_email_confirmation}) {
		$self->flash(message => "DEBUG: Now go to <a href='$link'>$link</a> to activate your account");
	}
	else {
		$self->email(
			header => [
				To => $self->param('email'),
				Subject => $ENV{email_subjects_account_confirmation}
			],
			data => [
				template => 'email/account_confirmation',
				username => $username,
				link => $link
			],
			content_type => 'text/html',
			charset => 'utf8',
			format => 'html'
		);
	}

	$self->redirect_to($self->url_for('confirmation'));
};


get '/logout' => sub {
	my $self = shift;

	$self->session(logged_in_username => undef);
	$self->redirect_to('/');
};

get '/post/:post_id' => sub {
	my $self = shift;

	my $s = $self->kioku->new_scope;
	my $post = $self->kioku->lookup($self->param('post_id'));
	$self->stash(post => $post);

	return $self->render(text => '404')
		unless $post;
} => 'post';


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

post '/add_comment' => sub {
	my $self = shift;

	my $s = $self->kioku->new_scope;
	my $post = $self->kioku->lookup($self->param('post_id'));

	my $comment = Comment->new({
		body => $self->param('comment'),
		is_author => $post->article->author->username eq $self->session('logged_in_username'),
		author => DB_Backend->find_user(username => $self->session('logged_in_username'))
		# parent_comment => undef
	});

	push @{$post->comments}, $comment;

	$post->store_to_db;
	$self->redirect_to(sprintf("post/%s", $self->param('post_id')));
};

get '/posts' => sub {
	my $self = shift;

	my @posts = DB_Backend->find_posts_by_author($self->session('logged_in_username'));;
	$self->render('posts', posts => \@posts);
} => 'post_list';

get '/edit_post' => sub {
	my $self = shift;

	my $post_id = $self->param('post_id');

	if ($post_id) {
		my $s = $self->kioku->new_scope;
		my $post = $self->kioku->lookup($post_id);

		$self->stash(post => $post);

		return $self->render(text => '404')
			unless $post;
	}
} => 'edit_post';

post '/edit_post' => sub {
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
} => 'edit_post';

get '/delete_post/:post_id' => sub {
	my $self = shift;
	my $post_id = $self->param('post_id');

	my $s = $self->kioku->new_scope;
	my $post = $self->kioku->lookup($post_id);

	return unless $post->am_i_author($self->session('logged_in_username'));

	if ($post) {
		$self->kioku->delete($post);
	}

	return $self->redirect_to('post_list');
};

get '/post_set_visibility/:post_id/:should_hide' => sub {
	my $self = shift;
	my $post_id = $self->param('post_id');
	my $should_hide = $self->param('should_hide');

	return $self->render(text => '404')
		unless ($should_hide eq '0' || $should_hide eq '1');

	my $s = $self->kioku->new_scope;

	my $post = $self->kioku->lookup($post_id);
	if ($post) {
		$post->is_hidden($should_hide);
		$self->kioku->store($post);
	}

	$self->redirect_to('post_list');
};

any '/settings' => sub {
	my $self = shift;

	# Push list of available themes into stash
	my @themes = split " ", $ENV{preference_themes};
	$self->stash(preference_themes => \@themes);

	my $user = DB_Backend->find_user(username => $self->session('logged_in_username'));
	return unless $user;

	$self->stash(current_theme => $user->get_preference('theme'));

	return unless $self->req->method eq 'POST';

	# TODO Validate input
	for (qw/theme/) {
		$user->set_preference($_ => $self->param($_));
	}
	$self->kioku->new_scope && $self->kioku->deep_update($user);

	$self->redirect_to('/settings');
} => 'settings';


# builder {
	# enable "Debug";
	app->start;	
# }

