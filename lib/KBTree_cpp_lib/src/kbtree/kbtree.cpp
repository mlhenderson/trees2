/**
 * @file kbtree.cpp
 * @brief KBase Tree Utility Library Implementation
 *
 * @author Michael Sneddon, mwsneddon@lbl.gov
 * @date created Jun 6, 2012, last edited Jun 12
 */


/**
 * The tree library makes use of the C library assert functionality
 * for internal testing of the code.  Uncomment this define statement
 * when debugging, leave this statement commented to test assertions.
 * @see http://www.cplusplus.com/reference/clibrary/cassert/assert/
 */
//#define NDEBUG

// for parsing Newick strings, it is useful to define a set of
// characters we will need to identify and match frequently
#define OPEN_PARAN '('
#define CLOSE_PARAN ')'
#define COMMA ','
#define SEMICOLON ';'
#define COLON ':'
#define OPEN_BRACKET '['
#define CLOSE_BRACKET ']'
#define DBL_QUOTE '"'
#define SGL_QUOTE '\''


#include "kbtree.hh"
#include "tree.hh"
#include <iostream>
#include <algorithm>
#include <cassert>
#include <cmath>
#include <sstream>


using namespace std;
using namespace KBTreeLib;



void KBTreeLib::trim(std::string& str) {
	size_t startpos = str.find_first_not_of(" \t");
	size_t endpos = str.find_last_not_of(" \t");
	if(( string::npos == startpos ) || (string::npos == endpos)) {
		str="";
	} else {
		str = str.substr(startpos,endpos-startpos+1);
	}
}

double KBTreeLib::convertToDouble(const std::string& s)
{
	bool failIfLeftoverChars = true;
	std::istringstream i(s);
	double x; char c;
	if (!(i >> x) || (failIfLeftoverChars && i.get(c))) {
		cerr<<"Cannot convert string '"+s+"' to double value."<<endl; exit(1); //,"Util::convertToDouble(\"" + s + "\")");
	}
	return x;
}

std::string KBTreeLib::toString(double x)
{
	std::ostringstream o;
	if (!(o << x))
		cerr<<"Cannot convert double to string value."<<endl; exit(1);
	return o.str();
}

std::string KBTreeLib::getQuotedString(const std::string& s)
{
	string quoted_string=""; char C;
	bool reqQuote = false;
	for(unsigned int k=0;k<s.size();k++) {
		C = s.at(k);
		if(C==DBL_QUOTE) { quoted_string+='\\'; quoted_string+=C; reqQuote=true; }
		if(!reqQuote) {
			if(  C==OPEN_PARAN || C==CLOSE_PARAN  || C==COMMA         || C==SEMICOLON ||
			     C==COLON      || C==OPEN_BRACKET || C==CLOSE_BRACKET  ) {
				reqQuote=true;
			}
		}
	}
	if(reqQuote) { quoted_string = "\""+quoted_string+"\""; }
	return quoted_string;
}

std::string KBNode::getLabelFromComponents(unsigned int style) {

	string constructedLabel = "";

	if(style==0) { //name:distance, distance left blank if no distance
		constructedLabel=getQuotedString(name);
		if(!isnan(distanceToParent)) {
			constructedLabel+= (":"+toString(distanceToParent));
		}
	} else if (style==1) { //name
		constructedLabel=getQuotedString(name);
	} else if (style==2) { //name:distance + all comments, leave nothing out
		constructedLabel=("["+getQuotedString(pre_name_decoration)+"]");
		constructedLabel=getQuotedString(name);
		constructedLabel=("["+getQuotedString(post_name_decoration)+"]");
		constructedLabel+=":";
		constructedLabel=("["+getQuotedString(pre_dist_decoration)+"]");
		if(!isnan(distanceToParent)) { constructedLabel+= (":"+toString(distanceToParent)); }
		constructedLabel=("["+getQuotedString(post_dist_decoration)+"]");
	}
	// style: output only if comments are there

	return constructedLabel;
}




KBNode::KBNode()
{
	clear();
}
KBNode::~KBNode()
{
}

void KBNode::clear()
{
	this->label="";
	this->name="";
	this->pre_name_decoration="";
	this->post_name_decoration="";
	this->pre_dist_decoration="";
	this->post_dist_decoration="";
	this->distanceToParent=NAN;
}




