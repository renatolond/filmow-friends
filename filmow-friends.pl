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

struct( Movie => {
        mv_title => '$',
        mv_img => '$',
        mv_link => '$',
        mv_html => '$'
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

sub get_name
{
    my $site = shift;
    my $profile = shift;
    my $url = $site.$profile;
    my $content = $ua->get($url);
    die "Couldn't get $url. $!" unless defined $content;
    my $dom_tree = new HTML::DOM;
    $dom_tree->write($content->decoded_content);
    $dom_tree->close();

    my $name = $dom_tree->getElementsByClassName("name")->[0]->innerHTML;

    return $name;
}

sub get_movies
{
    my $site = shift;
    my $next_page = shift;
    my %hash = ();
    print keys %hash;
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

        $next_page = $dom_tree->getElementsByClassName("next_page")->[0]->attributes->getNamedItem("href");


        foreach (@my_movies)
        {
            my $m = new Movie;
            my $img = $_->getElementsByClassName("wrapper")->[0]->getElementsByTagName("img")->[0];
            $m->mv_img($img->attributes->getNamedItem("src"));
            $m->mv_title($img->attributes->getNamedItem("alt"));
            my $href = $_->getElementsByClassName("wrapper")->[0]->getElementsByTagName("A")->[0]; 
            $m->mv_link($href->attributes->getNamedItem("href"));

            my $poster = $_->getElementsByClassName("poster")->[0];
            my $title = $_->getElementsByClassName("title")->[0];
            my $html = "<span class=\"wrapper\">".$poster->as_HTML."</span>\n".$title->as_HTML;

            my $new_string = $site.$m->mv_link;
            my $test = quotemeta($m->mv_link);
            $html =~ s!$test!$new_string!g;
            $m->mv_html($html);

            $hash{$m->mv_link} = $m;
        }
        $next_page = $dom_tree->getElementsByClassName("next_page")->[0]->attributes->getNamedItem("href");
        print STDERR scalar(keys %hash)," filmes\n";
    } while($next_page ne "");

    return %hash;
}

my $i = 0;

my $compare_string_html;
my $compare_string;

foreach my $user (@users)
{
    push(@user_pages, "/usuario/$user/");
    my $user_name = get_name($site, $user_pages[$i]);
    push(@user_names, $user_name);
    my $next_page = $user_pages[$i]."filmes/quero-ver";
    my %quero_ver = get_movies($site, $next_page);

    if($i == scalar(@users) - 1)
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
        $result .= "<li class=\"movie_list_item";
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

