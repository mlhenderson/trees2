# This file was automatically generated by SWIG (http://www.swig.org).
# Version 2.0.7
#
# Do not make changes to this file unless you know what you are doing--modify
# the SWIG interface file instead.

package KBTreeUtil;
use base qw(Exporter);
use base qw(DynaLoader);
package KBTreeUtilc;
bootstrap KBTreeUtil;
package KBTreeUtil;
@EXPORT = qw();

# ---------- BASE METHODS -------------

package KBTreeUtil;

sub TIEHASH {
    my ($classname,$obj) = @_;
    return bless $obj, $classname;
}

sub CLEAR { }

sub FIRSTKEY { }

sub NEXTKEY { }

sub FETCH {
    my ($self,$field) = @_;
    my $member_func = "swig_${field}_get";
    $self->$member_func();
}

sub STORE {
    my ($self,$field,$newval) = @_;
    my $member_func = "swig_${field}_set";
    $self->$member_func($newval);
}

sub this {
    my $ptr = shift;
    return tied(%$ptr);
}


# ------- FUNCTION WRAPPERS --------

package KBTreeUtil;


############# Class : KBTreeUtil::KBTree ##############

package KBTreeUtil::KBTree;
use vars qw(@ISA %OWNER %ITERATORS %BLESSEDMEMBERS);
@ISA = qw( KBTreeUtil );
%OWNER = ();
%ITERATORS = ();
sub new {
    my $pkg = shift;
    my $self = KBTreeUtilc::new_KBTree(@_);
    bless $self, $pkg if defined($self);
}

sub DESTROY {
    return unless $_[0]->isa('HASH');
    my $self = tied(%{$_[0]});
    return unless defined $self;
    delete $ITERATORS{$self};
    if (exists $OWNER{$self}) {
        KBTreeUtilc::delete_KBTree($self);
        delete $OWNER{$self};
    }
}

*toNewick = *KBTreeUtilc::KBTree_toNewick;
*writeNewickToFile = *KBTreeUtilc::KBTree_writeNewickToFile;
*removeNodesByNameAndSimplify = *KBTreeUtilc::KBTree_removeNodesByNameAndSimplify;
*printTree = *KBTreeUtilc::KBTree_printTree;
*getNodeCount = *KBTreeUtilc::KBTree_getNodeCount;
*getLeafCount = *KBTreeUtilc::KBTree_getLeafCount;
sub DISOWN {
    my $self = shift;
    my $ptr = tied(%$self);
    delete $OWNER{$ptr};
}

sub ACQUIRE {
    my $self = shift;
    my $ptr = tied(%$self);
    $OWNER{$ptr} = 1;
}


# ------- VARIABLE STUBS --------

package KBTreeUtil;

1;
