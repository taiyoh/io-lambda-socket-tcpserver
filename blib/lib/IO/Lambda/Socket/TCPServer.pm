use strict;

package IO::Lambda::Socket::TCPServer;

use vars qw/$VERSION/;
$VERSION = '0.01';

use IO::Lambda qw/:all :dev/;
use IO::Lambda::Socket qw/:all/;
use IO::Socket;

use Time::HiRes qw/time/;
use Digest::MD5 qw/md5_hex/;

sub new {
    my $pkg    = shift;
    my %param = @_;

    my $server = IO::Socket::INET->new(
        Proto     => 'tcp',
        Listen    => delete($param{Listen})    || 1024,
        LocalPort => delete($param{LocalPort}) || 10000,
        Blocking  => delete($param{Blocking})  || 1,
    ) or die $!;
    my $o = bless({ _server => $server, _heap => {} }, $pkg);
    $o->{_serv} = $o->_make_proccesser($server, \%param);

    return $o;
}

sub _make_proccesser {
    my ( $self, $server, $param ) = @_;

    my $timeout = delete $param->{Timeout};
    my $accepted = __PACKAGE__.'::Accepted';
    $accepted->_make_methods($param);
    return lambda {
        context $server;
        accept { # constructer
            my $conn   = shift;
            my $sessid = md5_hex(time);
            $self->{_heap}->{$sessid} = {};
            my $accepted_o = $accepted->new(
                _socket => $conn,
                _sessid => $sessid,
                Heap    => $self->{_heap}->{$sessid},
            );
            $accepted_o->client_connected();
            again;
        context getline, $conn, \$self->{_b}, $timeout;
        tail {   # getlined
            $accepted_o->parse(@_);
            if($accepted_o->will_close) {
                delete $self->{_heap}->{$sessid};
                delete $accepted_o->{_socket};
                close $conn;
            }
            else {
                again;
            }
        }};
    };
}

sub run { shift->{_serv}->wait; }

1;

package IO::Lambda::Socket::TCPServer::Accepted;

sub _make_methods {
    my ( $pkg, $param ) = @_;
    warn "why wouldn't you process input?" unless $param->{ClientInput};
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

  use IO::Lambda::Socket::TCPServer;

  my $server = IO::Lambda::Socket::TCPServer->new(
      Listen      => 32,
      LocalPort   => 10000,
      ClientInput => sub {
          my $accepted = shift;
          my $buf      = shift;
          $accepted->put("[INPUT] $buf");
      },
      ClientConnected => sub {
          my $accepted = shift;
          print "connected $accepted->{_sessid}\n";
      },
      ClientDisconnected => sub {
          my $accepted = shift;
          print "disconnected $accepted->{_sessid}\n";
      },
  );
  $server->run;

=head1 DESCRIPTION

IO::Lambda::Socket::TCPServer is ported from POE::Component::Server::TCP

This module is underconstructing, so some function is not ported.

=head1 AUTHOR

Author E<lt>sun.basix@gmail.comE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<>

=cut
