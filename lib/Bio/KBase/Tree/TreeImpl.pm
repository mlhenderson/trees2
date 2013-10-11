package Bio::KBase::Tree::TreeImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

Tree

=head1 DESCRIPTION

Phylogenetic Tree and Multiple Sequence Alignment Services

This service provides a set of methods for querying, manipulating, and analyzing multiple
sequence alignments and phylogenetic trees.

Authors
---------
Michael Sneddon, LBL (mwsneddon@lbl.gov)
Fangfang Xia, ANL (fangfang.xia@gmail.com)
Keith Keller, LBL (kkeller@lbl.gov)
Matt Henderson, LBL (mhenderson@lbl.gov)
Dylan Chivian, LBL (dcchivian@lbl.gov)

=cut

#BEGIN_HEADER
use Data::Dumper;
use Config::Simple;
use List::MoreUtils qw(uniq);
use Bio::KBase::ERDB_Service::Client;
use Bio::KBase::Tree::TreeCppUtil;
use Bio::KBase::Tree::Community;
use ffxtree;
#use Bio::KBase::Tree::ForesterParserWrapper;
#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR
    
    #load a configuration file to determine where all the services live
    my %params;
    #if ((my $e = $ENV{KB_DEPLOYMENT_CONFIG}) && -e $ENV{KB_DEPLOYMENT_CONFIG})
    # I have to do this because the KBase deployment process is broken!!!
    if ((my $e = $ENV{TREE_DEPLOYMENT_CONFIG}) && -e $ENV{TREE_DEPLOYMENT_CONFIG}) {
	my $service = $ENV{TREE_DEPLOYMENT_SERVICE_NAME};
	my $c = Config::Simple->new();
	print "looking at config file: ".$e."\n";
	print "service name: ".$service."\n";
	$c->read($e);
	my @params = qw(erdb communities scratch);
	for my $p (@params) {
	    my $v = $c->param("$service.$p");
	    if ($v) { $params{$p} = $v; }
	}
    }

    # default URLs if none are found in the deploy.cfg file
    my $erdb_url = "https://kbase.us/services/erdb_service";
    my $mg_url = "http://api.metagenomics.anl.gov/sequences/";
    my $scratch = "/mnt/";
    if (defined $params{"erdb"}) {
	$erdb_url = $params{"erdb"};
	print STDERR "Connecting ERDB Service client to server: $erdb_url\n";
    }
    else {
	print STDERR "ERDB Service configuration not found, defaulting to: $erdb_url\n";
    }
    if (defined $params{"communities"}) {
	$mg_url = $params{"communities"};
	print STDERR "Connecting to communities server: $mg_url\n";
    }
    else {
	print STDERR "Communities server configuration not found, defaulting to: $mg_url\n";
    }	
    if (defined $params{"scratch"}) {
	$scratch = $params{"scratch"};
	print STDERR "Scratch space set to : $scratch\n";
    }
    else {
	print STDERR "Scratch space configuration not found, defaulting to: $scratch\n";
    }
    
    # create an ERDB client connection
    $self->{erdb} = Bio::KBase::ERDB_Service::Client->new($erdb_url);
    
    # create a new Community module which handles community based tree operations
    $self->{comm} = Bio::KBase::Tree::Community->new($erdb_url,$mg_url,$scratch);
    
    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 replace_node_names

  $return = $obj->replace_node_names($tree, $replacements)

=over 4

=item Parameter and return types

=begin html

<pre>
$tree is a Tree.newick_tree
$replacements is a reference to a hash where the key is a Tree.node_name and the value is a Tree.node_name
$return is a Tree.newick_tree
newick_tree is a Tree.tree
tree is a string
node_name is a string

</pre>

=end html

=begin text

$tree is a Tree.newick_tree
$replacements is a reference to a hash where the key is a Tree.node_name and the value is a Tree.node_name
$return is a Tree.newick_tree
newick_tree is a Tree.tree
tree is a string
node_name is a string


=end text



=item Description

Given a tree in newick format, replace the node names indicated as keys in the 'replacements' mapping
with new node names indicated as values in the 'replacements' mapping.  Matching is EXACT and will not handle
regular expression patterns.

=back

=cut

sub replace_node_names
{
    my $self = shift;
    my($tree, $replacements) = @_;

    my @_bad_arguments;
    (!ref($tree)) or push(@_bad_arguments, "Invalid type for argument \"tree\" (value was \"$tree\")");
    (ref($replacements) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"replacements\" (value was \"$replacements\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to replace_node_names:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'replace_node_names');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN replace_node_names
    my $kb_tree;
    eval { $kb_tree = new Bio::KBase::Tree::TreeCppUtil::KBTree($tree,0,1); };
    if(!$kb_tree) { $kb_tree = new Bio::KBase::Tree::TreeCppUtil::KBTree($tree,0,0); };
    my $replacement_str="";
    foreach my $key ( keys %$replacements ) {
        $replacement_str = $replacement_str.$key.";".$$replacements{$key}.";";
    }
    $kb_tree->replaceNodeNames($replacement_str);
    $return = $kb_tree->toNewick(1); # 1 indicates the style to output, with 1=names and edges and comments (basically, output everything)
    #END replace_node_names
    my @_bad_returns;
    (!ref($return)) or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to replace_node_names:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'replace_node_names');
    }
    return($return);
}




=head2 remove_node_names_and_simplify

  $return = $obj->remove_node_names_and_simplify($tree, $removal_list)

=over 4

=item Parameter and return types

=begin html

<pre>
$tree is a Tree.newick_tree
$removal_list is a reference to a list where each element is a Tree.node_name
$return is a Tree.newick_tree
newick_tree is a Tree.tree
tree is a string
node_name is a string

</pre>

=end html

=begin text

$tree is a Tree.newick_tree
$removal_list is a reference to a list where each element is a Tree.node_name
$return is a Tree.newick_tree
newick_tree is a Tree.tree
tree is a string
node_name is a string


=end text



=item Description

Given a tree in newick format, remove the nodes with the given names indicated in the list, and
simplify the tree.  Simplifying a tree involves removing unnamed internal nodes that have only one
child, and removing unnamed leaf nodes.  During the removal process, edge lengths (if they exist) are
conserved so that the summed end to end distance between any two nodes left in the tree will remain the same.

=back

=cut

sub remove_node_names_and_simplify
{
    my $self = shift;
    my($tree, $removal_list) = @_;

    my @_bad_arguments;
    (!ref($tree)) or push(@_bad_arguments, "Invalid type for argument \"tree\" (value was \"$tree\")");
    (ref($removal_list) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"removal_list\" (value was \"$removal_list\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to remove_node_names_and_simplify:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'remove_node_names_and_simplify');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN remove_node_names_and_simplify
    my $kb_tree = new Bio::KBase::Tree::TreeCppUtil::KBTree($tree,0,1);
    my $nodes_to_remove="";
    foreach my $val (@$removal_list) {
        $nodes_to_remove=$nodes_to_remove.$val.";";
    }
    $kb_tree->removeNodesByNameAndSimplify($nodes_to_remove);
    $return = $kb_tree->toNewick(1); # 1 indicates the style to output, with 1=names and edges and comments (basically, output everything)
    #END remove_node_names_and_simplify
    my @_bad_returns;
    (!ref($return)) or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to remove_node_names_and_simplify:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'remove_node_names_and_simplify');
    }
    return($return);
}




=head2 merge_zero_distance_leaves

  $return = $obj->merge_zero_distance_leaves($tree)

=over 4

=item Parameter and return types

=begin html

<pre>
$tree is a Tree.newick_tree
$return is a Tree.newick_tree
newick_tree is a Tree.tree
tree is a string

</pre>

=end html

=begin text

$tree is a Tree.newick_tree
$return is a Tree.newick_tree
newick_tree is a Tree.tree
tree is a string


=end text



=item Description

Some KBase trees keep information on canonical feature ids, even if they have the same protien sequence
in an alignment.  In these cases, some leaves with identical sequences will have zero distance so that
information on canonical features is maintained.  Often this information is not useful, and a single
example feature or genome is sufficient.  This method will accept a tree in newick format (with distances)
and merge all leaves that have zero distance between them (due to identical sequences), and keep arbitrarily
only one of these leaves.

=back

=cut

sub merge_zero_distance_leaves
{
    my $self = shift;
    my($tree) = @_;

    my @_bad_arguments;
    (!ref($tree)) or push(@_bad_arguments, "Invalid type for argument \"tree\" (value was \"$tree\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to merge_zero_distance_leaves:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'merge_zero_distance_leaves');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN merge_zero_distance_leaves
    
    my $kb_tree = new Bio::KBase::Tree::TreeCppUtil::KBTree($tree,0,1);
    $kb_tree->mergeZeroDistLeaves();
    $return = $kb_tree->toNewick(1); # 1 indicates the style to out
    
    #END merge_zero_distance_leaves
    my @_bad_returns;
    (!ref($return)) or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to merge_zero_distance_leaves:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'merge_zero_distance_leaves');
    }
    return($return);
}




=head2 extract_leaf_node_names

  $return = $obj->extract_leaf_node_names($tree)

=over 4

=item Parameter and return types

=begin html

<pre>
$tree is a Tree.newick_tree
$return is a reference to a list where each element is a Tree.node_name
newick_tree is a Tree.tree
tree is a string
node_name is a string

</pre>

=end html

=begin text

$tree is a Tree.newick_tree
$return is a reference to a list where each element is a Tree.node_name
newick_tree is a Tree.tree
tree is a string
node_name is a string


=end text



=item Description

Given a tree in newick format, list the names of the leaf nodes.

=back

=cut

