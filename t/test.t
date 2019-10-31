use Test2::V0;
use Mojo::Base -strict, -signatures;

use Mojolicious;
use Mojo::AsyncAwait;
use Mojo::URL;
use Reporter;

my $r = Reporter->new(
  mos_url   => Mojo::URL->new('/mos'),
  scope_url => Mojo::URL->new('/scope'),
  from => 'from@example.com',
  to => 'to@example.com',
);

my $mock = Mojolicious->new;
$mock->log->level('fatal');

my $clients = [{ id => 2 }, { id => 3 }];
$mock->routes->get('/scope' => sub ($c) { $c->render(json => $clients) });

my $req_id;
$mock->routes->get('/mos' => sub ($c) {
  $req_id = $c->param('id');
  $c->render(json => { month => 100 });
});
$r->ua->server->app($mock);

async tests => sub() {
  {
    my $got = await $r->get_mos_clients;
    is $got, $clients, 'got expected client list';
  }

  {
    my $got = await $r->get_usage_for_client(2);
    is $req_id, 2, 'got expected request id';
    is $got, 100, 'got expected usage';
  }

  {
    my $got = await $r->get_report_data;
    is $got, [{ id => 2, usage => 100 }, { id => 3, usage => 100 }], 'got expected data';
    #warn $r->format_report($got);
  }

  {
    $ENV{EMAIL_SENDER_TRANSPORT} = 'Test';
    await $r->report;
    my @emails = Email::Sender::Simple->default_transport->deliveries;
    is scalar(@emails), 1, 'sent one email';
    is $emails[0]{envelope}{from}, 'from@example.com', 'expected sender';
    is $emails[0]{envelope}{to}[0], 'to@example.com', 'expected recipient';
    is $emails[0]{email}->get_header('Content-Type'), 'text/csv', 'right type';
    #warn Mojo::Util::dumper $emails[0];
  }

  done_testing;
};

tests()->wait;


