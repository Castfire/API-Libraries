use LWP::Simple;
use LWP;
use JSON;
use DateTime;
use URI::Escape;
use MIME::Base64;
use Digest::MD5 qw(md5_hex);

sub call_castfire_upload {
  my $type = shift;
  my $params = shift;

  # these are our constants
  my $api_key     = "51779-41327-14842";
  my $api_secret  = "FhV2va3V3ldJ3WUJ";

  # build policy
  # another possibility instead of using DateTime: my $future_date = `date -d "+1 hour" -R`;
  my $dt = DateTime->now->add( hours => 1);
  my $future_date = $dt->strftime("%a, %d %b %Y %H:%M:%S %z");
  my $expiration = uri_escape($future_date);
  my $policy = encode_base64("expiration=$expiration&api_key=$api_key");
  
  # build signature
  my $md5sum = md5_hex($api_secret . $policy);
  my $api_sig = substr($md5sum, 0, 32);

  $params->{api_key}    = $api_key;
  $params->{policy}     = $policy;
  $params->{api_sig}    = $api_sig;

  if (exists $params->{"files[1]"}) {
    my $file = $params->{"files[1]"};
    $params->{"files[1]"} = [ $file ];
  }

  my $ua = LWP::UserAgent->new();
  $ua->timeout(3600);

  if ($params->{test}) {
    print Dumper($show);
    print "Test only, not uploading.\n";
    return 1;
  }

  my $response = $ua->post("http://api.castfire.com/upload/$type/", Content_Type => 'form-data', Content => $params);

  if ($response->is_success) {
      return $response->decoded_content;
  } else {
      return undef;
  }

}

sub update_castfire_playlist {
  my $name = shift;
  my $shows = shift;

  my $params = {
    network_id => 313,
    name => "$name",
    slug => "$name",
    tags => "aolhd,$name"
  };

  for (my $i=0; $i<scalar @$shows; $i++) {
    $params->{"show_ids[$i]"} = $shows->[$i];
  }

  my $result = &call_castfire_rest("playlists.add", $params);
  if ($result->{status} ne "ok") {
      return 0;
  }
  return $result->{id}{_content};
}

sub list_castfire_shows {
    my $channel_id = shift;
    my $result = &call_castfire_rest("shows.getList", { status => "published", type => "video", active => "true", order_by => "created", sequence => "desc", channel_id => $channel_id });
    my $show_ids = [];
    if ($result->{status} ne "ok") {
        return $show_ids;
    }
    foreach my $show (@{$result->{shows}{show}}) {
        push @$show_ids, $show->{id}{_content};
    }
    return $show_ids;
}

sub params {
    if ($a =~ /\[\d+\]/ and $b =~ /\[\d+\]/) {
        $a =~ /\[(\d+)\]/;
        $anum = $1;
        $b =~ /\[(\d+)\]/;
        $bnum = $1;
        return $anum <=> $bnum;
    } else {
        return $a cmp $b;
    }
}

sub call_castfire_rest {
  my $method = shift;
  my $params = shift;

  # these are our constants
  my $api_key     = "51779-41327-14842";
  my $api_secret  = "FhV2va3V3ldJ3WUJ";

  $params->{api_key}     = $api_key;
  $params->{method}      = $method;

  # build signature
  my $param_string = "";
  my @sorted_keys = sort params keys %$params;
  foreach my $key (@sorted_keys) {
        $param_string .= $key . $params->{$key};
  }
  my $md5sum = md5_hex($api_secret . $param_string);
  my $api_sig = substr($md5sum, 0, 32);

  #print "Parameters: $param_string\n";
  #print "API SIG: $api_sig\n";

  $params->{api_sig}     = $api_sig;

  my $ua = LWP::UserAgent->new();
  $ua->timeout(30);

  my @http_params = ();
  foreach my $key (keys %$params) {
    push @http_params, "$key=$params->{$key}";
  }
  my $query_string = join("&", @http_params);

  print "query: $query_string\n";

  my $response = $ua->get("http://api.castfire.com/rest/json?$query_string");

  if ($response->is_success) {
    #print STDERR "Response: " . $response->decoded_content;
    my $result = from_json($response->decoded_content);
    return $result;
  } else {
    print STDERR "  -> Error contacting castfire: " . $response->status_line, "\n";
    return undef;
  }

}

sub check_castfire_exists {
  my $foreign_key = shift;

  # these are our constants
  my $api_key     = "51779-41327-14842";
  my $api_secret  = "FhV2va3V3ldJ3WUJ";

  my $show = {};
  
  $show->{api_key}     = $api_key;
  $show->{method}      = "shows.getId";
  $show->{foreign_key} = $foreign_key;

  # build signature
  my $param_string = "api_key" . $show->{api_key} . "foreign_key" . $show->{foreign_key} . "method" . $show->{method};
  my $md5sum = md5_hex($api_secret . $param_string);
  my $api_sig = substr($md5sum, 0, 32);

  #print "Parameters: $param_string\n";
  #print "API SIG: $api_sig\n";

  $show->{api_sig}     = $api_sig;

  my $ua = LWP::UserAgent->new();
  $ua->timeout(30);

  my @params = ();
  foreach my $key (keys %$show) {
    push @params, "$key=$show->{$key}";
  }
  my $query_string = join("&", @params);

  my $response = $ua->get("http://api.castfire.com/rest/json?$query_string");

  if ($response->is_success) {
    #print STDERR "Response: " . $response->decoded_content;
    my $result = from_json($response->decoded_content);
    if ($result->{status} eq "fail") {
      if ($result->{error}{code} eq "143") {
        return 0;
      } else {
        printf "%s FAILED: [%d] %s\n", ($foreign_key, $result->{error}{code}, $result->{error}{message});
      }
      return 1;
    } else {
      return 1;
    }
  } else {
    print STDERR "  -> Error contacting castfire: " . $response->status_line, "\n";
    return 1;
  }

}

1;

