#!/usr/bin/env perl

use Mojolicious::Lite;
use lib qw(lib vendor/Mojolicious-Plugin-Email/lib);

use 5.010;
# use Plack::Builder;

use Talkalicious::Schema;

use DDP;
use Data::Dumper;
use Digest::SHA qw(sha1_hex);
use Email::Sender::Transport::SMTP::TLS;
use DateTime;

use Mojo::Util qw(url_unescape);

app->secret('aVerySecretThingHere');

my $mode = app->mode || 'development';
say "[debug] Running in $mode";
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

helper schema => sub {
	return Talkalicious::Schema->connect($ENV{db_dsn}, $ENV{db_username}, $ENV{db_password}, 
		{ AutoCommit => 1, RaiseError => 1, mysql_enable_utf8 => 1}
	);
};

helper UserModel => sub {
	shift->schema->resultset('User');
};

helper PostModel => sub {
	shift->schema->resultset('Post');
};

helper CommentModel => sub {
	shift->schema->resultset('Comment');
};

helper PreferenceModel => sub {
	shift->schema->resultset('Preference');
};

# Hooks
hook before_dispatch => sub {
	my $self = shift;
	
	# TODO: instead passing every single setting, pass entire $config object into the view?
	$self->stash(preference_blog_name => $ENV{preference_blog_name});
	$self->stash(disable_comments => $ENV{disable_comments});

	return unless $self->session('user_id');

	# TODO: refactor searching user so that we don't need to get user for each request
	my $user = $self->UserModel->find($self->session('user_id'));

	my $theme_preference = $user->preference_value_by_name('theme');
	$self->stash(preference_theme => $theme_preference->value);
};

# Routes
get '/' => sub {
  my $self = shift;

  my @all_posts = $self->PostModel->all_published_posts;
  $self->render('posts', posts => \@all_posts);
};

any ['GET', 'POST'] => '/login' => sub {
	my $self = shift;

	if ($self->req->method eq 'POST') {	
		my $user = $self->UserModel->find({username => $self->param('login'), active => 1});

		if ($user && $user->password eq sha1_hex($self->param('password'))) {
			$self->session(user_id => $user->id);
			# $self->session(username => $user->username);
			$self->redirect_to('/');
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

	my $user = $self->UserModel->find({confirmation_key => $confirmation_key});
	if ($user) {
		$self->flash(flash => 'Thanks for registering with us. Your account is now active and you can sign in.');
		$user->active(1);
		$user->update;		
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

	if ($self->UserModel->find({username => $self->param('username')})) {
		$self->stash(error => 'This username is taken, please choose another one');
		return;	
	}
	
	if ($self->UserModel->find({email => $self->param('email')})) {
		$self->stash(error => 'This email address is taken, please choose another one');
		return;	
	}
	
	if ($self->stash('recaptcha_error')) {
		$self->stash(error => 'reCAPTCHA error, please try again');
		return;
	}


	my $user = $self->UserModel->create({
		username => $self->param('username'), 
		password => sha1_hex($self->param('password1')),
		email => $self->param('email'),
		fullname => $self->param('fullname'),
		active => 0,
		confirmation_key => sha1_hex(localtime . rand()),
		registered_on => DateTime->now
	});



	my $preferences = $self->PreferenceModel;
	$user->populate_empty_preferences($preferences);

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

	$self->session(user_id => undef);
	# $self->session(username => undef);

	$self->redirect_to('/');
};

get '/post/:post_id' => sub {
	my $self = shift;

	my $post = $self->PostModel->find($self->param('post_id'));
	$self->stash(post => $post);

	return $self->render(text => '404')
		unless $post;
} => 'post';


#
# Auth
#
under sub {
	my $self = shift;
	if ($self->session('user_id')) {
		return 1;
	}
	
	return $self->redirect_to('login');
};

post '/add_comment' => sub {
	my $self = shift;

	my $post = $self->PostModel->find($self->param('post_id'));

	my $comment = $self->CommentModel->create({
		body => $self->param('comment'),
		added_on => DateTime->now,
		post_id => $post->id,
		author_id => $self->session('user_id'),
		# parent_comment_id => undef
	});

	$self->redirect_to(sprintf("post/%s", $self->param('post_id')));
};

get '/posts' => sub {
	my $self = shift;

	my @posts = $self->PostModel->posts_by_author(author_id => $self->session('user_id'));
	$self->render('posts', posts => \@posts);
} => 'post_list';

get '/edit_post' => sub {
	my $self = shift;

	my $post_id = $self->param('post_id');

	if ($post_id) {
		my $post = $self->PostModel->find($post_id);

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
		my $post = $self->PostModel->find($post_id);

		return $self->render(text => '404')
			unless $post;

		$post->title($self->param('title'));
		$post->excerpt($self->param('excerpt'));
		$post->body($self->param('body'));
		$post->modified_on(DateTime->now);

		$post->update;
	} else { # new post
		my $title = $self->param('title');
		my $body = $self->param('body');
		my $excerpt = $self->param('excerpt');

		my $post = $self->PostModel->create({
			title => $self->param('title'),
			excerpt => $self->param('excerpt'),
			body => $self->param('body'),
			added_on => DateTime->now,
			author_id => $self->session('user_id'),
			published => 0
		});
	}

	$self->redirect_to($self->url_for('post_list'));
} => 'edit_post';

get '/delete_post/:post_id' => sub {
	my $self = shift;
	my $post_id = $self->param('post_id');

	my $post = $self->PostModel->find($post_id);

	# TODO: fix this line, there is no Post->am_i_author method
	return unless $post->am_i_author($self->session('logged_in_username'));

	$post->delete if $post;

	return $self->redirect_to('post_list');
};

get '/post_set_visibility/:post_id/:should_hide' => sub {
	my $self = shift;
	my $post_id = $self->param('post_id');
	my $publish = $self->param('should_hide');

	return $self->render(text => '404')
		unless ($publish eq '0' || $publish eq '1');

	my $post = $self->PostModel->find($post_id);
	if ($post) {
		$post->published($publish);
		$post->update;
	}

	$self->redirect_to("/edit_post?post_id=$post_id");
};

any '/settings' => sub {
	my $self = shift;

	# Push list of available themes into stash
	my @themes = split " ", $ENV{preference_themes};
	$self->stash(preference_themes => \@themes);

	my $user = $self->UserModel->find($self->session('user_id'));
	return unless $user;

	# Themes
	my $theme_preference = $user->preference_value_by_name('theme');
	$self->stash(current_theme => $theme_preference->value);
	$self->stash(user => $user);

	return unless $self->req->method eq 'POST';

	# TODO: Validate input
	for (qw/theme/) {
		# $user->set_preference($_ => $self->param($_)) if $self->param($_);
		$theme_preference->value($self->param($_));
		$theme_preference->update;
	}

	$user->fullname($self->param('fullname')) if $self->param('fullname');
	$user->email($self->param('email')) if $self->param('email');
	$user->update;

	$self->redirect_to('/settings');
} => 'settings';


# builder {
	# enable "Debug";
	app->start;	
# }

