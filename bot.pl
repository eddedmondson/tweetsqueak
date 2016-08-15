#!/usr/bin/perl -w
use strict;
package FRBot;
use base qw(Bot::BasicBot);
use Net::Twitter;
use Config::Simple;

#configurations we need - interval, authorized, twitter keys
our $cfg=new Config::Simple('bot.ini');

our $interval = $cfg->param('interval'); #rate limit in seconds
our $consumer_key = $cfg->param('consumer_key');
our $consumer_secret = $cfg->param('consumer_secret');
our $access_token = $cfg->param('access_token');
our $access_token_secret = $cfg->param('access_token_secret');
our @authlist = $cfg->param('authlist');
our $superuser = $cfg->param('superuser');
our $server = $cfg->param('server');
our $port = $cfg->param('port');
our $channel = $cfg->param('channel');
our $nick = $cfg->param('nick');
our $username = $cfg->param('username');
our $name = $cfg->param('name');

our $lasttime = time()-$interval;

#doesn't seem to flush often, so generally I expect to override this
$cfg->autosave(1);

sub authorized {
    my $checknick = $_[0];
    if ($checknick =~ /dispatch/i) {
	return 1;
    }
    $checknick =~ s/\[.*\]$//;
    foreach my $authed (@authlist) {
	if ($checknick =~ /^$authed/i) {
	    return 1;
	}
    }
    return 0;
}

my $tweeter = Net::Twitter->new(
    traits => [qw/API::RESTv1_1/],
    consumer_key => $consumer_key,
    consumer_secret => $consumer_secret,
    access_token => $access_token,
    access_token_secret => $access_token_secret,
#    source => "api",
    );

sub help { "This is a bot for tweeting out to \@FuelRatAlerts if more help is needed than can currently be found in chat. Ask Edmondson for assistance or to be added to the authorized list. Use '!tweet yourmessage' in channel to send out an alert if you are authorized or currently dispatch" }

sub said {
    my ($self, $message) = @_;
    if ($message->{raw_nick} eq $superuser) {
	if ($message->{body} =~ /!authorize (.*)/) {
	    warn "Authorizing $1";
	    push @authlist, $1;
	    $cfg->param("authlist", \@authlist);
	    $self->say(
		who => $message->{who},
		channel => "msg",
		body => "$1 is now authorized for tweeting.",
		);
	    $cfg->save;
	}
    }
    #spit direct messages to stderr
    if ($message->{channel} eq "msg") {
	warn "Direct message: <".$message->{who}."> ".$message->{body};
	if ($message->{body} =~ /^!tweet /) {
	    warn "Tweet request detected from $message->{who}, $message->{body}";
	    if (authorized($message->{who})) {
		warn "Request authorized";
		my $trim = $message->{body};
		$trim =~ s/^!tweet //;
		if (length($trim) > 140) {
		    warn "Tweet too long";
		    $self->say(
			who => $message->{who},
			$channel => "msg",
			body => "That message was too long to tweet. Please try again keeping below 140 characters",
			);
		}
		if ($lasttime+$interval > time()) {
		    warn "Rate limit hit";
		    $self->say(
			who => $message->{who},
			channel => "msg",
			body => "You have hit the tweet rate limit. Please try again a little later (rate limited to $interval seconds)",
			);
		} else {
		    eval {
			warn "Tweeting...";
			$tweeter->update($trim)
		    };
		    if ( $@ ) {
			#hit an error from twitter
			$self->say(
			    who => $message->{who},
			    channel => "msg",
			    body => "Something went wrong trying to communicate with Twitter. Apologies. Please try again in a few minutes or contact Edmondson for support",
			    );
			warn $@;
		    } else {
			warn "Tweet successful";
			$lasttime = time();
			return "Your message has been tweeted.";
		    }
		}
	    } else {
		warn "Tweet request not authorized";
		#not authorised - send user a private message
		$self->say(
		    who => $message->{who},
		    channel => "msg",
		    body => "You attempted to send a tweet via me. Unfortunately I couldn't authorize you. Please ask Edmondson for help.",
		    );
	    }
	}
    }
    if ($message->{channel} =~ /fuelrats/i && $message->{body} =~ /^!tweet /) {
	warn "Tweet request detected from $message->{who}, $message->{body}";
        if (authorized($message->{who})) {
	    warn "Request authorized";
	    my $trim = $message->{body};
	    $trim =~ s/^!tweet //;
	    if (length($trim) > 140) {
		warn "Tweet too long";
		$self->say(
		    who => $message->{who},
		    $channel => "msg",
		    body => "That message was too long to tweet. Please try again keeping below 140 characters",
		    );
	    }
	    if ($lasttime+$interval > time()) {
		warn "Rate limit hit";
		$self->say(
		    who => $message->{who},
		    channel => "msg",
		    body => "You have hit the tweet rate limit. Please try again a little later (rate limited to $interval seconds)",
		    );
	    } else {
		eval {
		    warn "Tweeting...";
		    $tweeter->update($trim)
		};
		if ( $@ ) {
		    #hit an error from twitter
		    $self->say(
			who => $message->{who},
			channel => "msg",
			body => "Something went wrong trying to communicate with Twitter. Apologies. Please try again in a few minutes or contact Edmondson for support",
			);
		    warn $@;
		} else {
		    warn "Tweet successful";
		    $lasttime = time();
		    return "Your message has been tweeted.";
		}
	    }
	} else {
	    warn "Tweet request not authorized";
	    #not authorised - send user a private message
	    $self->say(
		who => $message->{who},
		channel => "msg",
		body => "You attempted to send a tweet via me. Unfortunately I couldn't authorize you. Please ask Edmondson for help.",
		);
	}
    }
    return;
}

my $bot = FRBot->new(
    channels=>[$channel],
    server => $server,
    port => $port,
    nick => $nick,
    username => $username,
    name => $name,
    );

$bot->run();
