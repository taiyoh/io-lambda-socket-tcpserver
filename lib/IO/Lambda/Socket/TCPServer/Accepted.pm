use strict;
use warnings;

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
    if ( $err && $err =~ /^(eof|timeout)$/ ) {
        $self->client_disconnected($err, $buf);
        $self->close;
    }
    elsif ($err) {
        $self->client_error($err, $buf);
    }
    else {
        $buf =~ s/\r\n//g;
        $self->client_input($buf);
        $self->{_close} = 0;
    }
}

sub close { shift->{_close} = 1; }

sub will_close { shift->{_close} }

sub put {
    my ( $self, $buf ) = @_;
    syswrite( $self->{_socket}, "$buf\r\n" );
}

1;
__END__

=head1 NAME

IO::Lambda::Socket::TCPServer::Accepted - a parser module for IO::Lambda::Socket::TCPServer

=head1 SYNOPSIS


=head1 DESCRIPTION

IO::Lambda::Socket::TCPServer is ported from POE::Component::Server::TCP

=head1 AUTHOR

Author E<lt>sun.basix@gmail.comE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<>

=cut
