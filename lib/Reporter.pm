package Reporter;

use Mojo::Base -base, -signatures;

use Mojo::AsyncAwait;
use Mojo::Promise;
use Mojo::UserAgent;
use Mojo::URL;
use Text::CSV 'csv';
use Email::Stuffer;

has ua => sub { Mojo::UserAgent->new };

has mos_url   => sub { Mojo::URL->new('https://mos.servercentral.com/api/0/get_usage') };
has scope_url => sub { Mojo::URL->new('https://scope.servercentral.com/api/0/get_mos_clients') };

has from => sub { die 'from email is required' };
has to   => sub { die 'to email is required' };

async get_mos_clients => sub ($self) {
  my $url = $self->scope_url->clone;
  my $tx = await $self->ua->get_p($url);
  return $tx->result->json;
};

async get_usage_for_client => sub ($self, $client) {
  my $url = $self->mos_url->clone->query(id => $client);
  my $tx = await $self->ua->get_p($url);
  return $tx->result->json('/month');
};

async get_report_data => sub ($self) {
  my $clients = await $self->get_mos_clients;
  my $cb = async sub ($client) {
    my $usage = await $self->get_usage_for_client($client->{id});
    return { 
      id    => $client->{id},
      usage => $usage,
    };
  };
  my @res = await Mojo::Promise->map({concurrency => 5}, $cb, @$clients);
  return [ map { $_->[0] } @res ];
};

sub format_report ($self, $data) {
  csv(
    in => $data,
    out => \my $out,
    headers => ['id', 'usage'],
  );
  return $out;
}

async report => sub ($self) {
  my $data = await $self->get_report_data;
  my $csv  = $self->format_report($data);
  Email::Stuffer->from($self->from)
    ->to($self->to)
    ->attach($csv, filename => 'usage.csv')
    ->send_or_die;
};

1;