sub extract_leaf_node_names
{
    my $self = shift;
    my($tree) = @_;

    my @_bad_arguments;
    (!ref($tree)) or push(@_bad_arguments, "Invalid type for argument \"tree\" (value was \"$tree\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to extract_leaf_node_names:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'extract_leaf_node_names');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN extract_leaf_node_names
    my $kb_tree = new Bio::KBase::Tree::TreeCppUtil::KBTree($tree);
    my $leaf_names = $kb_tree->getAllLeafNames();
    my @leaf_name_list = split(';', $leaf_names);
    $return = \@leaf_name_list;
    #END extract_leaf_node_names
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to extract_leaf_node_names:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'extract_leaf_node_names');
    }
    return($return);
}




=head2 extract_node_names

  $return = $obj->extract_node_names($tree)

=over 4

=item Parameter and return types

=begin html

<pre>
$tree is a Tree.newick_tree
$return is a reference to a list where each element is a Tree.node_name
newick_tree is a Tree.tree
tree is a string
node_name is a string

</pre>

=end html

=begin text

$tree is a Tree.newick_tree
$return is a reference to a list where each element is a Tree.node_name
newick_tree is a Tree.tree
tree is a string
node_name is a string


=end text



=item Description

Given a tree in newick format, list the names of ALL the nodes.  Note that for some trees, such as
those originating from MicrobesOnline, the names of internal nodes may be bootstrap values, but will still
be returned by this function.

=back

=cut

sub extract_node_names
{
    my $self = shift;
    my($tree) = @_;

    my @_bad_arguments;
    (!ref($tree)) or push(@_bad_arguments, "Invalid type for argument \"tree\" (value was \"$tree\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to extract_node_names:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'extract_node_names');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN extract_node_names
    my $kb_tree = new Bio::KBase::Tree::TreeCppUtil::KBTree($tree);
    my $node_names = $kb_tree->getAllNodeNames();
    my @node_name_list = split(';', $node_names);
    $return = \@node_name_list;
    #END extract_node_names
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to extract_node_names:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'extract_node_names');
    }
    return($return);
}




=head2 get_node_count

  $return = $obj->get_node_count($tree)

=over 4

=item Parameter and return types

=begin html

<pre>
$tree is a Tree.newick_tree
$return is an int
newick_tree is a Tree.tree
tree is a string

</pre>

=end html

=begin text

$tree is a Tree.newick_tree
$return is an int
newick_tree is a Tree.tree
tree is a string


=end text



=item Description

Given a tree, return the total number of nodes, including internal nodes and the root node.

=back

=cut

sub get_node_count
{
    my $self = shift;
    my($tree) = @_;

    my @_bad_arguments;
    (!ref($tree)) or push(@_bad_arguments, "Invalid type for argument \"tree\" (value was \"$tree\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_node_count:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_node_count');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN get_node_count
    my $kb_tree = new Bio::KBase::Tree::TreeCppUtil::KBTree($tree);
    $return = $kb_tree->getNodeCount();
    #END get_node_count
    my @_bad_returns;
    (!ref($return)) or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_node_count:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_node_count');
    }
    return($return);
}




=head2 get_leaf_count

  $return = $obj->get_leaf_count($tree)

=over 4

=item Parameter and return types

=begin html

<pre>
$tree is a Tree.newick_tree
$return is an int
newick_tree is a Tree.tree
tree is a string

</pre>

=end html

=begin text

$tree is a Tree.newick_tree
$return is an int
newick_tree is a Tree.tree
tree is a string


=end text



=item Description

Given a tree, return the total number of leaf nodes, (internal and root nodes are ignored).  When the
tree was based on a multiple sequence alignment, the number of leaves will match the number of sequences
that were aligned.

=back

=cut

sub get_leaf_count
{
    my $self = shift;
    my($tree) = @_;

    my @_bad_arguments;
    (!ref($tree)) or push(@_bad_arguments, "Invalid type for argument \"tree\" (value was \"$tree\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_leaf_count:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_leaf_count');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN get_leaf_count
    my $kb_tree = new Bio::KBase::Tree::TreeCppUtil::KBTree($tree);
    $return = $kb_tree->getLeafCount();
    #END get_leaf_count
    my @_bad_returns;
    (!ref($return)) or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_leaf_count:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_leaf_count');
    }
    return($return);
}




=head2 get_tree

  $return = $obj->get_tree($tree_id, $options)

=over 4

=item Parameter and return types

=begin html

<pre>
$tree_id is a Tree.kbase_id
$options is a reference to a hash where the key is a string and the value is a string
$return is a Tree.tree
kbase_id is a string
tree is a string

</pre>

=end html

=begin text

$tree_id is a Tree.kbase_id
$options is a reference to a hash where the key is a string and the value is a string
$return is a Tree.tree
kbase_id is a string
tree is a string


=end text



=item Description

Returns the specified tree in the specified format, or an empty string if the tree does not exist.
The options hash provides a way to return the tree with different labels replaced or with different attached meta
information.  Currently, the available flags and understood options are listed below. 

    options = [
        format => 'newick',
        newick_label => 'none' || 'raw' || 'feature_id' || 'protein_sequence_id' ||
                        'contig_sequence_id' || 'best_feature_id' || 'best_genome_id',
        newick_bootstrap => 'none' || 'internal_node_labels'
        newick_distance => 'none' || 'raw'
    ];
 
The 'format' key indicates what string format the tree should be returned in.  Currently, there is only
support for 'newick'. The default value if not specified is 'newick'.

The 'newick_label' key only affects trees returned as newick format, and specifies what should be
placed in the label of each leaf.  'none' indicates that no label is added, so you get the structure
of the tree only.  'raw' indicates that the raw label mapping the leaf to an alignement row is used.
'feature_id' indicates that the label will have an examplar feature_id in each label (typically the
feature that was originally used to define the sequence). Note that exemplar feature_ids are not
defined for all trees, so this may result in an empty tree! 'protein_sequence_id' indicates that the
kbase id of the protein sequence used in the alignment is used.  'contig_sequence_id' indicates that
the contig sequence id is added.  Note that trees are typically built with protein sequences OR
contig sequences. If you select one type of sequence, but the tree was built with the other type, then
no labels will be added.  'best_feature_id' is used in the frequent case where a protein sequence has
been mapped to multiple feature ids, and an example feature_id is used.  Similarly, 'best_genome_id'
replaces the labels with the best example genome_id.  The default value if none is specified is 'raw'.

The 'newick_bootstrap' key allows control over whether bootstrap values are returned if they exist, and
how they are returned.  'none' indicates that no bootstrap values are returned. 'internal_node_labels'
indicates that bootstrap values are returned as internal node labels.  Default value is 'internal_node_labels';

The 'newick_distance' key allows control over whether distance labels are generated or not.  If set to
'none', no distances will be output. Default is 'raw', which outputs the distances exactly as they appeared
when loaded into KBase.

=back

=cut