KBTree::KBTree(const string &newickString)
{
	this->nodeCount=0;
	this->initializeFromNewick(newickString);
}

KBTree::~KBTree()
{
	// delete each node in the tree
	this->tr.clear();
}

void KBTree::initializeFromNewick(const std::string &newickString)
{
	// create and add the root node
	tr.set_head(KBNode());
	this->nodeCount++;
	unsigned int curserPosition = 0;
	// go on and parse the rest recursively
	tree<KBNode>::iterator rootIter = tr.begin();
	parseNewick(newickString,curserPosition,rootIter);
}


void printPos(const std::string &newickString, unsigned int &k)
{
	for(unsigned int j=0;j<k;j++) { cout<<" "; }
	cout<<"|"<<endl;
	cout<<newickString<<endl;
}

void KBTree::parseNewick(const std::string &newickString, unsigned int &k, tree<KBNode>::iterator &currentNode)
{
	//toNewick();
	//cout<<"START"<<endl;printPos(newickString,k);
	//cout<<"current node name: '"<<(*currentNode)->label<<"'"<<endl;

	// ditch leading white space first
	passLeadingWhiteSpace(newickString, k);
	if( k >= newickString.length() ) return;

	// if we get to an open parenthesis, then create a child and recurse down
	if( newickString.at(k)==OPEN_PARAN ) {
		//cout<<"OPEN"<<endl;printPos(newickString,k);
		// note here that the begin iterator points to the first child of the current node
		tree<KBNode>::iterator newChild = tr.insert(currentNode.begin(),KBNode());
		this->nodeCount++;
		k=k++;
		if( k >= newickString.length() ) { cerr<<"syntax error in tree"<<endl; exit(1); }
		if(newickString.at(k)!=CLOSE_PARAN) {
			parseNewick(newickString,k,newChild);
		}
	}

	// if we get to the end, then exit recursion
	if( k >= newickString.length() ) return;

	// if we get to a close parenthesis, then go on to the next position in the string
	if (newickString.at(k)==CLOSE_PARAN) {
		//cout<<"CLOSE"<<endl;printPos(newickString,k);
		k++;
	}

	// If we get here, then we are at a leaf node, so label it and look for children
	//getNextLabelWithoutComments(newickString,k,(*currentNode));
	getNextLabel(newickString,k,(*currentNode));

	//again make sure we can go further
	if( k >= newickString.length() ) return;

	// If we get to a comma, then the current node has some siblings, so recurse on the sibling node
	if (newickString.at(k)==COMMA) {
		//cout<<"COMMA"<<endl;printPos(newickString,k);
		tree<KBNode>::iterator newSibling = tr.insert_after(currentNode,KBNode());
		this->nodeCount++;
		k++;
		parseNewick(newickString,k,newSibling);
	}
}





/**
 * ignores comments (normally denoted by [..]), but does detect the first colon found and splits the string into names and distances
 * simply includes quotes as is in the strings without conversion
 */
bool KBTree::getNextLabelWithoutComments(const std::string &newickString, unsigned int &k, KBNode &node)
{
	std::string label = "";
	std::string nameString="";
	std::string distanceToParentString = "";

	bool afterColonOperator = false;
	char C;
	while( k<newickString.size() ) {
		C=newickString.at(k);

		// if we have to move somewhere else in the tree structure, then break (skipping over the closing semicolon)
		if ( C==OPEN_PARAN || C==CLOSE_PARAN || C==COMMA ) { break; }
		if ( C==SEMICOLON ) { k++; break; }

		// determine if we are before or after the colon (indicates name vs. distance)
		if(afterColonOperator) { distanceToParentString += C; }
		if (C==COLON) { afterColonOperator = true; }
		if(!afterColonOperator) { nameString += C; }

		//always add the character to be part of the label
		label += C;
		k++;
	}
	trim(label);trim(nameString);trim(distanceToParentString);
	node.label.assign(label);
	node.name.assign(nameString);
	if(distanceToParentString.size()>0) { node.distanceToParent = convertToDouble(distanceToParentString); }
	return true;
}




