#!/usr/bin/env perl

use strict;
use warnings;

use Test::TCP;
use IO::Socket::INET;

use FindBin;
use lib "$FindBin::Bin/../lib";

use POE qw/Component::Server::TCP/;
use IO::Lambda qw/:all/;
use IO::Lambda::Socket::TCPServer qw/:all/;

use Benchmark qw/:all/;

my $loop = shift || 1000000;

my $result = timethese(1, {
    lambda => 'lambda_test',
    poco   => 'poco_test',
});

cmpthese( $result ) ;

sub lambda_test {
    test_tcp(
        client => \&client_handler,
        server => sub {
            my $port = shift;
            lambda {
                context { Blocking => 0, Port => $port };
                server_start {
                    context shift;
                client_accepted {
                    my ( $client, $input ) = @_;
                    $client->put($input);
                }};
            }->wait;
        },
    );
}

sub poco_test {
    test_tcp(
        client => \&client_handler,
        server => sub {
            my $port = shift;
            POE::Component::Server::TCP->new(
                Port        => $port,
                ClientInput => sub {
                    my ( $heap, $input ) = @_[ HEAP, ARG0 ];
                    $heap->{client}->put($input);
                },
            );
            $poe_kernel->run;
        },
    );
}

sub client_handler {
    my $port = shift;

    my $sock = IO::Socket::INET->new(
        PeerPort => $port,
        PeerAddr => '127.0.0.1',
        Proto    => 'tcp'
    ) or die "Cannot open client socket: $!";

    for ( 1 .. $loop ) {
        $sock->print("test");
    }

    $sock->close;
}