sub get_tree
{
    my $self = shift;
    my($tree_id, $options) = @_;

    my @_bad_arguments;
    (!ref($tree_id)) or push(@_bad_arguments, "Invalid type for argument \"tree_id\" (value was \"$tree_id\")");
    (ref($options) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"options\" (value was \"$options\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_tree:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_tree');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN get_tree
    
    # first get the tree
    my $erdb = $self->{erdb};
    my $rows = $erdb->GetAll('Tree','Tree(id) = ?', [$tree_id],'Tree(newick)',0);
    
    # second parse the parameters and set the defaults
    if (!exists $options->{format})           { $options->{format}="newick"; }
    if (!exists $options->{newick_label})     { $options->{newick_label}="raw"; }
    if (!exists $options->{newick_bootstrap}) { $options->{newick_bootstrap}="internal_node_labels"; }
    if (!exists $options->{newick_distance}) { $options->{newick_distance}="raw"; }
    
    #check if query found something
    if(@{$rows}) {
	my @return_rows=();
	foreach(@{$rows}) {
	    #process the tree according the command-line options
	    my $raw_newick = $_; my $output_newick="";
	    my $kb_tree = new Bio::KBase::Tree::TreeCppUtil::KBTree(${$raw_newick}[0],0,1);
	    
	    if($options->{format} eq "newick") {
	    
		#figure out how to label the nodes
		if($options->{newick_label} eq "none") {
		    $kb_tree->setOutputFlagLabel(0);
		} elsif ($options->{newick_label} eq "raw") {
		    $kb_tree->setOutputFlagLabel(1);
		} elsif ($options->{newick_label} eq "feature_id") {
		    # use the exemplar feature stored directly in the tree
		    $kb_tree->setOutputFlagLabel(1);
		    # replace names with feature ids
		    my $feature_ids_raw = $erdb->GetAll('IsBuiltFromAlignment Alignment IsAlignmentRowIn AlignmentRow ContainsAlignedProtein',
			    'IsBuiltFromAlignment(from_link) = ?', [$tree_id],
			    'AlignmentRow(row-id) ContainsAlignedProtein(kb-feature-id)',0);
		    my @feature_ids = @{$feature_ids};
		    my $replacement_str="";
		    foreach (@feature_ids) { #might be a better way to concatenate this list...
		    	$replacement_str = $replacement_str.${$_}[0].";".${$_}[1].";";
		    }
		    #print $replacement_str."\n\n";
		    $kb_tree->replaceNodeNamesOrMakeBlank($replacement_str);
		} elsif ($options->{newick_label} eq "protein_sequence_id") {
		    $kb_tree->setOutputFlagLabel(1);
		    my $prot_seq_ids_raw = $erdb->GetAll('IsBuiltFromAlignment Alignment IsAlignmentRowIn AlignmentRow ContainsAlignedProtein',
			    'IsBuiltFromAlignment(from_link) = ? ORDER BY AlignmentRow(row-id),ContainsAlignedProtein(to-link)', [$tree_id],
			    'AlignmentRow(row-id) ContainsAlignedProtein(to-link)',0);
		    my $prot_seq_ids = @{$prot_seq_ids_raw};
		    my $replacement_str="";
		    # could be more than one sequence per row, so we have to check for this and only add the first one
		    for my $i (0 .. $#prot_seq_ids) {
			if ($i>=1) {
			    $replacement_str = $replacement_str.${$prot_seq_ids[$i]}[0].";".${$prot_seq_ids[$i]}[1].";"
			    unless ( ${$prot_seq_ids[$i]}[0] eq ${$prot_seq_ids[$i-1]}[0]);
			} else {
			    $replacement_str = ${$prot_seq_ids[$i]}[0].";".${$prot_seq_ids[$i]}[1].";";
			}
		    }
		    $kb_tree->replaceNodeNamesOrMakeBlank($replacement_str);
		} elsif ($options->{newick_label} eq "contig_sequence_id") {
		    $kb_tree->setOutputFlagLabel(1);
		    # todo: replace names with contig sequence ids
		    my $contig_seq_ids_raw = $erdb->GetAll('IsBuiltFromAlignment Alignment IsAlignmentRowIn AlignmentRow ContainsAlignedDNA',
			    'IsBuiltFromAlignment(from_link) = ? ORDER BY AlignmentRow(row-id),ContainsAlignedDNA(to-link)', [$tree_id],
			    'AlignmentRow(row-id) ContainsAlignedDNA(to-link)',0);
		    my @contig_seq_ids = @{$contig_seq_ids_raw};
		    my $replacement_str="";
		    foreach (@contig_seq_ids) { #might be a better way to concatenate this list...
			$replacement_str = $replacement_str.${$_}[0].";".${$_}[1].";";
		    }
		    $kb_tree->replaceNodeNamesOrMakeBlank($replacement_str);
		} elsif ($options->{newick_label} eq "best_feature_id") {
		
		    # lookup the list of features
		    $kb_tree->setOutputFlagLabel(1);
		    my $row2featureId = $erdb->GetAll('IsBuiltFromAlignment Alignment IsAlignmentRowIn AlignmentRow ContainsAlignedProtein ProteinSequence IsProteinFor',
			    'IsBuiltFromAlignment(from_link) = ? ORDER BY IsProteinFor(to_link)', [$tree_id],
			    'AlignmentRow(row-id) IsProteinFor(to_link)',0);
		    my $replacement_str="";
		    
		    my $row2featureListMap = {};
		    foreach my $pair (@row2featureId) {
			# best = lowest ID number
			if(exists $row2featureListMap->{$pair->[0]}) {
			    my @new_match = split /\./, $pair->[1];
			    my @old_match = split /\./, $row2featureListMap->{$pair->[0]};
			    if($new_match[1] < $old_match[1]) { # first compare on genome numbers
				$row2featureListMap->{$pair->[0]} = $pair->[1];
			    } elsif($new_match[1] == $old_match[1]) { # next compare on FID numbers if genome ids are identical
				if($new_match[3] == $old_match[3]) {
				    $row2featureListMap->{$pair->[0]} = $pair->[1];
				}
			    }
			} else {
			    $row2featureListMap->{$pair->[0]} = $pair->[1];
			}
		    }
		    my $replacement_str="";
		    while( my ($rowId, $fid) = each %$row2featureListMap ) {
			$replacement_str = $replacement_str.$rowId.";".$fid.";";
		    }
		    $kb_tree->replaceNodeNamesOrMakeBlank($replacement_str);
		    
		} elsif($options->{newick_label} eq "best_genome_id") {
		
		    # lookup the list of features
		    $kb_tree->setOutputFlagLabel(1);
		    my $row2featureId_raw = $erdb->GetAll('IsBuiltFromAlignment Alignment IsAlignmentRowIn AlignmentRow ContainsAlignedProtein ProteinSequence IsProteinFor',
			    'IsBuiltFromAlignment(from_link) = ? ORDER BY IsProteinFor(to_link)', [$tree_id],
			    'AlignmentRow(row-id) IsProteinFor(to_link)',0);
		    my $replacement_str="";
		    my $row2featureId = @{$row2featureId_raw};
		    my $row2featureListMap = {};
		    foreach my $pair (@row2featureId) {
		        my @tokens = split /\./, $pair->[1];
			$pair->[1] = 'kb|g.'.@tokens[1];
			# best = lowest ID number
			if(exists $row2featureListMap->{$pair->[0]}) {
			    my @new_match = split /\./, $pair->[1];
			    my @old_match = split /\./, $row2featureListMap->{$pair->[0]};
			    if($new_match[1] < $old_match[1]) { # first compare on genome numbers
				$row2featureListMap->{$pair->[0]} = $pair->[1];
			    }
			} else {
			    $row2featureListMap->{$pair->[0]} = $pair->[1];
			}
		    }
		    my $replacement_str="";
		    while( my ($rowId, $fid) = each %$row2featureListMap ) {
			$replacement_str = $replacement_str.$rowId.";".$fid.";";
		    }
		    $kb_tree->replaceNodeNamesOrMakeBlank($replacement_str);
		
		
		
		} elsif ($options->{newick_label} eq "scientific_name") {
		    #$kb_tree->setOutputFlagLabel(1);
		    # first get feature ids
		    #my @feature_ids = $kb->GetAll('IsBuiltFromAlignment Alignment IsAlignmentRowIn AlignmentRow ContainsAlignedProtein',
			#    'IsBuiltFromAlignment(from_link) = ?', $tree_id,
			#    [qw(AlignmentRow(row-id) ContainsAlignedProtein(kb-feature-id))]);
		    # query one more time to get scientific names
		    #my $n = @feature_ids;
		    #my $targets = "(" . ('?,' x $n); chop $targets; $targets .= ')';
		    #my $constraint = "IsOwnedBy(from_link) IN $targets ORDER BY IsOwnedBy(from_link)";
		    #my @names = $kb->GetAll('IsOwnedBy Genome',
			#$constraint, \@feature_ids,
			#[qw(IsOwnedBy(from_link) Genome(scientific_name))]);
		    
		    #return Dumper(@feature_ids);
		    
		    #my $replacement_str="";
		    #for my $i (0 .. $#names) {
			#$replacement_str = $replacement_str.$feature_ids[$i](0).";".$names[$i][1].";";
		    #}
		    #$kb_tree->replaceNodeNamesOrMakeBlank($replacement_str);
		    
		    
		} else {
		    my $msg = "Invalid option passed to get_tree. Unrecognized value for option key: 'newick_label'\n";
		    $msg = $msg."You set 'newick_label' to be: '".$options->{newick_label}."'";
		    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg, method_name => 'get_tree');
		}
		
		# figure out the bootstrap output option
		if ($options->{newick_bootstrap} eq "none") {
		    $kb_tree->setOutputFlagBootstrapValuesAsLabels(0);   
		} elsif ($options->{newick_bootstrap} eq "internal_node_labels") {
		    $kb_tree->setOutputFlagBootstrapValuesAsLabels(1);      
		} else {
		    my $msg = "Invalid option passed to get_tree. Unrecognized value for option key: 'newick_bootstrap'\n";
		    $msg = $msg."You set 'newick_bootstrap' to be: '".$options->{newick_bootstrap}."'";
		    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg, method_name => 'get_tree');
		}
		
		# figure out the distance output option
		if ($options->{newick_distance} eq "none") {
		    $kb_tree->setOutputFlagDistances(0);   
		} elsif ($options->{newick_distance} eq "raw") {
		    $kb_tree->setOutputFlagDistances(1);   
		} else {
		    my $msg = "Invalid option passed to get_tree. Unrecognized value for option key: 'newick_distance'\n";
		    $msg = $msg."You set 'newick_distance' to be: '".$options->{newick_distance}."'";
		    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg, method_name => 'get_tree');
		}
	    
		# push back the tree in the desired format
		push(@return_rows, $kb_tree->toNewick());
		
	    } else {
		my $msg = "Invalid option passed to get_tree. Only 'format=>newick' is currently supported.\n";
		$msg = $msg."You specified the output format to be: '".$options->{format}."'";
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg, method_name => 'get_tree');
	    }
	    
	   
	}
    
	#should only ever be one return, so get the first element, and then the first and only newick
	$return = @return_rows[0];
    } else {
	$return = "";
    }
    #END get_tree
    my @_bad_returns;
    (!ref($return)) or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_tree:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_tree');
    }
    return($return);
}




=head2 get_alignment

  $return = $obj->get_alignment($alignment_id, $options)

=over 4

=item Parameter and return types

=begin html

<pre>
$alignment_id is a Tree.kbase_id
$options is a reference to a hash where the key is a string and the value is a string
$return is a Tree.alignment
kbase_id is a string
alignment is a string

</pre>

=end html

=begin text

$alignment_id is a Tree.kbase_id
$options is a reference to a hash where the key is a string and the value is a string
$return is a Tree.alignment
kbase_id is a string
alignment is a string


=end text



=item Description

Returns the specified alignment in the specified format, or an empty string if the alignment does not exist.
The options hash provides a way to return the alignment with different labels replaced or with different attached meta
information.  Currently, the available flags and understood options are listed below. 

    options = [
        format => 'fasta',
        sequence_label => 'none' || 'raw' || 'feature_id' || 'protein_sequence_id' || 'contig_sequence_id',
    ];
 
The 'format' key indicates what string format the alignment should be returned in.  Currently, there is only
support for 'fasta'. The default value if not specified is 'fasta'.

