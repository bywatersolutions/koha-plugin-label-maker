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
    date_updated    => "2025-09-03",
    minimum_version => '24.11.00.000',
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
        my $starting_label  = $cgi->param('starting_label');

        if ( $batch && $template && $layout ) {
            $self->print_labels(
                {
                    batch           => $batch,
                    template        => $template,
                    layout          => $layout,
                    printer_profile => $printer_profile,
                    starting_label  => $starting_label,
                }
            );
        }
        else {
            $self->print_labels_form();
        }
    }
    elsif ( $action eq 'patronprint' ) {
        my $batch           = $cgi->param('patronbatch');
        my $template        = $cgi->param('template');
        my $layout          = $cgi->param('layout');
        my $printer_profile = $cgi->param('printer_profile');
        my $starting_label  = $cgi->param('starting_label');

        if ( $batch && $template && $layout ) {
            $self->print_patron_labels(
                {
                    batch           => $batch,
                    template        => $template,
                    layout          => $layout,
                    printer_profile => $printer_profile,
                    starting_label  => $starting_label,
                }
            );
        }
        else {
            $self->print_patron_labels_form();
        }
    }
    elsif ( $action eq 'print_single') {
        my $itemnumber      = $cgi->param('itemnumber');
        my $barcode         = $cgi->param('barcode');
        my $quantity        = $cgi->param('quantity');
        my $template        = $cgi->param('template');
        my $layout          = $cgi->param('layout');
        my $printer_profile = $cgi->param('printer_profile');
        my $starting_label  = $cgi->param('starting_label');

        if ( $template && $layout ) {
            $self->print_labels(
                {
                    itemnumber      => $itemnumber,
                    barcode         => $barcode,
                    quantity        => $quantity,
                    template        => $template,
                    layout          => $layout,
                    printer_profile => $printer_profile,
                    starting_label  => $starting_label,
                }
            );
        }
        else {
            $self->print_labels_form();
        }
    }
    elsif ( $action eq 'quickprint') {
        my $barcode         = $cgi->param('barcode');
        my $template        = $cgi->param('template');
        my $layout          = $cgi->param('layout');
        my $printer_profile = $cgi->param('printer_profile');
        my $starting_label  = $cgi->param('starting_label');

        if ( $template && $layout ) {
            $self->print_quicklabels(
                {
                    barcode         => $barcode,
                    template        => $template,
                    layout          => $layout,
                    printer_profile => $printer_profile,
                    starting_label  => $starting_label,
                }
            );
        }
        else {
            $self->print_quicklabels_form();
        }
    }
    elsif ( $action eq 'edit' ) {
        my $type = $cgi->param('type');
	my %valid_types = map { $_ => 1 } qw(templates patron_templates layouts printer_profiles);
        warn Data::Dumper::Dumper( $type );
        unless (defined($type) && $valid_types{$type}) {
            warn "Invalid type parameter used: " . $type;
            return;
        }
        my $id   = $cgi->param('id');
        $self->edit( { type => $type, id => $id } );
    }
    elsif ( $action eq 'copy' ) {
        my $type = $cgi->param('type');
	my %valid_types = map { $_ => 1 } qw(templates patron_templates layouts printer_profiles);

        unless (defined($type) && $valid_types{$type}) {
            warn "Invalid type parameter used: " . $type;
            return;
        }
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
	my %valid_types = map { $_ => 1 } qw(templates patron_templates layouts printer_profiles);

        unless (defined($type) && $valid_types{$type}) {
            warn "Invalid type parameter used: " . $type;
            return;
        }
        my $id   = $cgi->param('id');
        $self->delete( { type => $type, id => $id } );
    }
    elsif ( $action eq 'wizard' ) {
        my $type = $cgi->param('type');
	my %valid_types = map { $_ => 1 } qw(templates patron_templates layouts printer_profiles);

        unless (defined($type) && $valid_types{$type}) {
            warn "Invalid type parameter used: " . $type;
            return;
        }
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

sub uninstall() {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    $dbh->do("DROP TABLE plugin_label_maker_templates");
    $dbh->do("DROP TABLE plugin_label_maker_patron_templates");
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

    my $patron_templates =
      $dbh->selectall_arrayref( 'SELECT * FROM plugin_label_maker_patron_templates',
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
        patrontemplates  => $patron_templates,
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

    my %valid_types = map { $_ => 1 } qw(templates patron_templates layouts printer_profiles);

    unless (defined($type) && $valid_types{$type}) {
        warn "Invalid type parameter used: " . $type;
        return;
    }
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

    my %valid_types = map { $_ => 1 } qw(templates patron_templates layouts printer_profiles);

    unless (defined($type) && $valid_types{$type}) {
        warn "Invalid type parameter used: " . $type;
        return;
    }
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

    my %valid_types = map { $_ => 1 } qw(templates patron_templates layouts printer_profiles);

    unless (defined($type) && $valid_types{$type}) {
        warn "Invalid type parameter used: " . $type;
        return;
    }
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
        'SELECT batch_id, COUNT(batch_id) AS items_count, branch_code FROM creator_batches WHERE creator = "Labels" GROUP BY batch_id ORDER BY timestamp DESC',
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

sub print_patron_labels_form {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    my $patron_templates =
        $dbh->selectall_arrayref( 'SELECT * FROM plugin_label_maker_patron_templates',
        { Slice => {} } );

    my $layouts =
        $dbh->selectall_arrayref( 'SELECT * FROM plugin_label_maker_layouts',
        { Slice => {} } );

    my $printer_profiles =
        $dbh->selectall_arrayref(
        'SELECT * FROM plugin_label_maker_printer_profiles',
        { Slice => {} } );

    my $patron_batches =
        $dbh->selectall_arrayref(
        'SELECT patron_list_id, COUNT(patron_list_id) as patrons_count FROM patron_list_patrons GROUP BY patron_list_id ORDER BY patron_list_id DESC',
        { Slice => {} } );

    my $template = $self->get_template( { file => 'print_patron_labels_form.tt' } );
    $template->param(
        patrontemplates  => $patron_templates,
        layouts          => $layouts,
        printer_profiles => $printer_profiles,
        batches          => $patron_batches,
    );

    $self->output_html( $template->output() );
}

sub print_quicklabels_form {
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

    my $template = $self->get_template( { file => 'print_quicklabels_form.tt' } );

    $template->param(
        templates        => $templates,
        layouts          => $layouts,
        printer_profiles => $printer_profiles,
    );

    $self->output_html( $template->output() );
}

sub print_labels {
    my ( $self, $args ) = @_;
    my $batch_id           = $args->{batch};
    my $template_id        = $args->{template};
    my $layout_id          = $args->{layout};
    my $printer_profile_id = $args->{printer_profile};
    my $starting_label     = $args->{starting_label} || 1;
    my $itemnumber         = $args->{itemnumber};
    my $barcode            = $args->{barcode};
    my $quantity           = $args->{quantity} || 1;

    my $dbh = C4::Context->dbh;

    my $batch =
      $batch_id
      ? $dbh->selectall_arrayref(
        'SELECT * FROM creator_batches WHERE batch_id = ?',
        { Slice => {} }, $batch_id )
      : undef;

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

    push( @items, undef ) for ( 1 .. $starting_label - 1 );

    if ( $batch ) {
        foreach my $b (@$batch) {
            my $item = Koha::Items->find( $b->{item_number} );
            push( @items, $item );
        }
    } elsif ( $itemnumber ) {
            my $item = Koha::Items->find( $itemnumber );
            push( @items, $item ) for 1..$quantity;
    } elsif ( $barcode ) {
            my $item = Koha::Items->find( { barcode => $barcode } );
            push( @items, $item ) for 1..$quantity;
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

sub print_patron_labels {
    my ( $self, $args ) = @_;
    my $patronlist_id      = $args->{batch};
    my $template_id        = $args->{template};
    my $layout_id          = $args->{layout};
    my $printer_profile_id = $args->{printer_profile};
    my $starting_label     = $args->{starting_label} || 1;
    my $barcode            = $args->{barcode};
    my $quantity           = $args->{quantity} || 1;
    my $dbh = C4::Context->dbh;

    my $patronlist =
        $patronlist_id
        ? $dbh->selectall_arrayref(
        'SELECT * FROM patron_list_patrons WHERE patron_list_id = ?',
        { Slice => {} }, $patronlist_id )
        : undef;
    my $template = $dbh->selectrow_hashref(
        "SELECT * FROM plugin_label_maker_patron_templates WHERE id = ?",
        undef, $template_id );
    my $layout = $dbh->selectrow_hashref(
        "SELECT * FROM plugin_label_maker_layouts WHERE id = ?",
        undef, $layout_id );
    my $printer_profile = $dbh->selectrow_hashref(
        "SELECT * FROM plugin_label_maker_printer_profiles WHERE id = ?",
        undef, $printer_profile_id );

    my @patrons;

    push( @patrons, undef ) for ( 1 .. $starting_label - 1 );

    my $page_template = $self->get_template( { file => 'print_patron_labels.tt' } );

    if ( $patronlist ) {
        foreach my $pl (@$patronlist) {
            my $patron = Koha::Patrons->find( $pl->{borrowernumber} );
            push( @patrons, $patron );
        }
    }
    $page_template->param(
        patrons                => \@patrons,
        labels_template        => $template,
        labels_layout          => $layout,
        labels_printer_profile => $printer_profile,
    );

    $self->output_html( $page_template->output() );
}

sub print_quicklabels {
    my ( $self, $args ) = @_;
    my $this_barcode       = $args->{barcode};
    my $template_id        = $args->{template};
    my $layout_id          = $args->{layout};
    my $printer_profile_id = $args->{printer_profile};
    my $starting_label     = $args->{starting_label} || 1;

    my $dbh = C4::Context->dbh;

    #remove leading whitespaces
    $this_barcode  =~ s/^\s+//;
    my $barcode = $dbh->selectrow_hashref(
        "SELECT * from items where barcode = ?",
        undef, $this_barcode );
    my $template = $dbh->selectrow_hashref(
        "SELECT * FROM plugin_label_maker_templates WHERE id = ?",
        undef, $template_id );
    my $layout = $dbh->selectrow_hashref(
        "SELECT * FROM plugin_label_maker_layouts WHERE id = ?",
        undef, $layout_id );
    my $printer_profile = $dbh->selectrow_hashref(
        "SELECT * FROM plugin_label_maker_printer_profiles WHERE id = ?",
        undef, $printer_profile_id );

    my $item = Koha::Items->find( $barcode->{itemnumber} );
    my $page_template = $self->get_template( { file => 'print_labels.tt' } );

    $page_template->param(
        items                  => $item,
        labels_template        => $template,
        labels_layout          => $layout,
        labels_printer_profile => $printer_profile,
    );

    $self->output_html( $page_template->output() );
}
=head2

    This method below attaches to any Koha::Item objects,
    modifying them by adding a marc() method that will return
    the MARC::Record object related to this item's record with
    item MARC embedded

=cut

sub Koha::Item::marc {
    my ($item) = @_;
    my $marc = C4::Biblio::GetMarcBiblio(
        {
            biblionumber => $item->biblionumber,
            embed_items  => 1,
        }
    );
    return $marc;
}

sub wizard {
    my ( $self, $args ) = @_;
    my $type = $args->{type};

    my %valid_types = map { $_ => 1 } qw(templates patron_templates layouts printer_profiles);

    unless (defined($type) && $valid_types{$type}) {
        warn "Invalid type parameter used: " . $type;
        return;
    }
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
    my %valid_types = map { $_ => 1 } qw(templates patron_templates layouts printer_profiles);

    unless (defined($type) && $valid_types{$type}) {
        warn "Invalid type parameter used: " . $type;
        return;
    }
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

sub upgrade {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS plugin_label_maker_templates (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        content TEXT
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS plugin_label_maker_patron_templates (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        content TEXT
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS plugin_label_maker_layouts (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        content TEXT
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS plugin_label_maker_printer_profiles (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        content TEXT
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    });


    return 1;
}

sub install() {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS plugin_label_maker_templates (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        content TEXT
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS plugin_label_maker_patron_templates (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        content TEXT
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS plugin_label_maker_layouts (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        content TEXT
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS plugin_label_maker_printer_profiles (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        content TEXT
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    });

    $dbh->do(q|
        INSERT IGNORE INTO `plugin_label_maker_layouts` (`id`, `name`, `content`) VALUES

(1,'Avery 5630','html, body, div, span, h1 {
  margin: 0;
  padding: 0;
  border: 0;
}

body {
  width: 8.5in;
}

.page {
  padding-top: .5in; /* Height from top of page to top of first label row */
  margin-left: .25in; /* Width of gap from left of page to left edge of first label column */

  page-break-after: always;
  clear: left;
  display: block;
}

.label {
  width: 2.625in; /* Width of actual label */
  height: 1in; /* Height of actual label */
  margin-right: 0in; /* Distance between each column of labels */

  float: left;

  text-align: center;
  overflow: hidden;

  /* Uncomment for testing and debugging */
  outline: 1px dotted;
}

.page-break  {
  clear: left;
  display: block;
  page-break-after: always;
}'),


(2,'Basix 55-459-007','html, body, div, span, h1 {
  margin: 0;
  padding: 0;
  border: 0;
}

body {
  width: 8.5in;
}

.page {
  padding-top: .5in; /* Height from top of page to top of first label row */
  margin-left: .25in; /* Width of gap from left of page to left edge of first label column */

  page-break-after: always;
  clear: left;
  display: block;
}

.label {
  width: 8.5in; /* Width of actual label */

  margin-right: 0in; /* Distance between each column of labels */

  float: left;
  text-align: center;
  overflow: hidden;

  outline: 1px dotted white;
}

.left-label {
  width: 1in;
  height: 1in;
  margin-right: .5in;


  float: left;
  text-align: center;
  overflow: hidden;

  background-color: red;
}

.center-label {
  width: 3in;
  height: 1in;
  margin-right: .5in;

  float: left;
  text-align: center;
  overflow: hidden;

  background-color: green;
}

.right-label {
  width: 3in;
  height: 1in;

  float: left;
  text-align: center;
  overflow: hidden;

  background-color: blue;
}');
    |);

    $dbh->do(q|
        INSERT IGNORE INTO `plugin_label_maker_templates` (`id`, `name`, `content`) VALUES
(1,'Avery Standard Labels','[% FOREACH item IN items %]
    [% IF loop.index % 30 == 0 %]
        [% SET label_index = 1 %]
        [% UNLESS loop.first %]
            </span>
        [% END %]
        <span class="page">
    [% END %]

    <div class="label label[% label_index %]">
        [% item.biblio.title %]

        <br/>

        [% IF item.barcode %]
            <img src="/cgi-bin/koha/svc/barcode?barcode=[% item.barcode %]&type=Matrix2of5" />
        [% END %]

        <br/>

        [% item.itemnumber %]
    </div>
    [% IF loop.last %]</span>[% END %]
    [% SET label_index = label_index + 1 %]
[% END %]'),


(2,'Basix 55-459-007','[% FOREACH item IN items %]
    [% IF loop.index % 8 == 0 %]
        [% SET label_index = 1 %]
        [% UNLESS loop.first %]
            </span>
        [% END %]
        <span class="page">
    [% END %]

    <div class="label label[% label_index %]">
       <div class="left-label">
           [% item.biblio.title %]
       </div>

       <div class="center-label">
           [% item.biblio.title %]
           <br/>
           [% IF item.barcode %]
               <img src="/cgi-bin/koha/svc/barcode?barcode=[% item.barcode %]&type=Matrix2of5" />
           [% END %]
       </div>

       <div class="right-label">
           [% item.biblio.title %]
           <br/>
           [% IF item.barcode %]
               <img src="/cgi-bin/koha/svc/barcode?barcode=[% item.barcode %]&type=Matrix2of5" />
            [% END %]
       </div>
    </div>
    [% IF loop.last %]</span>[% END %]
    [% SET label_index = label_index + 1 %]
[% END %]');
    |);

    $dbh->do(q|
        INSERT IGNORE INTO `plugin_label_maker_patron_templates` (`id`, `name`, `content`) VALUES
(1,'Avery Standard Labels','[% FOREACH patron IN patrons %]
    [% IF loop.index % 30 == 0 %]
        [% SET label_index = 1 %]
        [% UNLESS loop.first %]
            </span>
        [% END %]
        <span class="page">
    [% END %]

    <div class="label label[% label_index %]">
        [% patron.firstname %] [% patron.surname %]

        <br/>

        [% IF patron.cardnumber %]
            <img src="/cgi-bin/koha/svc/barcode?barcode=[% patron.cardnumber %]&type=Matrix2of5" />
        [% END %]

        <br/>

        [% patron.cardnumber %]
    </div>
    [% IF loop.last %]</span>[% END %]
    [% SET label_index = label_index + 1 %]
[% END %]');
    |);
    return 1;
}

1;
