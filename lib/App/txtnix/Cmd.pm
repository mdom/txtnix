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
);

opt config => (
    isa     => 'Str',
    comment => 'Specify a custom config file location.',
);

subcmd
  cmd     => 'tweet',
  comment => 'Append a new tweet to your twtxt file.';

arg text => (
    isa      => 'Str',
    comment  => 'Message to tweet.',
    required => 1,
);

opt created_at => (
    isa     => 'Str',
    comment => 'ISO8601 datetime to use in Tweet, instead of current time.',
);

opt twtfile => (
    isa     => 'Str',
    comment => 'Location of your twtxt file.',
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
    default => 1,
);
opt time_format => (
    isa     => 'Str',
    comment => 'Format to display timestamps.',
);
opt limit => (
    isa     => 'Int',
    comment => 'Limit total number of shown tweets.',
);
opt ascending => (
    isa     => 'Bool',
    comment => 'Sort timeline in ascending order.',
);
opt descending => (
    isa     => 'Bool',
    comment => 'Sort timeline in descending order.',
);
opt since => (
    isa     => 'Str',
    comment => 'Only display tweets written after the supplied datetime.',
);
opt until => (
    isa     => 'Str',
    comment => 'Only display tweets written until the supplied datetime.',
);

subcmd
  cmd     => 'view',
  comment => 'Show feed of given source.';

arg source => (
    isa      => 'Str',
    comment  => 'Source to view.',
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
);
opt time_format => (
    isa     => 'Str',
    comment => 'Format to display timestamps.',
);
opt limit => (
    isa     => 'Int',
    comment => 'Limit total number of shown tweets.',
);
opt ascending => (
    isa     => 'Bool',
    comment => 'Sort timeline in ascending order.',
);
opt descending => (
    isa     => 'Bool',
    comment => 'Sort timeline in descending order.',
);
opt since => (
    isa     => 'Str',
    comment => 'Only display tweets written after the supplied datetime.',
);
opt until => (
    isa     => 'Str',
    comment => 'Only display tweets written until the supplied datetime.',
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

1;