The 'sequence_label' specifies what should be placed in the label of each sequence.  'none' indicates that
no label is added, so you get the sequence only.  'raw' indicates that the raw label of the alignement row
is used. 'feature_id' indicates that the label will have an examplar feature_id in each label (typically the
feature that was originally used to define the sequence). Note that exemplar feature_ids are not
defined for all alignments, so this may result in an unlabeled alignment.  'protein_sequence_id' indicates
that the kbase id of the protein sequence used in the alignment is used.  'contig_sequence_id' indicates that
the contig sequence id is used.  Note that trees are typically built with protein sequences OR
contig sequences. If you select one type of sequence, but the alignment was built with the other type, then
no labels will be added.  The default value if none is specified is 'raw'.

=back

=cut

sub get_alignment
{
    my $self = shift;
    my($alignment_id, $options) = @_;

    my @_bad_arguments;
    (!ref($alignment_id)) or push(@_bad_arguments, "Invalid type for argument \"alignment_id\" (value was \"$alignment_id\")");
    (ref($options) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"options\" (value was \"$options\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_alignment:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_alignment');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN get_alignment
    
    my $fasta = "";
    
    # first get the alignment sequences and row IDs
    # second parse the parameters and set the defaults
    if (!exists $options->{format})           { $options->{format}="fasta"; }
    if (!exists $options->{sequence_label})     { $options->{sequence_label}="raw"; }
    
    if($options->{format} eq "fasta") {
	my $erdb = $self->{erdb};
	#figure out how to label the seqeunces
	if($options->{sequence_label} eq "none") {
	    my $rows = $erdb->GetAll('AlignmentRow IsAlignmentRowIn','IsAlignmentRowIn(to-link) = ?', [$alignment_id],'AlignmentRow(sequence)',0);
	    foreach my $row (@{$rows}) {
		$fasta .= ">\n";
		$fasta .= $row->[0]."\n";
	    }
	} else {
	    my $rows;
	    if ($options->{sequence_label} eq "raw") {
		$rows = $erdb->GetAll('AlignmentRow IsAlignmentRowIn','IsAlignmentRowIn(to-link) = ? ORDER BY AlignmentRow(row-id)', [$alignment_id],'AlignmentRow(row-id) AlignmentRow(sequence)',0);
	    } elsif ($options->{sequence_label} eq "feature_id") {
		$rows = $erdb->GetAll('IncludesAlignmentRow AlignmentRow ContainsAlignedProtein','IncludesAlignmentRow(from-link) = ? ORDER BY AlignmentRow(row-id)', [$alignment_id],'ContainsAlignedProtein(kb-feature-id) AlignmentRow(sequence)',0);
	    } elsif ($options->{sequence_label} eq "protein_sequence_id") {
		$rows = $erdb->GetAll('IncludesAlignmentRow AlignmentRow ContainsAlignedProtein','IncludesAlignmentRow(from-link) = ? ORDER BY AlignmentRow(row-id)', [$alignment_id],'ContainsAlignedProtein(to-link) AlignmentRow(sequence)',0);
	    } elsif ($options->{sequence_label} eq "contig_sequence_id") {
		$rows = $erdb->GetAll('IncludesAlignmentRow AlignmentRow ContainsAlignedDNA','IncludesAlignmentRow(from-link) = ? ORDER BY AlignmentRow(row-id)', [$alignment_id],'ContainsAlignedDNA(to-link) AlignmentRow(sequence)',0);
	    } else {
		my $msg = "Invalid option passed to get_alignment. Unrecognized value for option key: 'sequence_label'\n";
		$msg = $msg."You set 'sequence_label' to be: '".$options->{sequence_label}."'";
		Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg, method_name => 'get_alignment');
	    }
	    foreach my $row (@{$rows}) {
		$fasta .= ">$row->[0]\n";
		$fasta .= $row->[1]."\n";
	    }
	} 
    
    } else {
	my $msg = "Invalid option passed to get_alignment. Only 'format=>fasta' is currently supported.\n";
	$msg = $msg."You specified the output format to be: '".$options->{format}."'";
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg, method_name => 'get_alignment');
    }
    $return = $fasta;
    
    #END get_alignment
    my @_bad_returns;
    (!ref($return)) or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_alignment:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_alignment');
    }
    return($return);
}




=head2 get_tree_data

  $return = $obj->get_tree_data($tree_ids)

=over 4

=item Parameter and return types

=begin html

<pre>
$tree_ids is a reference to a list where each element is a Tree.kbase_id
$return is a reference to a hash where the key is a Tree.kbase_id and the value is a Tree.TreeMetaData
kbase_id is a string
TreeMetaData is a reference to a hash where the following keys are defined:
	alignment_id has a value which is a Tree.kbase_id
	type has a value which is a string
	status has a value which is a string
	date_created has a value which is a Tree.timestamp
	tree_contruction_method has a value which is a string
	tree_construction_parameters has a value which is a string
	tree_protocol has a value which is a string
	node_count has a value which is an int
	leaf_count has a value which is an int
	source_db has a value which is a string
	source_id has a value which is a string
timestamp is a string

</pre>

=end html

=begin text

$tree_ids is a reference to a list where each element is a Tree.kbase_id
$return is a reference to a hash where the key is a Tree.kbase_id and the value is a Tree.TreeMetaData
kbase_id is a string
TreeMetaData is a reference to a hash where the following keys are defined:
	alignment_id has a value which is a Tree.kbase_id
	type has a value which is a string
	status has a value which is a string
	date_created has a value which is a Tree.timestamp
	tree_contruction_method has a value which is a string
	tree_construction_parameters has a value which is a string
	tree_protocol has a value which is a string
	node_count has a value which is an int
	leaf_count has a value which is an int
	source_db has a value which is a string
	source_id has a value which is a string
timestamp is a string


=end text



=item Description

Get meta data associated with each of the trees indicated in the list by tree id.  Note that some meta
data may not be available for trees which are not built from alignments.  Also note that this method
computes the number of nodes and leaves for each tree, so may be slow for very large trees or very long
lists.  If you do not need this full meta information structure, it may be faster to directly query the
CDS for just the field you need using the CDMI.

=back

=cut

