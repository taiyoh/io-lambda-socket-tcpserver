use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'      => 'IO::Lambda::Socket::TCPServer',
    'VERSION_FROM' => 'lib/IO/Lambda/Socket/TCPServer.pm', # finds $VERSION
    'PREREQ_PM' => {
	Test::More => 0.32,
    },
);
