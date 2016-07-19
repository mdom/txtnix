<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<title>twtxt</title>
</head>
<body id="home">

% for my $t ( @$tweets ) {
<p>➤<%= $t->nick %> (<%= $t->formatted_time %>)<br>
%= $t->text
</p>
% }

</body>
</html>
