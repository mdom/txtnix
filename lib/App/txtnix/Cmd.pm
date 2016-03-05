package App::txtnix::Cmd;
use Mojo::Base -base;
use OptArgs;

arg command => (
    isa      => 'SubCmd',
    comment  => 'sub command to run',
    required => 1,
);

opt help => (
    isa     => 'Bool',
    comment => 'Print a help message and exit.',
    ishelp  => 1,
    alias   => 'h',
);

opt config => (
    isa     => 'Str',
    comment => 'Specify a custom config file location.',
    alias   => 'c',
);

subcmd
  cmd     => 'tweet',
  comment => 'Append a new tweet to your twtxt file.';

arg text => (
    isa     => 'Str',
    comment => 'Message to tweet.',
);

opt created_at => (
    isa     => 'Str',
    comment => 'RFC 3339 datetime to use in Tweet, instead of current time.',
    alias   => 'a',
);

opt twtfile => (
    isa     => 'Str',
    comment => 'Location of your twtxt file.',
    alias   => 't',
);

opt hooks => (
    isa     => 'Bool',
    comment => 'Run hooks.',
    alias   => 'r',
);

subcmd
  cmd     => 'timeline',
  comment => 'Retrieve your personal timeline.';

opt cache => (
    isa     => 'Bool',
    comment => 'Cache remote twtxt files locally.',
);
opt cache_dir => (
    isa     => 'Str',
    comment => 'Directory for saving twtxt files locally.',
);
opt timeout => (
    isa     => 'Int',
    comment => 'Maximum time requests are allowed to take.',
);
opt pager => (
    isa     => 'Bool',
    comment => 'Use a pager to display content.',
    alias   => 'p',
);
opt time_format => (
    isa     => 'Str',
    comment => 'Format to display timestamps.',
    alias   => 'f',
);
opt limit => (
    isa     => 'Int',
    comment => 'Limit total number of shown tweets.',
    alias   => 'l',
);
opt ascending => (
    isa     => 'Bool',
    comment => 'Sort timeline in ascending order.',
    alias   => 'a',
);
opt descending => (
    isa     => 'Bool',
    comment => 'Sort timeline in descending order.',
    alias   => 'd',
);
opt since => (
    isa     => 'Str',
    comment => 'Only display tweets written after the supplied datetime.',
    alias   => 's',
);
opt until => (
    isa     => 'Str',
    comment => 'Only display tweets written until the supplied datetime.',
    alias   => 'u',
);
opt me => (
    isa     => 'Bool',
    comment => 'Only display your tweets and all replies and mentions.',
    alias   => 'm',
);

subcmd
  cmd     => 'view',
  comment => 'Show feed of given source.';

arg source => (
    isa      => 'Str',
    comment  => 'Nick or URL to view.',
    required => 1,
);

opt cache => (
    isa     => 'Bool',
    comment => 'Cache remote twtxt files locally.',
);
opt cache_dir => (
    isa     => 'Str',
    comment => 'Directory for saving twtxt files locally.',
);
opt timeout => (
    isa     => 'Int',
    comment => 'Maximum time requests are allowed to take.',
);
opt pager => (
    isa     => 'Bool',
    comment => 'Use a pager to display content.',
    alias   => 'p',
);
opt time_format => (
    isa     => 'Str',
    comment => 'Format to display timestamps.',
    alias   => 'f',
);
opt limit => (
    isa     => 'Int',
    comment => 'Limit total number of shown tweets.',
    alias   => 'l',
);
opt ascending => (
    isa     => 'Bool',
    comment => 'Sort timeline in ascending order.',
    alias   => 'a',
);
opt descending => (
    isa     => 'Bool',
    comment => 'Sort timeline in descending order.',
    alias   => 'd',
);
opt since => (
    isa     => 'Str',
    comment => 'Only display tweets written after the supplied datetime.',
    alias   => 's',
);
opt until => (
    isa     => 'Str',
    comment => 'Only display tweets written until the supplied datetime.',
    alias   => 'u',
);

subcmd
  cmd     => 'follow',
  comment => 'Add a new source to your followings.';

arg nickname => (
    isa      => 'Str',
    comment  => 'Local nickname for url.',
    required => 1,
);

arg url => (
    isa      => 'Str',
    comment  => 'URL for follow.',
    required => 1,
);

subcmd
  cmd     => 'unfollow',
  comment => 'Remove an existing source from your followings.';

arg nickname => (
    isa      => 'Str',
    comment  => 'Nick to unfollow.',
    required => 1,
);

subcmd
  cmd     => 'following',
  comment => q{Return the list of sources you're following.};

arg nickname => (
    isa     => 'Str',
    comment => 'Search for NICKNAME.',
);

subcmd
  cmd     => 'config',
  comment => 'Get or set config item.';

arg command => (
    isa      => 'SubCmd',
    comment  => 'sub command to run',
    required => 1,
);

subcmd
  cmd     => [qw( config edit)],
  comment => 'Edit configuration file.';

subcmd
  cmd     => [qw( config get)],
  comment => 'Get configuration option.';

arg key => (
    isa      => 'Str',
    comment  => 'Configuration option to get.',
    required => 1,
);

subcmd
  cmd     => [qw( config set)],
  comment => 'Set configuration option.';

arg key => (
    isa      => 'Str',
    comment  => 'Configuration option to set.',
    required => 1,
);

arg value => (
    isa      => 'Str',
    comment  => 'Value configuration option to set to.',
    required => 1,
);

subcmd
  cmd     => [qw( config remove)],
  comment => 'Remove configuration option.';

arg key => (
    isa      => 'Str',
    comment  => 'Configuration option to remove.',
    required => 1,
);

subcmd
  cmd     => 'query',
  comment => 'Query your registry.';

arg command => (
    isa      => 'SubCmd',
    comment  => 'sub command to run',
    required => 1,
);

subcmd
  cmd     => [qw( query users)],
  comment => 'Query registry for users.';

arg search_term => (
    isa     => 'Str',
    comment => 'Search term.',
);

opt limit => (
    isa     => 'Int',
    comment => 'Limit total number of shown users.',
    alias   => 'l',
);

opt unfollowed => (
    isa     => 'Bool',
    comment => 'Only list users you are not already following.',
);

subcmd
  cmd     => [qw( query mentions)],
  comment => 'Query registry for mentions.';

arg search_term => (
    isa      => 'Str',
    comment  => 'Search term.',
    required => 1,
);

subcmd
  cmd     => [qw( query tags)],
  comment => 'Query registry for tags.';

arg search_term => (
    isa      => 'Str',
    comment  => 'Search term.',
    required => 1,
);

subcmd
  cmd     => [qw( query tweets)],
  comment => 'Query registry for tweets.';

arg search_term => (
    isa     => 'Str',
    comment => 'Search term.',
);

subcmd
  cmd     => 'register',
  comment => 'Register at your registry.';

1;
