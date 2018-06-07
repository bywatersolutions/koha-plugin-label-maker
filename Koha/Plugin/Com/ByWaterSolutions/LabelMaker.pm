package Koha::Plugin::Com::ByWaterSolutions::LabelMaker;

use Modern::Perl;

use Template;

use base qw(Koha::Plugins::Base);

use C4::Context;
use C4::Auth;
use Koha::Items;
use Koha::Biblios;
use Koha::Biblioitems;

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

    my $cgi = $self->{cgi};

    my $action = $cgi->param('action') || q{};

    if ( $action eq 'print' ) {
        my $batch           = $cgi->param('batch');
        my $template        = $cgi->param('template');
        my $layout          = $cgi->param('layout');
        my $printer_profile = $cgi->param('printer_profile');

        if ( $batch && $template && $layout ) {
            $self->print_labels(
                {
                    batch           => $batch,
                    template        => $template,
                    layout          => $layout,
                    printer_profile => $printer_profile
                }
            );
        }
        else {
            $self->print_labels_form();
        }
    }
    elsif ( $action eq 'edit' ) {
        my $type = $cgi->param('type');
        my $id   = $cgi->param('id');
        $self->edit( { type => $type, id => $id } );
    }
    elsif ( $action eq 'copy' ) {
        my $type = $cgi->param('type');
        my $id   = $cgi->param('id');
        $self->edit( { type => $type, id => $id, copy => 1 } );
    }
    elsif ( $action eq 'store' ) {
        my $type    = $cgi->param('type');
        my $id      = $cgi->param('id');
        my $name    = $cgi->param('name');
        my $content = $cgi->param('content');
        $self->store(
            {
                type    => $type,
                id      => $id,
                name    => $name,
                content => $content,
            }
        );
    }
    elsif ( $action eq 'delete' ) {
        my $type = $cgi->param('type');
        my $id   = $cgi->param('id');
        $self->delete( { type => $type, id => $id } );
    }
    elsif ( $action eq 'wizard' ) {
        my $type = $cgi->param('type');
        $self->wizard( { type => $type } );
    }
    elsif ( $action eq 'wizard_store' ) {
        my $type = $cgi->param('type');
        my $name = $cgi->param('name');
        $self->wizard_store( { type => $type, name => $name, cgi => $cgi } );
    }
    else {
        $self->label_maker_home();
    }
}