void getQuotedText(const std::string &newickString, unsigned int &k, string &quotedText, string &rawLabel, char QUOTE) {
	cout<<"**getting quoted text!"<<endl;
	// grab the quote, because we need to include this in the raw label
	rawLabel+=newickString.at(k);
	k++;
	assert(k>=1);
	quotedText="";
	while( k<newickString.size() ) {
		assert(k+1<newickString.size());
		char C = newickString.at(k);
		cout<<"  *gots:"<<C<<endl;
		if(C=='\\' && newickString.at(k+1)==QUOTE ) {
			rawLabel+=C;
			k++; C=newickString.at(k);
		}
		else if(C==QUOTE && newickString.at(k-1)!='\\' ) { break; }
		rawLabel+=C;
		quotedText+=C;
		k++;
	}
	cout<<"**got it chief!"<<endl;
}

bool KBTree::getNextLabel(const std::string &newickString, unsigned int &k, KBNode &node)
{
	// reserve all of the components that might be needed to label the Node
	std::string label = "";
	std::string distanceToParentString = "";
	std::string nameString = "";
	std::string preNameComment  = "";
	std::string postNameComment = "";
	std::string preDistComment  = "";
	std::string postDistComment = "";

	// keep track of what we are currently parsing
	unsigned int commentType = 0; // 0=name/distance/delimeter, 1=preName, 2=postName, 3=preDist, 4=postDist
	bool afterColonOperator = false;
	bool quotedTextWasFound = false;

	char C; string textToAdd;
	while( k<newickString.size() ) {

		// first things first - get the next character
		C=newickString.at(k);

		// Now handle anything in quotes.  Note how this is a bit deceptive.  We first save the character to
		// the textToAdd string.  This will be the text that we eventually add to the comment, name, or distance
		// strings.  By default we set it to be just the value of the current character that we see.  But if that
		// character is a quote, then we parse the entire quote and overwrite the variable textToAdd.  Then later,
		// we can simply add textToAdd to the appropriate string.  Note that this also advances k such that we
		// won't try to parse anything inside the quoted string as a special character
		textToAdd=""; textToAdd+=C; quotedTextWasFound=false;
		if ( C==SGL_QUOTE ) { getQuotedText(newickString,k,textToAdd,label,SGL_QUOTE); }
		if ( C==DBL_QUOTE ) { getQuotedText(newickString,k,textToAdd,label,DBL_QUOTE); }

		//detect if we have to close a comment block (asserting that a comment was previously open)
		//should we force that a ']' cannot be used unless it is in a comment or quoted string? I think so.
		if ( C==CLOSE_BRACKET ) {
			assert(commentType!=0);
			commentType = 0;
		}

		//if we aren't closing a comment, then we should add the next character or quoted text to
		//something, or detect that it is a special character
		else {
			//handle cases where we are in comments first, adding either the character or the quoted text
			if(commentType==1)       { preNameComment+=textToAdd;  }
			else if(commentType==2)  { postNameComment+=textToAdd; }
			else if(commentType==3)  { preDistComment+=textToAdd;  }
			else if(commentType==4)  { postDistComment+=textToAdd; }

			// if we are not in a comment, then we can process special characters or determine if the character or
			// quoted text should be placed in a name or distanceFromParent string
			else if(commentType==0) {

				// if we have to move somewhere else in the tree structure, then break (skipping over the closing semicolon)
				if ( C==OPEN_PARAN || C==CLOSE_PARAN || C==COMMA ) { assert(commentType==0); break; }
				if ( C==SEMICOLON ) { assert(commentType==0); k++; break; }

				// detect if we are opening a comment block, and determine where this block appears
				if ( C==OPEN_BRACKET ) {
					trim(distanceToParentString); trim(nameString);
					if(afterColonOperator) {
						if(distanceToParentString.size()==0) { commentType=3; }
						else { commentType=4; }
					} else {
						if(nameString.size()==0) { commentType = 1; }
						else {commentType = 2; }
					}
				}
				// if we get here, then we have to add the character or quoted text to the name/distance strings
				else{
					// determine if we are before or after the colon (indicates name vs. distance)
					if(afterColonOperator) { distanceToParentString += textToAdd; }
					if (newickString.at(k)==COLON) { afterColonOperator = true; }
					if(!afterColonOperator) { nameString += textToAdd; }
				}
			}
		}

		//always add the character to be part of the label (note that quoted text was already added above if it was found)
		label += C;
		k++;
	}
	trim(label);

	node.label.assign(label);
	node.name.assign(nameString);
	if(distanceToParentString.size()>0) { node.distanceToParent = convertToDouble(distanceToParentString); }
	node.pre_name_decoration.assign(preNameComment);
	node.post_name_decoration.assign(postNameComment);
	node.pre_dist_decoration.assign(preDistComment);
	node.post_dist_decoration.assign(postDistComment);

	cout<<" LABEL=>'"<<label<<"'"<<endl;
	cout<<" NAME=>'"<<nameString<<"'"<<endl;
	cout<<" DIST=>'"<<distanceToParentString<<"'"<<endl;

	cout<<" PRENAME=>'"<<preNameComment<<"'"<<endl;
	cout<<" POSTNAME=>'"<<postNameComment<<"'"<<endl;
	cout<<" PREDIST=>'"<<preDistComment<<"'"<<endl;
	cout<<" POSTDIST=>'"<<postDistComment<<"'"<<endl;

	return true;
}

