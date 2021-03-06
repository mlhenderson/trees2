#!/usr/bin/perl
# This script tests the Tree scripts by calling each one
#
#  author:  msneddon
#  created: jan 2013
use strict;
use warnings;

use Test::More;
use Data::Dumper;

use lib "test/perl-tests";
use TreeTestConfig qw(getURL);

# DETERMINE THE URL TO USE BASED ON THE CONFIG MODULE
my $url = getURL();
print "-> attempting to use :'".$url."'\n";

# declare some variables we use over and over 
my ($out,$exit_code);


#######################################################
# [tree-get-tree] script tests
$out = `tree-get-tree -h --url $url`;
$exit_code = ($? >> 8);
ok($exit_code==0,'tree-get-tree with help returns error exit code 0');
ok($out,'tree-get-tree with help returns a message');

$out = `tree-get-tree madeUpID --url $url`;
$exit_code = ($? >> 8);
ok($exit_code==0,'tree-get-tree with bogus treeId still exits with error code 0');
ok($out eq '','tree-get-tree with bogus treeId returns nothing');

$out = `tree-get-tree 'kb|tree.0' --url $url`;
$exit_code = ($? >> 8);
ok($exit_code==0,'tree-get-tree with real treeId  exits with error code 0');
ok($out,'tree-get-tree with real treeId returns something');

$out = `tree-get-tree -m 'kb|tree.0' --url $url`;
$exit_code = ($? >> 8);
ok($exit_code==0,'tree-get-tree with real treeId and -m flag exits with error code 0');
ok($out=~m/\[leaf_count\]/g,'tree-get-tree with real treeId and -m flag returns with string indicating meta data was returned');


#######################################################
# [tree-get-leaf-nodes] script tests
$out = `echo '' | tree-get-leaf-nodes --url $url`;
$exit_code = ($? >> 8);
ok($exit_code!=0,'tree-get-leaf-nodes with no parameters returns error exit code that is not 0');
ok($out,'tree-get-tree with no parameters returns a message');

$out = `tree-get-leaf-nodes "(a,b,c,d,e,f,g)root;" --url $url`;
$exit_code = ($? >> 8);
ok($exit_code==0,'tree-get-leaf-nodes with a tree returned with error code 0');
ok($out eq "a\nb\nc\nd\ne\nf\ng\n",'tree-get-leaf-nodes with a tree returns proper output');

#######################################################
# [tree-find-tree-ids] script tests
$out = `tree-find-tree-ids --help --url $url`;
$exit_code = ($? >> 8);
ok($exit_code==0,'tree-find-tree-ids with long help flag returns exit code 0');
ok($out,'tree-find-tree-ids with long help flag returns some text');


#######################################################
# [tree-find-alignment-ids] script tests
$out = `tree-find-alignment-ids --help --url $url`;
$exit_code = ($? >> 8);
ok($exit_code==0,'tree-find-alignment-ids with long help flag returns exit code 0');
ok($out,'tree-find-alignment-ids with long help flag returns some text');


#######################################################
# [tree-relabel-node-names] script tests
$out = `tree-relabel-node-names --help --url $url`;
$exit_code = ($? >> 8);
ok($exit_code==0,'tree-relabel-node-names with long help flag returns exit code 0');
ok($out,'tree-relabel-node-names with long help flag returns some text');


#######################################################
# [tree-compute-abundance-profile] script tests
$out = `tree-compute-abundance-profile --help --url $url`;
$exit_code = ($? >> 8);
ok($exit_code==0,'tree-compute-abundance-profile with long help flag returns exit code 0');
ok($out,'tree-compute-abundance-profile with long help flag returns some text');


#######################################################
# [tree-filter-abundance-profile] script tests
$out = `tree-filter-abundance-profile-column --help`;
$exit_code = ($? >> 8);
ok($exit_code==0,'tree-filter-abundance-profile-column with long help flag returns exit code 0');
ok($out,'tree-filter-abundance-profile with long help flag returns some text');


#######################################################
# [tree-normalize-abundance-profile] script tests
$out = `tree-normalize-abundance-profile --help --url $url`;
$exit_code = ($? >> 8);
ok($exit_code==0,'tree-normalize-abundance-profile with long help flag returns exit code 0');
ok($out,'tree-normalize-abundance-profile with long help flag returns some text');



#######################################################
# [tree-remove-nodes] script tests
$out = `tree-remove-nodes --help --url $url`;
$exit_code = ($? >> 8);
ok($exit_code==0,'tree-remove-nodes with long help flag returns exit code 0');
ok($out,'tree-remove-nodes with long help flag returns some text');


#######################################################
# [tree-html-add-boxes] script tests
$out = `tree-html-add-boxes --help`;
$exit_code = ($? >> 8);
ok($exit_code==0,'tree-html-add-boxes with long help flag returns exit code 0');
ok($out,'tree-html-add-boxes with long help flag returns some text');


#######################################################
# [tree-html-relabel-leaves] script tests
$out = `tree-html-relabel-leaves --help --url $url`;
$exit_code = ($? >> 8);
ok($exit_code==0,'tree-html-relabel-leaves with long help flag returns exit code 0');
ok($out,'tree-html-relabel-leaves with long help flag returns some text');

done_testing();
