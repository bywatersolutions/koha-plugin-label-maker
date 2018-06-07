package Koha::Plugin::Com::ByWaterSolutions::LabelMaker;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Auth;

## Here we set our plugin version
our $VERSION = "{VERSION}";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Label Maker',
    author          => 'Kyle M Hall',
    date_authored   => '2018-06-07',
    date_updated    => "1900-01-01",
    minimum_version => '17.05.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'An alternative label creator for Koha powered by HTML and CSS'
};

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);

    return $self;
}

sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('submitted') ) {
        $self->tool_step1();
    }
    else {
        $self->tool_step2();
    }

}

sub install() {
    my ( $self, $args ) = @_;

    return C4::Context->dbh->do(q{
        CREATE TABLE plugin_label_maker_templates (
            `borrowernumber` INT( 11 ) NOT NULL
        ) ENGINE = INNODB;
    });
}

sub uninstall() {
    my ( $self, $args ) = @_;

    return C4::Context->dbh->do("DROP TABLE plugin_label_maker_templates");
}


sub tool_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'tool-step1.tt' });

    $self->output_html( $template->output() );
}

sub tool_step2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'tool-step2.tt' });

    $self->output_html( $template->output() );
}

1;