void KBTree::passLeadingWhiteSpace(const std::string &newickString, unsigned int &k)
{
	char C=newickString.at(k);
	while( k<newickString.size() ) {
		if( C!=' ' && C!='\t' && C!='\n' && C!='\r' ) {
			break;
		}
		k++;
	}
}

void KBTree::printTree(ostream &o) {
	KBTree::printTree(o,this->tr,this->tr.begin(),this->tr.end());
}

void KBTree::printTree(ostream &o, const tree<KBNode>& tr, tree<KBNode>::pre_order_iterator it, tree<KBNode>::pre_order_iterator end)
{
	o<<"*****************"<<endl;
	o<<"Tree Size: "<<tr.size()<<endl;
	if(!tr.is_valid(it)) return;
	int rootdepth=tr.depth(it);
	o << "-----" << std::endl;
	while(it!=end) {
		for(int i=0; i<tr.depth(it)-rootdepth; ++i)
			o << "  ";
		o << (*it).name<<"   (dist="<<(*it).distanceToParent <<",full="<<(*it).label<<")"<< std::endl << std::flush;
		++it;
	}
	o << "*****************" << std::endl;
}



void printAllNodes(ostream &o)
{
//	for(int i=0;i<node_list.size();i++) {
//		o<<"["<<i<<"]:'"<<node_list.at(i)->label<<"'";
//		if(node_list.at(i)->firstChild!=NULL) o<<", firstChild='"<<node_list.at(i)->firstChild->label<<"'";
//		if(node_list.at(i)->right!=NULL) o<<", right='"<<node_list.at(i)->right->label<<"'";
//		if(node_list.at(i)->parent!=NULL) o<<", parent='"<<node_list.at(i)->parent->label<<"'";
//		o<<endl;
//	}
}




std::string KBTree::toNewick()
{
	// retrieve the root node, then call the recursive version of this function
	std::string newickString="";
	tree<KBNode>::iterator rootIter = tr.begin();
	toNewick(rootIter, newickString);
	return newickString;
}

void KBTree::toNewick(tree<KBNode>::iterator &currentNode, std::string &newickString)
{
	assert(currentNode!=NULL);
	//cout<<"here:"<<newickString<<":"<<(*currentNode)->label<<endl;
	// First check if we have children, if we do then descend to that child
	if(tree<KBNode>::number_of_children(currentNode)>0) {
		//cout<<"  -num of children>0"<<endl;
		newickString+="(";
		tree<KBNode>::iterator childIter = currentNode.begin();
		toNewick(childIter,newickString);
	}

	// Next check if we have siblings, and if so we have to go there next
	tree<KBNode>::iterator sibling = tr.next_sibling(currentNode);
	if(sibling!=NULL && sibling!=tr.end()) {
		// if we have a next sibling, then go there
		//cout<<"  -num of siblings>0"<<endl;
		newickString+=(*currentNode).label;
		newickString+=",";
		toNewick(sibling,newickString);
	}

	// If we don't have siblings, do we have a parent? if so go back up
	else if(tr.parent(currentNode)!=NULL && tr.parent(currentNode)!=tr.end()) {
		//cout<<"  -has parent"<<endl;
		newickString+=(*currentNode).label; //getLabelFromComponents(0);
		newickString+=")";
	}

	// And finally, if we don't have a parent, then we're back at root,
	// so print the label and close the tree with a semicolon.
	else {
		//cout<<"  -no siblings, no parent"<<endl;
		newickString+=(*currentNode).label;
		newickString+=";";
	}
}