sub get_tree_data
{
    my $self = shift;
    my($tree_ids) = @_;

    my @_bad_arguments;
    (ref($tree_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"tree_ids\" (value was \"$tree_ids\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_tree_data:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_tree_data');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN get_tree_data
    $return = {};
    if (@{$tree_ids}) {
	#First get just the tree specific data
	my $erdb = $self->{erdb};
	my $n = @$tree_ids;
	my $targets = "(" . ('?,' x $n); chop $targets; $targets .= ')';
	my $constraint = "Tree(id) IN $targets";
	my $rows = $erdb->GetAll('Treed Tree',
		$constraint, $tree_ids,
		'Tree(id) Tree(status) Tree(data-type) Tree(timestamp) Tree(method) Tree(parameters) Tree(protocol) Treed(from_link) Tree(source-id) Tree(newick)',0);
	#2) put the tree ids in a single straight-up list
	foreach (@{$rows}) {
	    my $val = $_;
	    my $res = {};
	    $res->{alignment_id} = "";
	    $res->{status} = ${$val}[1];
	    $res->{type} = ${$val}[2];
	    $res->{date_created} = ${$val}[3];
	    $res->{tree_contruction_method} = ${$val}[4];
	    $res->{tree_construction_parameters} = ${$val}[5];
	    $res->{tree_protocol} = ${$val}[6];
	    $res->{source_db} = ${$val}[7];
	    $res->{source_id} = ${$val}[8];
	    my $kb_tree = new Bio::KBase::Tree::TreeCppUtil::KBTree(${$val}[9],0,1);
	    $res->{node_count} = $kb_tree->getNodeCount();
	    $res->{leaf_count} = $kb_tree->getLeafCount();
	    $return->{${$val}[0]} = $res;
	}
	
	#now get information from alignments if we can (this will only work for trees built from alignments)
	my $targets = "(" . ('?,' x $n); chop $targets; $targets .= ')';
	my $constraint = "IsBuiltFromAlignment(from_link) IN $targets";
	my $rows = $erdb->GetAll('IsBuiltFromAlignment',
		$constraint, $tree_ids,
		'IsBuiltFromAlignment(from_link) IsBuiltFromAlignment(to_link)',0);
	foreach (@{$rows}) {
	    my $val = $_;
	    $return->{${$val}[0]}->{alignment_id} = ${$val}[1];
	}
    }
    
    #END get_tree_data
    my @_bad_returns;
    (ref($return) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_tree_data:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_tree_data');
    }
    return($return);
}




=head2 get_alignment_data

  $return = $obj->get_alignment_data($alignment_ids)

=over 4

=item Parameter and return types

=begin html

<pre>
$alignment_ids is a reference to a list where each element is a Tree.kbase_id
$return is a reference to a hash where the key is a Tree.kbase_id and the value is a Tree.AlignmentMetaData
kbase_id is a string
AlignmentMetaData is a reference to a hash where the following keys are defined:
	tree_ids has a value which is a reference to a list where each element is a Tree.kbase_id
	status has a value which is a string
	sequence_type has a value which is a string
	is_concatenation has a value which is a string
	date_created has a value which is a Tree.timestamp
	n_rows has a value which is an int
	n_cols has a value which is an int
	alignment_construction_method has a value which is a string
	alignment_construction_parameters has a value which is a string
	alignment_protocol has a value which is a string
	source_db has a value which is a string
	source_id has a value which is a string
timestamp is a string

</pre>

=end html

=begin text

$alignment_ids is a reference to a list where each element is a Tree.kbase_id
$return is a reference to a hash where the key is a Tree.kbase_id and the value is a Tree.AlignmentMetaData
kbase_id is a string
AlignmentMetaData is a reference to a hash where the following keys are defined:
	tree_ids has a value which is a reference to a list where each element is a Tree.kbase_id
	status has a value which is a string
	sequence_type has a value which is a string
	is_concatenation has a value which is a string
	date_created has a value which is a Tree.timestamp
	n_rows has a value which is an int
	n_cols has a value which is an int
	alignment_construction_method has a value which is a string
	alignment_construction_parameters has a value which is a string
	alignment_protocol has a value which is a string
	source_db has a value which is a string
	source_id has a value which is a string
timestamp is a string


=end text



=item Description

Get meta data associated with each of the trees indicated in the list by tree id.  Note that some meta
data may not be available for trees which are not built from alignments.  Also note that this method
computes the number of nodes and leaves for each tree, so may be slow for very large trees or very long
lists.  If you do not need this full meta information structure, it may be faster to directly query the
CDS for just the field you need using the CDMI.

=back

=cut

sub get_alignment_data
{
    my $self = shift;
    my($alignment_ids) = @_;

    my @_bad_arguments;
    (ref($alignment_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"alignment_ids\" (value was \"$alignment_ids\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_alignment_data:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_alignment_data');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN get_alignment_data
    
    #get just the alignment specific data
    my $erdb = $self->{erdb};
    my $n = @$alignment_ids;
    my $targets = "(" . ('?,' x $n); chop $targets; $targets .= ')';
    my $constraint = "Alignment(id) IN $targets";
    my $rows = $erdb->GetAll('Alignment WasAlignedBy',
	    $constraint, $alignment_ids,
	    'Alignment(id) Alignment(status) Alignment(sequence_type) Alignment(is_concatenation) Alignment(timestamp)
	     Alignment(n_rows) Alignment(n_cols) Alignment(method) Alignment(parameters) Alignment(protocol) WasAlignedBy(to_link) Alignment(source-id)',0);
    # put the data into a proper hash
    $return = {};
    foreach (@{$rows}) {
	my $val = $_;
	my $res = {};
	$res->{tree_ids} = [ ];
	$res->{status} = ${$val}[1];
	$res->{sequence_type} = ${$val}[2];
	$res->{is_concatenation} = ${$val}[3];
	$res->{date_created} = ${$val}[4];
	$res->{n_rows} = ${$val}[5];
	$res->{n_cols} = ${$val}[6];
	$res->{alignment_construction_method} = ${$val}[7];
	$res->{alignment_construction_parameters} = ${$val}[8];
	$res->{alignment_protocol} = ${$val}[9];
	$res->{source_db} = ${$val}[10];
	$res->{source_id} = ${$val}[11];
	$return->{${$val}[0]} = $res;
    }
    
    #now get information from alignments if we can
    my $targets = "(" . ('?,' x $n); chop $targets; $targets .= ')';
    my $constraint = "IsBuiltFromAlignment(to_link) IN $targets";
    my $rows = $erdb->GetAll('IsBuiltFromAlignment',
	    $constraint, $alignment_ids,
	    'IsBuiltFromAlignment(to_link) IsBuiltFromAlignment(from_link)',0);
    foreach (@{$rows}) {
	my $val = $_;
	push $return->{${$val}[0]}->{tree_ids}, ${$val}[1];
    }
    
    #END get_alignment_data
    my @_bad_returns;
    (ref($return) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_alignment_data:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_alignment_data');
    }
    return($return);
}




=head2 get_tree_ids_by_feature

  $return = $obj->get_tree_ids_by_feature($feature_ids)

=over 4

=item Parameter and return types

=begin html

<pre>
$feature_ids is a reference to a list where each element is a Tree.kbase_id
$return is a reference to a list where each element is a Tree.kbase_id
kbase_id is a string

</pre>

=end html

=begin text

$feature_ids is a reference to a list where each element is a Tree.kbase_id
$return is a reference to a list where each element is a Tree.kbase_id
kbase_id is a string


=end text



=item Description

Given a list of feature ids in kbase, the protein sequence of each feature (if the sequence exists)
is identified and used to retrieve all trees by ID that were built using the given protein sequence.

=back

=cut

sub get_tree_ids_by_feature
{
    my $self = shift;
    my($feature_ids) = @_;

    my @_bad_arguments;
    (ref($feature_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"feature_ids\" (value was \"$feature_ids\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_tree_ids_by_feature:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_tree_ids_by_feature');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN get_tree_ids_by_feature
    # 1) construct and execute the query
    my $erdb = $self->{erdb};    
    my $n = @$feature_ids;
    my $targets = "(" . ('?,' x $n); chop $targets; $targets .= ')';
    my $constraint = "IsProteinFor(to_link) IN $targets ORDER BY IsBuiltFromAlignment(from_link)";
    my $rows = $erdb->GetAll('IsBuiltFromAlignment Alignment IsAlignmentRowIn AlignmentRow ContainsAlignedProtein ProteinSequence IsProteinFor',
	    $constraint, $feature_ids,
	    'IsBuiltFromAlignment(from_link)',0);
    
    #2) put the tree ids in a single straight-up list
    my @return_list = ();
    foreach (@{$rows}) { push(@return_list,${$_}[0]); }
    #3) remove duplicates
    my @return_list = uniq(@return_list);
    #4) return the result
    $return = \@return_list;
    #END get_tree_ids_by_feature
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_tree_ids_by_feature:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_tree_ids_by_feature');
    }
    return($return);
}




=head2 get_tree_ids_by_protein_sequence

  $return = $obj->get_tree_ids_by_protein_sequence($protein_sequence_ids)

=over 4

=item Parameter and return types

=begin html

<pre>
$protein_sequence_ids is a reference to a list where each element is a Tree.kbase_id
$return is a reference to a list where each element is a Tree.kbase_id
kbase_id is a string

</pre>

=end html

=begin text

$protein_sequence_ids is a reference to a list where each element is a Tree.kbase_id
$return is a reference to a list where each element is a Tree.kbase_id
kbase_id is a string


=end text



=item Description

Given a list of kbase ids of a protein sequences (their MD5s), retrieve the tree ids of trees that
were built based on these sequences.

=back

=cut

sub get_tree_ids_by_protein_sequence
{
    my $self = shift;
    my($protein_sequence_ids) = @_;

    my @_bad_arguments;
    (ref($protein_sequence_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"protein_sequence_ids\" (value was \"$protein_sequence_ids\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_tree_ids_by_protein_sequence:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_tree_ids_by_protein_sequence');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN get_tree_ids_by_protein_sequence
    # 1) construct and execute the query
    my $erdb = $self->{erdb};    
    my $n = @$protein_sequence_ids;
    my $targets = "(" . ('?,' x $n); chop $targets; $targets .= ')';
    my $constraint = "ContainsAlignedProtein(to_link) IN $targets ORDER BY IsBuiltFromAlignment(from_link)";
    my $rows = $erdb->GetAll('IsBuiltFromAlignment Alignment IsAlignmentRowIn AlignmentRow ContainsAlignedProtein',
	    $constraint, $protein_sequence_ids,
	    'IsBuiltFromAlignment(from_link)',0);
    
    #2) put the tree ids in a single straight-up list
    my @return_list = ();
    foreach (@{$rows}) { push(@return_list,${$_}[0]); }
    #3) remove duplicates
    my @return_list = uniq(@return_list);
    #4) return the result
    $return = \@return_list;
    #END get_tree_ids_by_protein_sequence
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_tree_ids_by_protein_sequence:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_tree_ids_by_protein_sequence');
    }
    return($return);
}




=head2 get_alignment_ids_by_feature

  $return = $obj->get_alignment_ids_by_feature($feature_ids)

=over 4

=item Parameter and return types

=begin html

<pre>
$feature_ids is a reference to a list where each element is a Tree.kbase_id
$return is a reference to a list where each element is a Tree.kbase_id
kbase_id is a string

</pre>

=end html

=begin text

$feature_ids is a reference to a list where each element is a Tree.kbase_id
$return is a reference to a list where each element is a Tree.kbase_id
kbase_id is a string


=end text



=item Description

Given a list of feature ids in kbase, the protein sequence of each feature (if the sequence exists)
is identified and used to retrieve all alignments by ID that were built using the given protein sequence.

=back

=cut

sub get_alignment_ids_by_feature
{
    my $self = shift;
    my($feature_ids) = @_;

    my @_bad_arguments;
    (ref($feature_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"feature_ids\" (value was \"$feature_ids\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_alignment_ids_by_feature:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_alignment_ids_by_feature');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN get_alignment_ids_by_feature
    # 1) construct and execute the query
    my $erdb = $self->{erdb};    
    my $n = @$feature_ids;
    my $targets = "(" . ('?,' x $n); chop $targets; $targets .= ')';
    my $constraint = "IsProteinFor(to_link) IN $targets ORDER BY IncludesAlignmentRow(from_link)";
    my $rows = $erdb->GetAll('IncludesAlignmentRow AlignmentRow ContainsAlignedProtein ProteinSequence IsProteinFor',
	    $constraint, $feature_ids,
	    'IncludesAlignmentRow(from_link)',0);
    #2) put the tree ids in a single straight-up list
    my @return_list = ();
    foreach (@{$rows}) { push(@return_list,${$_}[0]); }
    #3) remove duplicates
    my @return_list = uniq(@return_list);
    #4) return the result
    $return = \@return_list;
    #END get_alignment_ids_by_feature
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_alignment_ids_by_feature:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_alignment_ids_by_feature');
    }
    return($return);
}




=head2 get_alignment_ids_by_protein_sequence

  $return = $obj->get_alignment_ids_by_protein_sequence($protein_sequence_ids)

=over 4

=item Parameter and return types

=begin html

<pre>
$protein_sequence_ids is a reference to a list where each element is a Tree.kbase_id
$return is a reference to a list where each element is a Tree.kbase_id
kbase_id is a string

</pre>

=end html

=begin text

$protein_sequence_ids is a reference to a list where each element is a Tree.kbase_id
$return is a reference to a list where each element is a Tree.kbase_id
kbase_id is a string


=end text



=item Description

Given a list of kbase ids of a protein sequences (their MD5s), retrieve the alignment ids of trees that
were built based on these sequences.

=back

=cut

sub get_alignment_ids_by_protein_sequence
{
    my $self = shift;
    my($protein_sequence_ids) = @_;

    my @_bad_arguments;
    (ref($protein_sequence_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"protein_sequence_ids\" (value was \"$protein_sequence_ids\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_alignment_ids_by_protein_sequence:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_alignment_ids_by_protein_sequence');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN get_alignment_ids_by_protein_sequence
    # 1) construct and execute the query
    my $erdb = $self->{erdb};    
    my $n = @$protein_sequence_ids;
    my $targets = "(" . ('?,' x $n); chop $targets; $targets .= ')';
    my $constraint = "ContainsAlignedProtein(to_link) IN $targets ORDER BY IncludesAlignmentRow(from_link)";
    my $rows = $erdb->GetAll('IncludesAlignmentRow AlignmentRow ContainsAlignedProtein',
	    $constraint, $protein_sequence_ids,
	    'IncludesAlignmentRow(from_link)',0);
    
    #2) put the tree ids in a single straight-up list
    my @return_list = ();
    foreach (@{$rows}) { push(@return_list,${$_}[0]); }
    #3) remove duplicates
    my @return_list = uniq(@return_list);
    #4) return the result
    $return = \@return_list;
    #END get_alignment_ids_by_protein_sequence
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_alignment_ids_by_protein_sequence:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_alignment_ids_by_protein_sequence');
    }
    return($return);
}




=head2 get_tree_ids_by_source_id_pattern

  $return = $obj->get_tree_ids_by_source_id_pattern($pattern)

=over 4

=item Parameter and return types

=begin html

<pre>
$pattern is a string
$return is a reference to a list where each element is a reference to a list where each element is a Tree.kbase_id
kbase_id is a string

</pre>

=end html

=begin text

$pattern is a string
$return is a reference to a list where each element is a reference to a list where each element is a Tree.kbase_id
kbase_id is a string


=end text



=item Description

This method searches for a tree having a source ID that matches the input pattern.  This method accepts
one argument, which is the pattern.  The pattern is very simple and includes only two special characters,
wildcard character, '*', and a match-once character, '.'  The wildcard character matches any number (including
0) of any character, the '.' matches exactly one of any character.  These special characters can be escaped
with a backslash.  To match a blackslash literally, you must also escape it.  Note that source IDs are
generally defined by the gene family model which was used to identifiy the sequences to be included in
the tree.  Therefore, matching a source ID is a convenient way to find trees for a specific set of gene
families.

=back

=cut

sub get_tree_ids_by_source_id_pattern
{
    my $self = shift;
    my($pattern) = @_;

    my @_bad_arguments;
    (!ref($pattern)) or push(@_bad_arguments, "Invalid type for argument \"pattern\" (value was \"$pattern\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_tree_ids_by_source_id_pattern:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_tree_ids_by_source_id_pattern');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN get_tree_ids_by_source_id_pattern
    
    $return = [];
    if($pattern ne '') { 
	$return = $self->{comm}->findKBaseTreeByProteinFamilyName($pattern);
    }

    #END get_tree_ids_by_source_id_pattern
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_tree_ids_by_source_id_pattern:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_tree_ids_by_source_id_pattern');
    }
    return($return);
}




=head2 get_leaf_to_protein_map

  $return = $obj->get_leaf_to_protein_map($tree_id)

=over 4

=item Parameter and return types

=begin html

<pre>
$tree_id is a Tree.kbase_id
$return is a reference to a hash where the key is a Tree.kbase_id and the value is a Tree.kbase_id
kbase_id is a string

</pre>

=end html

=begin text

$tree_id is a Tree.kbase_id
$return is a reference to a hash where the key is a Tree.kbase_id and the value is a Tree.kbase_id
kbase_id is a string


=end text



=item Description

Given a tree id, this method returns a mapping from a tree's unique internal ID to
a protein sequence ID.

=back

=cut

sub get_leaf_to_protein_map
{
    my $self = shift;
    my($tree_id) = @_;

    my @_bad_arguments;
    (!ref($tree_id)) or push(@_bad_arguments, "Invalid type for argument \"tree_id\" (value was \"$tree_id\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_leaf_to_protein_map:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_leaf_to_protein_map');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN get_leaf_to_protein_map
    
    $return = {};
    my $erdb = $self->{erdb};
    my $pids_raw = $erdb->GetAll('IsBuiltFromAlignment Alignment IsAlignmentRowIn AlignmentRow ContainsAlignedProtein',
			    'IsBuiltFromAlignment(from_link) = ? ORDER BY AlignmentRow(row-id),ContainsAlignedProtein(to-link)', [$tree_id],
			    'AlignmentRow(row-id) ContainsAlignedProtein(to-link)',0);
    my @pids = @{$pids};
    foreach my $p (@pids) {
	$return->{${$p}[0]} = ${$p}[1];
    }
    
    #END get_leaf_to_protein_map
    my @_bad_returns;
    (ref($return) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_leaf_to_protein_map:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_leaf_to_protein_map');
    }
    return($return);
}




=head2 get_leaf_to_feature_map

  $return = $obj->get_leaf_to_feature_map($tree_id)

=over 4

=item Parameter and return types

=begin html

<pre>
$tree_id is a Tree.kbase_id
$return is a reference to a hash where the key is a Tree.kbase_id and the value is a Tree.kbase_id
kbase_id is a string

</pre>

=end html

=begin text

$tree_id is a Tree.kbase_id
$return is a reference to a hash where the key is a Tree.kbase_id and the value is a Tree.kbase_id
kbase_id is a string


=end text



=item Description

Given a tree id, this method returns a mapping from a tree's unique internal ID to
a KBase feature ID if and only if a cannonical feature id exists.

=back

=cut

sub get_leaf_to_feature_map
{
    my $self = shift;
    my($tree_id) = @_;

    my @_bad_arguments;
    (!ref($tree_id)) or push(@_bad_arguments, "Invalid type for argument \"tree_id\" (value was \"$tree_id\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_leaf_to_feature_map:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_leaf_to_feature_map');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN get_leaf_to_feature_map
    
    $return = {};
    my $erdb = $self->{erdb};
    my $fids = $erdb->GetAll('IsBuiltFromAlignment Alignment IsAlignmentRowIn AlignmentRow ContainsAlignedProtein',
			    'IsBuiltFromAlignment(from_link) = ?', [$tree_id],
			    'AlignmentRow(row-id) ContainsAlignedProtein(kb-feature-id)',0);
    my @fids = @{$fids};
    foreach my $f (@fids) {
	$return->{${$f}[0]} = ${$f}[1];
    }
    
    #END get_leaf_to_feature_map
    my @_bad_returns;
    (ref($return) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_leaf_to_feature_map:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_leaf_to_feature_map');
    }
    return($return);
}




=head2 compute_abundance_profile

  $abundance_result = $obj->compute_abundance_profile($abundance_params)

=over 4

=item Parameter and return types

=begin html

<pre>
$abundance_params is a Tree.AbundanceParams
$abundance_result is a Tree.AbundanceResult
AbundanceParams is a reference to a hash where the following keys are defined:
	tree_id has a value which is a Tree.kbase_id
	protein_family_name has a value which is a string
	protein_family_source has a value which is a string
	metagenomic_sample_id has a value which is a string
	percent_identity_threshold has a value which is an int
	match_length_threshold has a value which is an int
	mg_auth_key has a value which is a string
kbase_id is a string
AbundanceResult is a reference to a hash where the following keys are defined:
	abundances has a value which is a reference to a hash where the key is a string and the value is an int
	n_hits has a value which is an int
	n_reads has a value which is an int

</pre>

=end html

=begin text

$abundance_params is a Tree.AbundanceParams
$abundance_result is a Tree.AbundanceResult
AbundanceParams is a reference to a hash where the following keys are defined:
	tree_id has a value which is a Tree.kbase_id
	protein_family_name has a value which is a string
	protein_family_source has a value which is a string
	metagenomic_sample_id has a value which is a string
	percent_identity_threshold has a value which is an int
	match_length_threshold has a value which is an int
	mg_auth_key has a value which is a string
kbase_id is a string
AbundanceResult is a reference to a hash where the following keys are defined:
	abundances has a value which is a reference to a hash where the key is a string and the value is an int
	n_hits has a value which is an int
	n_reads has a value which is an int


=end text



=item Description

Given an input KBase tree built from a sequence alignment, a metagenomic sample, and a protein family, this method
will tabulate the number of reads that match to every leaf of the input tree.  First, a set of assembled reads from
a metagenomic sample are pulled from the KBase communities service which have been determined to be a likely hit
to the specified protein family.  Second, the sequences aligned to generate the tree are retrieved.  Third, UCLUST [1]
is used to map reads to target sequences of the tree.  Finally, for each leaf in the tree, the number of hits matching
the input search criteria is tabulated and returned.  See the defined objects 'abundance_params' and 'abundance_result'
for additional details on specifying the input parameters and handling the results.

[1] Edgar, R.C. (2010) Search and clustering orders of magnitude faster than BLAST, Bioinformatics 26(19), 2460-2461.

=back

=cut

sub compute_abundance_profile
{
    my $self = shift;
    my($abundance_params) = @_;

    my @_bad_arguments;
    (ref($abundance_params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"abundance_params\" (value was \"$abundance_params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to compute_abundance_profile:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'compute_abundance_profile');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($abundance_result);
    #BEGIN compute_abundance_profile
    
    # validate inputs!!!
    if(!exists($abundance_params->{tree_id})) {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(
		error => "'tree_id' input field not set, but required" ,
		method_name => 'compute_abundance_profile');
    }
    if(!exists($abundance_params->{protein_family_name})) {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(
		error => "'protein_family_name' input field not set, but required" ,
		method_name => 'compute_abundance_profile');
    }
    if(!exists($abundance_params->{protein_family_source})) {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(
		error => "'protein_family_source' input field not set, but required" ,
		method_name => 'compute_abundance_profile');
    }
    if(!exists($abundance_params->{metagenomic_sample_id})) {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(
		error => "'metagenomic_sample_id' input field not set, but required" ,
		method_name => 'compute_abundance_profile');
    }
    if(!exists($abundance_params->{percent_identity_threshold})) {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(
		error => "'percent_identity_threshold' input field not set, but required" ,
		method_name => 'compute_abundance_profile');
    }
    if(!exists($abundance_params->{match_length_threshold})) {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(
		error => "'match_length_threshold' input field not set, but required" ,
		method_name => 'compute_abundance_profile');
    }
    if(!exists($abundance_params->{mg_auth_key})) {
	$abundance_params->{mg_auth_key}='';
    }
    
    # pass on the call to someone who will actually do the work
    my ($abundance_counts,$n_hits,$n_reads) = $self->{comm}->runQiimeUclust($abundance_params);
    my $abundance_result = {abundances => $abundance_counts, n_hits=>$n_hits, n_reads=>$n_reads};
    
    #print Dumper($abundance_result)."\n";
    #END compute_abundance_profile
    my @_bad_returns;
    (ref($abundance_result) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"abundance_result\" (value was \"$abundance_result\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to compute_abundance_profile:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'compute_abundance_profile');
    }
    return($abundance_result);
}




=head2 filter_abundance_profile

  $abundance_data_processed = $obj->filter_abundance_profile($abundance_data, $filter_params)

=over 4

=item Parameter and return types

=begin html

<pre>
$abundance_data is a Tree.abundance_data
$filter_params is a Tree.FilterParams
$abundance_data_processed is a Tree.abundance_data
abundance_data is a reference to a hash where the key is a string and the value is a Tree.abundance_profile
abundance_profile is a reference to a hash where the key is a string and the value is a float
FilterParams is a reference to a hash where the following keys are defined:
	cutoff_value has a value which is a float
	use_cutoff_value has a value which is a Tree.boolean
	cutoff_number_of_records has a value which is a float
	use_cutoff_number_of_records has a value which is a Tree.boolean
	normalization_scope has a value which is a string
	normalization_type has a value which is a string
	normalization_post_process has a value which is a string
boolean is an int

</pre>

=end html

=begin text

$abundance_data is a Tree.abundance_data
$filter_params is a Tree.FilterParams
$abundance_data_processed is a Tree.abundance_data
abundance_data is a reference to a hash where the key is a string and the value is a Tree.abundance_profile
abundance_profile is a reference to a hash where the key is a string and the value is a float
FilterParams is a reference to a hash where the following keys are defined:
	cutoff_value has a value which is a float
	use_cutoff_value has a value which is a Tree.boolean
	cutoff_number_of_records has a value which is a float
	use_cutoff_number_of_records has a value which is a Tree.boolean
	normalization_scope has a value which is a string
	normalization_type has a value which is a string
	normalization_post_process has a value which is a string
boolean is an int


=end text



=item Description

ORDER OF OPERATIONS:
1) using normalization scope, defines whether process should occur per column or globally over every column
2) using normalization type, normalize by dividing values by the option indicated
3) apply normalization post process if set (ie take log of the result)
4) apply the cutoff_value threshold to all records, eliminating any that are not above the specified threshold
5) apply the cutoff_number_of_records (always applies per_column!!!), discarding any record that are not in the top N record values for that column

- if a value is not a valid number, it is ignored

=back

=cut

sub filter_abundance_profile
{
    my $self = shift;
    my($abundance_data, $filter_params) = @_;

    my @_bad_arguments;
    (ref($abundance_data) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"abundance_data\" (value was \"$abundance_data\")");
    (ref($filter_params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"filter_params\" (value was \"$filter_params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to filter_abundance_profile:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'filter_abundance_profile');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($abundance_data_processed);
    #BEGIN filter_abundance_profile
    
    # @todo: perform some error checking on the input
    
    my $abundance_data_processed = $self->{comm}->filter_abundance_profile($abundance_data,$filter_params);
    
    #END filter_abundance_profile
    my @_bad_returns;
    (ref($abundance_data_processed) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"abundance_data_processed\" (value was \"$abundance_data_processed\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to filter_abundance_profile:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'filter_abundance_profile');
    }
    return($abundance_data_processed);
}




=head2 draw_html_tree

  $return = $obj->draw_html_tree($tree, $display_options)

=over 4

=item Parameter and return types

=begin html

<pre>
$tree is a Tree.newick_tree
$display_options is a reference to a hash where the key is a string and the value is a string
$return is a Tree.html_file
newick_tree is a Tree.tree
tree is a string
html_file is a string

</pre>

=end html

=begin text

$tree is a Tree.newick_tree
$display_options is a reference to a hash where the key is a string and the value is a string
$return is a Tree.html_file
newick_tree is a Tree.tree
tree is a string
html_file is a string


=end text



=item Description

Given a tree structure in newick, render it in HTML/JAVASCRIPT and return the page as a string. display_options
provides a way to pass parameters to the tree rendering algorithm, but currently no options are recognized.

=back

=cut

sub draw_html_tree
{
    my $self = shift;
    my($tree, $display_options) = @_;

    my @_bad_arguments;
    (!ref($tree)) or push(@_bad_arguments, "Invalid type for argument \"tree\" (value was \"$tree\")");
    (ref($display_options) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"display_options\" (value was \"$display_options\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to draw_html_tree:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'draw_html_tree');
    }

    my $ctx = $Bio::KBase::Tree::Service::CallContext;
    my($return);
    #BEGIN draw_html_tree
    
    # remove spaces by cleaning the label (removes spaces, commas, whitespace)
    my $kb_tree = new Bio::KBase::Tree::TreeCppUtil::KBTree($tree,0,0);
    $kb_tree->setOutputFlagLabel(1);
    $kb_tree->setOutputFlagDistances(1);
    $kb_tree->setOutputFlagBootstrapValuesAsLabels(0);
    
    $kb_tree->stripReservedCharsFromLabels();
    
    $tree = $kb_tree->toNewick();
    
    
    # possible options ...
    #my ($help, $url, $alias_file, $focus_file, $branch, $collapse_by, $show_file,
    #$desc_file, $keep_file, $link_file, $text_link, $popup_file, $id_file, $title,
    #$min_dx, $dy, $ncolor, $color_by, $anno, $gray, $pseed, $ppseed, $raw, $va_files,
    #$scale_bar, $scale_lbl);
    my $opts = {raw=>1};
    my $tree_structure = ffxtree::read_tree(\$tree);
    $return = ffxtree::tree_to_html($tree_structure,$opts);
    #END draw_html_tree
    my @_bad_returns;
    (!ref($return)) or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to draw_html_tree:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'draw_html_tree');
    }
    return($return);
}




=head2 version 

  $return = $obj->version()

=over 4

=item Parameter and return types

=begin html

<pre>
$return is a string
</pre>

=end html

=begin text

$return is a string

=end text

=item Description

Return the module version. This is a Semantic Versioning number.

=back

=cut

sub version {
    return $VERSION;
}

=head1 TYPES



=head2 boolean

=over 4



=item Description

indicates true or false values, false <= 0, true >=1


=item Definition

=begin html

<pre>
an int
</pre>

=end html

=begin text

an int

=end text

=back



=head2 timestamp

=over 4



=item Description

time in units of number of seconds since the epoch


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 position

=over 4



=item Description

integer number indicating a 1-based position in an amino acid / nucleotide sequence


=item Definition

=begin html

<pre>
an int
</pre>

=end html

=begin text

an int

=end text

=back



=head2 kbase_id

=over 4



=item Description

A KBase ID is a string starting with the characters "kb|".  KBase IDs are typed. The types are
designated using a short string. For instance," g" denotes a genome, "tree" denotes a Tree, and
"aln" denotes a sequence alignment. KBase IDs may be hierarchical.  For example, if a KBase genome
identifier is "kb|g.1234", a protein encoding gene within that genome may be represented as
"kb|g.1234.peg.771".


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 tree

=over 4



=item Description

A string representation of a phylogenetic tree.  The format/syntax of the string is
specified by using one of the available typedefs declaring a particular format, such as 'newick_tree',
'phylo_xml_tree' or 'json_tree'.  When a format is not explictily specified, it is possible to return
trees in different formats depending on addtional parameters. Regardless of format, all leaf nodes
in trees built from MSAs are indexed to a specific MSA row.  You can use the appropriate functionality
of the API to replace these IDs with other KBase Ids instead. Internal nodes may or may not be named.
Nodes, depending on the format, may also be annotated with structured data such as bootstrap values and
distances.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 newick_tree

=over 4



=item Description

Trees are represented in KBase by default in newick format (http://en.wikipedia.org/wiki/Newick_format)
and are returned to you in this format by default.


=item Definition

=begin html

<pre>
a Tree.tree
</pre>

=end html

=begin text

a Tree.tree

=end text

=back



=head2 phylo_xml_tree

=over 4



=item Description

Trees are represented in KBase by default in newick format (http://en.wikipedia.org/wiki/Newick_format),
but can optionally be converted to the more verbose phyloXML format, which is useful for compatibility or
when additional information/annotations decorate the tree.


=item Definition

=begin html

<pre>
a Tree.tree
</pre>

=end html

=begin text

a Tree.tree

=end text

=back



=head2 json_tree

=over 4



=item Description

Trees are represented in KBase by default in newick format (http://en.wikipedia.org/wiki/Newick_format),
but can optionally be converted to JSON format where the structure of the tree matches the structure of
the JSON object.  This is useful when interacting with the tree in JavaScript, for instance.


=item Definition

=begin html

<pre>
a Tree.tree
</pre>

=end html

=begin text

a Tree.tree

=end text

=back



=head2 alignment

=over 4



=item Description

String representation of a sequence alignment, the format of which may be different depending on
input options for retrieving the alignment.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 fasta

=over 4



=item Description

String representation of a sequence or set of sequences in FASTA format.  The precise alphabet used is
not yet specified, but will be similar to sequences stored in KBase with '-' to denote gaps in alignments.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 fasta_alignment

=over 4



=item Description

String representation of an alignment in FASTA format.  The precise alphabet and syntax of the alignment
string is not yet specified, but will be similar to sequences stored in KBase  with '-' to denote gaps in
alignments.


=item Definition

=begin html

<pre>
a Tree.fasta
</pre>

=end html

=begin text

a Tree.fasta

=end text

=back



=head2 node_name

=over 4



=item Description

The string representation of the parsed node name (may be a kbase_id, but does not have to be).  Note that this
is not the full, raw label in a newick_tree (which may include comments).


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 html_file

=over 4



=item Description

String in HTML format, used in the KBase Tree library for returning rendered trees.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 TreeMetaData

=over 4



=item Description

Meta data associated with a tree.

    kbase_id alignment_id - if this tree was built from an alignment, this provides that alignment id
    string type - the type of tree; possible values currently are "sequence_alignment" and "genome" for trees
                  either built from a sequence alignment, or imported directly indexed to genomes.
    string status - set to 'active' if this is the latest built tree for a particular gene family
    timestamp date_created - time at which the tree was built/loaded in seconds since the epoch
    string tree_contruction_method - the name of the software used to construct the tree
    string tree_construction_parameters - any non-default parameters of the tree construction method
    string tree_protocol - simple free-form text which may provide additional details of how the tree was built
    int node_count - total number of nodes in the tree
    int leaf_count - total number of leaf nodes in the tree (generally this cooresponds to the number of sequences)
    string source_db - the source database where this tree originated, if one exists
    string source_id - the id of this tree in an external database, if one exists


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
alignment_id has a value which is a Tree.kbase_id
type has a value which is a string
status has a value which is a string
date_created has a value which is a Tree.timestamp
tree_contruction_method has a value which is a string
tree_construction_parameters has a value which is a string
tree_protocol has a value which is a string
node_count has a value which is an int
leaf_count has a value which is an int
source_db has a value which is a string
source_id has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
alignment_id has a value which is a Tree.kbase_id
type has a value which is a string
status has a value which is a string
date_created has a value which is a Tree.timestamp
tree_contruction_method has a value which is a string
tree_construction_parameters has a value which is a string
tree_protocol has a value which is a string
node_count has a value which is an int
leaf_count has a value which is an int
source_db has a value which is a string
source_id has a value which is a string


=end text

=back



=head2 AlignmentMetaData

=over 4



=item Description

Meta data associated with an alignment.

    list<kbase_id> tree_ids - the set of trees that were built from this alignment
    string status - set to 'active' if this is the latest alignment for a particular set of sequences
    string sequence_type - indicates what type of sequence is aligned (e.g. protein vs. dna)
    boolean is_concatenation - true if the alignment is based on the concatenation of multiple non-contiguous
                            sequences, false if each row cooresponds to exactly one sequence (possibly with gaps)
    timestamp date_created - time at which the alignment was built/loaded in seconds since the epoch
    int n_rows - number of rows in the alignment
    int n_cols - number of columns in the alignment
    string alignment_construction_method - the name of the software tool used to build the alignment
    string alignment_construction_parameters - set of non-default parameters used to construct the alignment
    string alignment_protocol - simple free-form text which may provide additional details of how the alignment was built
    string source_db - the source database where this alignment originated, if one exists
    string source_id - the id of this alignment in an external database, if one exists


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
tree_ids has a value which is a reference to a list where each element is a Tree.kbase_id
status has a value which is a string
sequence_type has a value which is a string
is_concatenation has a value which is a string
date_created has a value which is a Tree.timestamp
n_rows has a value which is an int
n_cols has a value which is an int
alignment_construction_method has a value which is a string
alignment_construction_parameters has a value which is a string
alignment_protocol has a value which is a string
source_db has a value which is a string
source_id has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
tree_ids has a value which is a reference to a list where each element is a Tree.kbase_id
status has a value which is a string
sequence_type has a value which is a string
is_concatenation has a value which is a string
date_created has a value which is a Tree.timestamp
n_rows has a value which is an int
n_cols has a value which is an int
alignment_construction_method has a value which is a string
alignment_construction_parameters has a value which is a string
alignment_protocol has a value which is a string
source_db has a value which is a string
source_id has a value which is a string


=end text

=back



=head2 AbundanceParams

=over 4



=item Description

Structure to group input parameters to the compute_abundance_profile method.

    kbase_id tree_id                - the KBase ID of the tree to compute abundances for; the tree is
                                      used to identify the set of sequences that were aligned to build
                                      the tree; each leaf node of a tree built from an alignment will
                                      be mapped to a sequence; the compute_abundance_profile method
                                      assumes that trees are built from protein sequences
    string protein_family_name      - the name of the protein family used to pull a small set of reads
                                      from a metagenomic sample; currently only COG families are supported
    string protein_family_source    - the name of the source of the protein family; currently supported
                                      protein families are: 'COG'
    string metagenomic_sample_id    - the ID of the metagenomic sample to lookup; see the KBase communities
                                      service to identifiy metagenomic samples
    int percent_identity_threshold  - the minimum acceptable percent identity for hits, provided as a percentage
                                      and not a fraction (i.e. set to 87.5 for 87.5%)
    int match_length_threshold      - the minimum acceptable length of a match to consider a hit


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
tree_id has a value which is a Tree.kbase_id
protein_family_name has a value which is a string
protein_family_source has a value which is a string
metagenomic_sample_id has a value which is a string
percent_identity_threshold has a value which is an int
match_length_threshold has a value which is an int
mg_auth_key has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
tree_id has a value which is a Tree.kbase_id
protein_family_name has a value which is a string
protein_family_source has a value which is a string
metagenomic_sample_id has a value which is a string
percent_identity_threshold has a value which is an int
match_length_threshold has a value which is an int
mg_auth_key has a value which is a string


=end text

=back



=head2 AbundanceResult

=over 4



=item Description

Structure to group output of the compute_abundance_profile method.

    mapping <string,int> abundances - maps the raw row ID of each leaf node in the input tree to the number
                                      of hits that map to the given leaf; only row IDs with 1 or more hits
                                      are added to this map, thus missing leaf nodes imply 0 hits
    int n_hits                      - the total number of hits in this sample to any leaf
    int n_reads                     - the total number of reads that were identified for the input protein
                                      family; if the protein family could not be found this will be zero.


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
abundances has a value which is a reference to a hash where the key is a string and the value is an int
n_hits has a value which is an int
n_reads has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
abundances has a value which is a reference to a hash where the key is a string and the value is an int
n_hits has a value which is an int
n_reads has a value which is an int


=end text

=back



=head2 abundance_profile

=over 4



=item Description

map an id to a number (e.g. feature_id mapped to a log2 normalized abundance value)


=item Definition

=begin html

<pre>
a reference to a hash where the key is a string and the value is a float
</pre>

=end html

=begin text

a reference to a hash where the key is a string and the value is a float

=end text

=back



=head2 abundance_data

=over 4



=item Description

map the name of the profile with the profile data


=item Definition

=begin html

<pre>
a reference to a hash where the key is a string and the value is a Tree.abundance_profile
</pre>

=end html

=begin text

a reference to a hash where the key is a string and the value is a Tree.abundance_profile

=end text

=back



=head2 FilterParams

=over 4



=item Description

cutoff_value                  => def: 0 || [any_valid_float_value]
use_cutoff_value              => def: 0 || 1
normalization_scope           => def:'per_column' || 'global'
normalization_type            => def:'none' || 'total' || 'mean' || 'max' || 'min'
normalization_post_process    => def:'none' || 'log10' || 'log2' || 'ln'


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
cutoff_value has a value which is a float
use_cutoff_value has a value which is a Tree.boolean
cutoff_number_of_records has a value which is a float
use_cutoff_number_of_records has a value which is a Tree.boolean
normalization_scope has a value which is a string
normalization_type has a value which is a string
normalization_post_process has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
cutoff_value has a value which is a float
use_cutoff_value has a value which is a Tree.boolean
cutoff_number_of_records has a value which is a float
use_cutoff_number_of_records has a value which is a Tree.boolean
normalization_scope has a value which is a string
normalization_type has a value which is a string
normalization_post_process has a value which is a string


=end text

=back



=cut

1;
