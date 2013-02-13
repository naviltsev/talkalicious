$ENV{recaptcha_public_key} 			= '6LeqINoSAAAAAPiP1RACGh5rilIkHTDsxwusQRjn';
$ENV{recaptcha_private_key} 		= '6LeqINoSAAAAACQA5S9QqMneHkO0E0omPHMP1MVQ';
$ENV{recaptcha_lang}				= 'en';

$ENV{email_from} 					= '"mkdb-blog-perl" <blog@mkdb-blog-perl.com';
$ENV{email_transport_module}		= "Email::Sender::Transport::SMTP::TLS"; # or Email::Sender::Transport::Sendmail, etc
$ENV{email_transport_host}			= "";
$ENV{email_transport_username}		= "";
$ENV{email_transport_password}		= "";
$ENV{email_transport_port}			= 587;

$ENV{email_subjects_account_confirmation} = "mkdb-blog-perl account confirmation";

# debug 
# set to true to ignore some parts of the app
$ENV{debug_disable_recaptcha} = 1;
$ENV{debug_disable_email_confirmation} = 1;
