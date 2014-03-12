#!/usr/bin/perl
###############################################################################
# Copyright (C) 2012 Renato "Lond" Cerqueira                                  #
#                                                                             #
# This file is part of filmow-friends.                                        #
#                                                                             #
# filmow-friends is free software: you can redistribute it and/or modify      #
# it under the terms of the GNU General Public License as published by        #
# the Free Software Foundation, either version 3 of the License, or           #
# (at your option) any later version.                                         #
#                                                                             #
# filmow-friends is distributed in the hope that it will be useful,           #
# but WITHOUT ANY WARRANTY; without even the implied warranty of              #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               #
# GNU General Public License for more details.                                #
#                                                                             #
# You should have received a copy of the GNU General Public License           #
# along with filmow-friends.  If not, see <http://www.gnu.org/licenses/>.     #
###############################################################################

use LWP::Simple;
use LWP::UserAgent;
use HTML::DOM;
use Class::Struct;
use strict;
use DBI;
use DBD::SQLite;
use Data::Dumper;

struct( Movie => {
        mv_title => '$',
        mv_img => '$',
        mv_link => '$',
        mv_html => '$'
        }); 

struct( User => {
        usr_name => '$',
        usr_login => '$',
        usr_count => '$'
        });

my $ua = LWP::UserAgent->new("agent"=>"Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/7.0.540.0 Safari/534.10");

my @users = ();
my @user_pages = ();
my @user_names = ();
my @quero_ver_lists = ();

my $site = "http://filmow.com";

push(@users, "user1");
push(@users, "user2");
push(@users, "user3");
push(@users, "user4");

