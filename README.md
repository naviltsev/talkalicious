mkdb-blog-perl
==============

General notes
-------------

Training project to build up a clean and simple blog engine using `Moose/KiokuDB` in `Perl`.

I use [bower](https://github.com/twitter/bower) from Twitter for package management.

```
$ npm install -g bower
$ bower install --save jquery
$ bower install --save bootstrap
```

Notes on how to build Twitter Bootstrap - see /public/components/bootstrap/css/README.

mkdb-blog-perl and Heroku
-------------------------

This can be run within Heroku using [mojolicious-command-deploy-heroku](https://github.com/tempire/mojolicious-command-deploy-heroku) by [Glen Hinkle](http://tempi.re).

Environment config variables can be passed in into Heroku using `heroku config:set` command.

Also, do not forget to make following:

```
heroku config:set running_within_heroku=1

```
in order to forbid the app from loading config file and overriding Heroku config vars.