void KBTree::removeNodesByNameAndSimplify(std::map<std::string,std::string> &nodeNames)
{
	// loop through the nodes in a depth-first, post-order traversal
	// thus, as we look at each node, we can assume all nodes below have been processed
	tree<KBNode>::post_order_iterator node;
	for(node=tr.begin_post(); node!=tr.end_post(); node++) {
		// look for this node in the removal list
		if( nodeNames.find((*node).getLabel())!=nodeNames.end() ) {
			// if we are a leaf node, then just erase
			if(tr.number_of_children(node)==0) { tr.erase(node); }
			// if we have children, then we must replace this node with its child
			else {
				//first, refactor distances to the child by adding the edge lengths
				//@TODO manage distances!
				tr.erase_and_reparent_children(node);
			}
		}
		else {
			// if it is not in the removal list, but it is unnamed and has only zero or one children, then remove
			if(((*node).getLabel()).size()==0) {
				if(tr.number_of_children(node)==0) { tr.erase(node); }
				else if (tr.number_of_children(node)==1) {
					//@TODO manage distances!

					cout<<"-erasing because node has no name and one child"<<endl;
					tr.erase_and_reparent_children(node);
				}

			}
		}
	}
}

void KBTree::replaceNodeNames(std::map<std::string,std::string> &nodeNames)
{
	tree<KBNode>::post_order_iterator node;
	map<string,string>::iterator name;
	for(node=tr.begin_post(); node!=tr.end_post(); node++) {
		name = nodeNames.find((*node).getLabel());
		cout<<"looking at node:"<<(*node).getLabel()<<endl;
		if( name!=nodeNames.end() ) {
			(*node).label=name->second;
		}
	}
}





void KBTree::getAllLeafNames(vector<string> &names) {
	tree<KBNode>::iterator leafIter;
	names.reserve((size_t)(1+getNodeCount()/2)); //assume full binary tree of leaves
	for(leafIter=tr.begin_leaf(); leafIter!=tr.end_leaf(); leafIter++) {
		string name = (*leafIter).getLabel();
		if(name.size()>0) { names.push_back(name); }
	}
}

void KBTree::getAllNodeNames(vector<string> &names) {
	names.reserve((size_t)(1+getNodeCount()));
	tree<KBNode>::post_order_iterator nodeIter;
	for(nodeIter=tr.begin_post(); nodeIter!=tr.end_post(); nodeIter++) {
		string name = (*nodeIter).getLabel();
		if(name.size()>0) { names.push_back(name); }
	}

}



void KBTree::printOutNamesAllPossibleTraversals(ostream &o)
{
	tree<KBNode>::iterator leafIter;
	for(leafIter=tr.begin_leaf(); leafIter!=tr.end_leaf(); leafIter++) {
		o<<"leafIter::"<<(*leafIter).getLabel()<<endl;
	}
	tree<KBNode>::post_order_iterator nodeIter;
	for(nodeIter=tr.begin_post(); nodeIter!=tr.end_post(); nodeIter++) {
		o<<"postOrderDF::"<<(*nodeIter).getLabel()<<endl;
	}

	tree<KBNode>::pre_order_iterator preNodeIter;
	for(preNodeIter=tr.begin(); preNodeIter!=tr.end(); preNodeIter++) {
		o<<"preOrderDF::"<<(*preNodeIter).getLabel()<<endl;
	}

	tree<KBNode>::breadth_first_queued_iterator bfNodeIter;
	for(bfNodeIter=tr.begin_breadth_first(); bfNodeIter!=tr.end_breadth_first(); bfNodeIter++) {
		o<<"breadthFirst::"<<(*bfNodeIter).getLabel()<<endl;
	}
}