sub get_name_and_count
{
    my $site = shift;
    my $profile = shift;
    my $url = $site.$profile."?test=444";
    my $content = $ua->get($url);
    die "Couldn't get $url. $!" unless defined $content;
    my $dom_tree = new HTML::DOM;
    $dom_tree->write($content->decoded_content);
    $dom_tree->close();

    my $name = $dom_tree->getElementsByClassName("name")->[0]->innerHTML;

    my @seeCount = $dom_tree->getElementsByClassName("seeCount");

    my $count;

    foreach (@seeCount)
    {
        my $str = $_->innerHTML;
        if($str =~ m!\Qfilmes/quero-ver/"\E>([0-9]+)!)
        {
            $count = $1;
        }
    }

    my %ret = ();
    $ret{"name"} = $name;
    $ret{"count"} = $count;
    return %ret;
}

sub clear_cache
{
  my $u = shift;

  my $dbh = DBI->connect("dbi:SQLite:dbname=demo.db", "", "");

  my $query = "SELECT id FROM users where login = ?";
  my $sth = $dbh->prepare($query);
  $sth->execute($u->usr_login);
  $sth->bind_columns(\my($id));
  $sth->fetch();

  $query = "DELETE FROM users_movies where users_id = ?";
  $sth = $dbh->prepare($query);
  $sth->execute($id);

  $query = "DELETE FROM users where id = ?";
  $sth = $dbh->prepare($query);
  $sth->execute($id);
}

sub save_cache
{
  my $u = shift;
  my @movies = @_;

  my $dbh = DBI->connect("dbi:SQLite:dbname=demo.db", "", "");
  my $dbh2 = DBI->connect("dbi:SQLite:dbname=demo.db", "", "");
  my $dbh3 = DBI->connect("dbi:SQLite:dbname=demo.db", "", "");

  # first, a little checking to ensure everything is fine.
  if(scalar(@movies) != $u->usr_count)
  {
    return;
  }

  my $query = "INSERT INTO 'users' (name, login, last_cached, movies_count) values (?, ?, ?, ?)";
  my $query_handle = $dbh->prepare($query);
  $query_handle->execute($u->usr_name, $u->usr_login, time, $u->usr_count);
  my $key = $dbh->last_insert_id("","","",""); 

  my $query_movies = "INSERT into 'movies' (title, img, link, html) values (?, ?, ?, ?)";
  my $query_users_movies = "INSERT into 'users_movies' (users_id, movies_id) values (?, ?)";
  my $query_exists_movie = "SELECT id FROM movies where link = ?";
  my $query_movies_handle = $dbh2->prepare($query_movies);
  my $query_users_movies_handle = $dbh->prepare($query_users_movies);
  my $sth = $dbh3->prepare($query_exists_movie);

  foreach my $m (@movies)
  {
    $sth->execute($m->mv_link);
    $sth->bind_columns(\my($id));
    my $mkey;
    if($sth->fetch())
    {
      $mkey = $id;
    }
    else
    {
      $query_movies_handle->execute($m->mv_title, $m->mv_img, $m->mv_link, $m->mv_html);
      $mkey = $dbh2->last_insert_id("","","","");
    }
    $query_users_movies_handle->execute($key, $mkey);
  }
}

sub check_cache
{
    my $u = shift;
    my @movies = @_;

    my $dbargs;
    my $dbh = DBI->connect("dbi:SQLite:dbname=demo.db", "", "", $dbargs);

    my $query = "SELECT * FROM users where login = ?";
    my $query_handle = $dbh->prepare($query);
    $query_handle->execute($u->usr_login);
    
    $query_handle->bind_columns(\my($id, $name, $login, $last_cached, $movies_count));

    my $total = 0;

    while($query_handle->fetch())
    {
        $total++;
    }

    if($total == 0)
    {
      print STDERR "Cache: no record.\n";
      # don't have a record about this user, let the crawler get the user data
      return;
    }
    else
    {
      # we have some cache. Check if it is up to date.
      if($movies_count != $u->usr_count)
      {
        print STDERR "Cache: counts differ.\n";
        # cache is not up to date. clear the cache for this user, let the crawler get the user data.
        clear_cache($u);
        return;
      }

      print STDERR "Cache: Trying to get movies for user $id\n";
      my $query_movies = "SELECT m.* FROM movies m INNER JOIN users_movies um ON ( m.id = um.movies_id ) WHERE um.users_id = ?";
      my $query_movies_handle = $dbh->prepare($query_movies);
      $query_movies_handle->execute($id);

      $query_movies_handle->bind_columns(\my($m_id, $m_title, $m_img, $m_link, $m_html));

      my $m_total = 0;

      my $cache_is_valid = 1;

      my %hash = ();

      while($query_movies_handle->fetch())
      {
        if($m_total < scalar(@movies) && $m_link ne $movies[$m_total]->mv_link)
        {
          $cache_is_valid = 0;
        }
        my $m = new Movie;
        $m->mv_title($m_title);
        $m->mv_img($m_img);
        $m->mv_link($m_link);
        $m->mv_html($m_html);
        $hash{$m->mv_link} = $m;
        $m_total++;
      }
      if($cache_is_valid)
      {
        return %hash;
      }
      else
      {
        # user has new movies, even though the count is the same. clear cache, let the crawler get the data.

        clear_cache($u);
        return;
      }
    }
    return;
}

sub get_movies
{
    my $site = shift;
    my $next_page = shift;
    my $u = shift;
    my %hash = ();
    my $i = 0;
    my $page = 0;
    my @movies = ();
    do
    {
        my $url = $site . $next_page;
        print STDERR $next_page,"\n";
        my $content = $ua->get($url);
        die "Couldn't get $url. $!" unless defined $content;

        my $dom_tree = new HTML::DOM;
        $dom_tree->write($content->decoded_content);
        $dom_tree->close();

        my @my_movies = $dom_tree->getElementsByClassName("movie_list_item");

        foreach (@my_movies)
        {
            my $m = new Movie;
            my $img = $_->getElementsByClassName("wrapper")->[0]->getElementsByTagName("img")->[0];
            $m->mv_img($img->attributes->getNamedItem("src"));
            $m->mv_title($img->attributes->getNamedItem("alt"));
            my $href = $_->getElementsByClassName("wrapper")->[0]->getElementsByTagName("A")->[0]; 
            $m->mv_link($href->attributes->getNamedItem("href"));

            my $poster = $_->getElementsByClassName("cover")->[0];
            my $title = $_->getElementsByClassName("title")->[0];
            my $html = "<span class=\"wrapper\">".$poster->as_HTML."</span>\n";

            my $new_string = $site.$m->mv_link;
            my $test = quotemeta($m->mv_link);
            $html =~ s!$test!$new_string!g;
            $m->mv_html($html);

            $hash{$m->mv_link} = $m;
            $movies[$i] = $m;
            $i++;
        }

        if($page == 0)
        {
          my %cache = check_cache($u, @movies);
          if(%cache)
          {
            print STDERR "Using cache!\n";
            return %cache;
          }
        }

        my @next_pages = ();
		my $next_length = 0;
		if($dom_tree->getElementsByClassName("pagination")->length > 0) {
		  @next_pages = $dom_tree->getElementsByClassName("pagination")->[0]->getElementsByTagName("ul")->[0]->getElementsByTagName("li");
		  $next_length = $dom_tree->getElementsByClassName("pagination")->[0]->getElementsByTagName("ul")->[0]->getElementsByTagName("li")->length;
		}
        if($next_length > 0)
        {
			my $next = 0;
			foreach(@next_pages)
			{
				if($_->getElementsByClassName("active")->length!=0) {
					last;
				}
				$next++;
			}
			if($next+1 < $next_length) {
			  $next_page = $next_pages[$next+1]->getElementsByTagName("A")->[0]->attributes->getNamedItem("href");
			}
			else {
				undef $next_page;
			}
        }
        else
        {
          undef $next_page;
        }
        print STDERR scalar(keys %hash)," filmes\n";
        $page++;
    } while($next_page ne "");

    save_cache($u, @movies);

    return %hash;
}

my $i = 0;

my $compare_string_html;
my $compare_string;

foreach my $user (@users)
{
    my $u = new User;
    $u->usr_login($user);
    push(@user_pages, "/usuario/$user/");
    my %ret = get_name_and_count($site, $user_pages[$i]);
    my $user_name = $ret{"name"};
    my $movie_count = $ret{"count"};
    $u->usr_name($user_name);
    $u->usr_count($movie_count);
    push(@user_names, $user_name);
    my $next_page = $user_pages[$i]."filmes/quero-ver";
    my %quero_ver = get_movies($site, $next_page, $u);

    if($i != 0 && $i == scalar(@users) - 1)
    {
        $compare_string_html .= " e ";
        $compare_string .= " e ";
    }
    elsif($i != 0)
    {
        $compare_string_html .= ", ";
        $compare_string .= ", ";
    }
    $compare_string_html .= "<a href=\"".$site.$user_pages[$i]."\">".$user_name."</a>";
    $compare_string .= $user_name;
    push(@quero_ver_lists, \%quero_ver);

    $i++;
}

my %quero_ver_u1 = %{$quero_ver_lists[0]};

$i = 0;
my $result;

while ( (my $key, my $value) = each %quero_ver_u1 )
{
    my $exists = 1;
    for(my $j = 1; $j < scalar(@users); $j++)
    {
        if(!exists ${$quero_ver_lists[$j]}{$key})
        {
            $exists = 0;
            last;
        }

    }

    if($exists)
    {
        $result .= "<li class=\"span2 movie_list_item";
        if(($i+1) % 6 == 0)
        {
            $result .= " loopbreaker_item";
        }
        $result .= "\" id=\"movie-id\">".$value->mv_html."</li>";
        
        $i++;
        if($i % 6 == 0)
        {
            $result .= "<li class=\"loopbreaker\"></li>";
        }
    }
}
if($i % 6 != 0)
{
    $result .= "<li class=\"loopbreaker\"></li>";
}
print STDERR $i," em comum\n";

open (FHeader, "<./header.inc");
my @header = <FHeader>;
foreach (@header)
{
    $_ =~ s/TRALHA/$compare_string/;
    print $_;
}

print "				<h1 class=\"page_title\">$compare_string_html</h1>\n";

open (FTabs, "<./tabs.inc");
my @tabs = <FTabs>;
foreach (@tabs)
{
    $_ =~ s/TRALHA1/Querem ver/;
    $_ =~ s/TRALHA2/$result/;
    print $_;
}

open (FFooter, "<./footer.inc");
my @footer = <FFooter>;
print @footer;

