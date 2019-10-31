requires 'Mojolicious';
requires 'Mojo::AsyncAwait';
requires 'Email::Stuffer';
requires 'Text::CSV';

on test => sub {
  requires 'Test2::V0';
};
