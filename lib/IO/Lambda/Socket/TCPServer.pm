use strict;
use warnings;

package IO::Lambda::Socket::TCPServer;

use vars qw($VERSION @ISA @EXPORT_OK %EXPORT_TAGS);
$VERSION = '0.009_2';

use IO::Lambda qw(:all :dev);
use IO::Lambda::Socket qw(:all);
use IO::Socket;

use Exporter;
@ISA         = qw(Exporter);
%EXPORT_TAGS = (all => \@EXPORT_OK);
@EXPORT_OK   = qw(server_start client_accepted);
use subs       @EXPORT_OK;

use Time::HiRes qw(time);
use Digest::MD5 qw(md5_hex);

use YAML qw/Dump/;

my $heap;
my $timeout;

sub server_start (&) {
    my $callback = shift;
    my ($inet_param) = context;
    $inet_param->{Listen}    ||= 1024;
    $inet_param->{LocalPort} ||= 10000;
    $inet_param->{Blocking}  ||= 1;
    $inet_param->{Proto} = 'tcp';
    $timeout = delete($inet_param->{Timeout}) || undef;
    my $server = IO::Socket::INET->new(%$inet_param) or die $!;
    $callback->($server);
}

sub client_accepted (&) {
    my $client_input = shift;
    my ( $server, $param ) = context;
    $param->{ClientInput} = $client_input;

    my $accepted = __PACKAGE__.'::Accepted';
    $accepted->_make_methods($param);
    context $server, $timeout;
    accept { # constructer
        my $conn   = shift;
        my $sessid = md5_hex(time);
            $heap->{$sessid} = {};
            my $accepted_o = $accepted->new(
                _socket => $conn,
                _sessid => $sessid,
                Heap    => $heap->{$sessid},
            );
            $accepted_o->client_connected();
            again;
    context getline, $conn, \(my $b);
    tail {   # getlined
        $accepted_o->parse(@_);
        if($accepted_o->will_close) {
            delete $heap->{$sessid};
            delete $accepted_o->{_socket};
            $conn->close;
        }
        else {
            again;
        }
    }};
}

1;

package IO::Lambda::Socket::TCPServer::Accepted;

sub _make_methods {
    my ( $pkg, $param ) = @_;
    no strict 'refs';
    *{"${pkg}::client_connected"}    = $param->{ClientConnected}    || sub { };
    *{"${pkg}::client_disconnected"} = $param->{ClientDisconnected} || sub { };
    *{"${pkg}::client_error"}        = $param->{ClientError}        || sub { };
    *{"${pkg}::client_input"}        = $param->{ClientInput};
}

sub new {
    my ( $pkg, %param ) = @_;
    return bless \%param, $pkg;
}

sub parse {
    my ( $self, $buf, $err ) = @_;

    $self->{_close} = 0;
    if ( $err && $err =~ /^(eof|timeout)/ ) {
        $self->client_disconnected($err, $buf);
        $self->close;
    }
    elsif ($err) {
        $self->client_error($err, $buf);
    }
    else {
        $buf =~ s/(\r|\n)//g;# あとでFilterクラスつくって何とかできるよね
        $self->client_input($buf);
        $self->{_close} = 0;
    }
}

sub close { shift->{_close} = 1; }

sub will_close { shift->{_close} }

sub put {
    my $self = shift;
    my $buf  = shift;
    syswrite( $self->{_socket}, "$buf\r\n" );
}

1;
__END__

=head1 NAME

IO::Lambda::Socket::TCPServer - 

=head1 SYNOPSIS

  use IO::Lambda qw/:all/;
  use IO::Lambda::Socket::TCPServer qw/:all/;

  my $server = lambda {
      context { Listen => 32, LocalPort => 10000 };
      server_start {
          my $conn = shift;
          context $conn, {
              ClientConnected => sub {
                  my $accepted = shift;
                  print "connected $accepted->{_sessid}\n";
              },
              ClientDisconnected => sub {
                  my $accepted = shift;
                  print "disconnected $accepted->{_sessid}\n";
              },
          };
      client_accepted {
          # similar for ClientInput parameter in POCo::Server::TCP
          my $accepted = shift;
          my $buf      = shift;
          $accepted->put("[INPUT] $buf");
      }};
  };

  $server->wait;

=head1 DESCRIPTION

IO::Lambda::Socket::TCPServer is ported from POE::Component::Server::TCP

=head1 AUTHOR

Author E<lt>sun.basix@gmail.comE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<>

=cut