sub install() {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    $dbh->do(q{
        CREATE TABLE plugin_label_maker_templates (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        content TEXT
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    });

    $dbh->do(q{
        CREATE TABLE plugin_label_maker_layouts (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        content TEXT
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    });

    $dbh->do(q{
        CREATE TABLE plugin_label_maker_printer_profiles (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        content TEXT
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    });

    return 1;
}

sub uninstall() {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    $dbh->do("DROP TABLE plugin_label_maker_templates");
    $dbh->do("DROP TABLE plugin_label_maker_layouts");
    $dbh->do("DROP TABLE plugin_label_maker_printer_profiles");

    return 1;
}


sub label_maker_home {
    my ( $self, $args ) = @_;

    my $tab = $args->{tab};

    my $dbh = C4::Context->dbh;

    my $templates =
      $dbh->selectall_arrayref( 'SELECT * FROM plugin_label_maker_templates',
        { Slice => {} } );

    my $layouts =
      $dbh->selectall_arrayref( 'SELECT * FROM plugin_label_maker_layouts',
        { Slice => {} } );

    my $printer_profiles =
      $dbh->selectall_arrayref(
        'SELECT * FROM plugin_label_maker_printer_profiles',
        { Slice => {} } );

    my $template = $self->get_template( { file => 'label_maker_home.tt' } );

    $template->param(
        tab              => $tab,
        templates        => $templates,
        layouts          => $layouts,
        printer_profiles => $printer_profiles,
    );

    $self->output_html( $template->output() );
}

sub edit {
    my ( $self, $args ) = @_;
    my $type = $args->{type};
    my $id   = $args->{id};
    my $copy = $args->{copy};

    my $dbh = C4::Context->dbh;

    my $table = "plugin_label_maker_$type";
    my $query = "SELECT * FROM $table WHERE id = ?";
    my $data  = $dbh->selectrow_hashref( $query, undef, $id );

    my $template = $self->get_template( { file => 'edit.tt' } );

    $template->param(
        type => $type,
        data => $data,
        copy => $copy,
    );

    $self->output_html( $template->output() );
}

sub store {
    my ( $self, $args ) = @_;
    my $type    = $args->{type};
    my $id      = $args->{id};
    my $name    = $args->{name};
    my $content = $args->{content};

    my $dbh = C4::Context->dbh;

    my $table = "plugin_label_maker_$type";

    if ($id) {
        my $query = "UPDATE $table SET name = ?, content = ? WHERE id = ?";
        $dbh->do( $query, undef, $name, $content, $id );
    }
    else {
        my $query = "INSERT INTO $table ( name, content ) VALUES ( ?, ? )";
        $dbh->do( $query, undef, $name, $content );
    }

    $self->label_maker_home({ tab => $type });
}

sub delete {
    my ( $self, $args ) = @_;
    my $type    = $args->{type};
    my $id      = $args->{id};

    my $dbh = C4::Context->dbh;

    my $table = "plugin_label_maker_$type";

    my $query = "DELETE FROM $table WHERE id = ?";
    $dbh->do( $query, undef, $id );

    $self->label_maker_home({ tab => $type });
}

sub print_labels_form {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    my $templates =
      $dbh->selectall_arrayref( 'SELECT * FROM plugin_label_maker_templates',
        { Slice => {} } );

    my $layouts =
      $dbh->selectall_arrayref( 'SELECT * FROM plugin_label_maker_layouts',
        { Slice => {} } );

    my $printer_profiles =
      $dbh->selectall_arrayref(
        'SELECT * FROM plugin_label_maker_printer_profiles',
        { Slice => {} } );

    my $batches =
      $dbh->selectall_arrayref(
        'SELECT batch_id, COUNT(batch_id) AS items_count FROM creator_batches WHERE creator = "Labels" GROUP BY batch_id ORDER BY timestamp DESC',
        { Slice => {} } );

    my $template = $self->get_template( { file => 'print_labels_form.tt' } );

    $template->param(
        templates        => $templates,
        layouts          => $layouts,
        printer_profiles => $printer_profiles,
        batches          => $batches,
    );

    $self->output_html( $template->output() );
}

sub print_labels {
    my ( $self, $args ) = @_;
    my $batch_id           = $args->{batch};
    my $template_id        = $args->{template};
    my $layout_id          = $args->{layout};
    my $printer_profile_id = $args->{printer_profile};

    my $dbh = C4::Context->dbh;

    my $batch =
      $dbh->selectall_arrayref(
        'SELECT * FROM creator_batches WHERE batch_id = ?',
        { Slice => {} }, $batch_id );

    my $template = $dbh->selectrow_hashref(
        "SELECT * FROM plugin_label_maker_templates WHERE id = ?",
        undef, $template_id );
    my $layout = $dbh->selectrow_hashref(
        "SELECT * FROM plugin_label_maker_layouts WHERE id = ?",
        undef, $layout_id );
    my $printer_profile = $dbh->selectrow_hashref(
        "SELECT * FROM plugin_label_maker_printer_profiles WHERE id = ?",
        undef, $printer_profile_id );

    my @items;
    my @labels;
    foreach my $b (@$batch) {
        my $item = Koha::Items->find( $b->{item_number} );
        push( @items, $item );
    }

    my $page_template = $self->get_template( { file => 'print_labels.tt' } );

    $page_template->param(
        items                  => \@items,
        labels_template        => $template,
        labels_layout          => $layout,
        labels_printer_profile => $printer_profile,
    );

    $self->output_html( $page_template->output() );
}

sub wizard {
    my ( $self, $args ) = @_;
    my $type = $args->{type};

    my $filename = qq{wizard_$type.tt};

    my @item_columns = Koha::Items->columns();
    my @biblio_columns = Koha::Biblios->columns();
    my @biblioitem_columns = Koha::Biblioitems->columns();

    my $template = $self->get_template( { file => $filename } );

    $template->param(
        columns => {
            item       => \@item_columns,
            biblio     => \@biblio_columns,
            biblioitem => \@biblioitem_columns,
        }
    );

    $self->output_html( $template->output() );
}

sub wizard_store {
    my ( $self, $args ) = @_;
    my $type = $args->{type};
    my $name = $args->{name};
    my $cgi  = $args->{cgi};

    my $params = $cgi->Vars;

    my $filename = qq{wizard_generator_$type.tt};

    my $template = $self->get_template( { file => $filename } );

    $template->param( %$params );

    my $content = $template->output();

    my $dbh = C4::Context->dbh;
    my $table = "plugin_label_maker_$type";
    my $query = "INSERT INTO $table ( name, content ) VALUES ( ?, ? )";
    $dbh->do( $query, undef, $name, $content );

    $self->label_maker_home();
}

1;