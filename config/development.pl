$ENV{recaptcha_public_key} 			= '6LeqINoSAAAAAPiP1RACGh5rilIkHTDsxwusQRjn';
$ENV{recaptcha_private_key} 		= '6LeqINoSAAAAACQA5S9QqMneHkO0E0omPHMP1MVQ';
$ENV{recaptcha_lang}				= 'en';

$ENV{email_from} 					= '"mkdb-blog-perl" <blog@mkdb-blog-perl.com';
$ENV{email_transport} 				= Email::Sender::Transport::SMTP::TLS->new(
										host => '',
										username => '',
										password => '',
										port => 587
									);

$ENV{email_subjects_account_confirmation} = "mkdb-blog-perl account confirmation";