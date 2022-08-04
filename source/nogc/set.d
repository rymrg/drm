module drm.nogc.set;
import std.algorithm;
import std.range;
import drm.nogc.rbtree;

/**
  Set implemention
  **/
struct Set(T){
	private Tree!T set;

	/// Construct a set
	this(T[] ts...){
		this.add(ts);
	}

	/// Ditto
	this (Range) (Range r) if (isInputRange!Range){
		this.add(r);
	}

	/// Copy constructor
	/// Set preserves struct semantics
	this(ref return scope typeof(this) rhs){
		this.set = rhs.set;
	}

	//// Add item to set
	/// Returns:
	///	If the item already existed in the set
	bool add(T t) @nogc{
		return set.add(t) == 0;
	}
	/// Ditto
	void add(T[] ts...){
		ts.each!(t=>add(t));
	}
	/// Ditto
	void add(Range)(Range r) if (isInputRange!Range){
		r.each!(t=>add(t));
	}

	/** Remove an item from the set
	  Params:
	  t = item to remove
	  Returns:
	  	Whether the item existed in the set
		**/
	bool remove(T t){
		//if (t !in set) return false;
		return set.remove(t);
		//return true;
	}

	/// Returns: the amount of elements in the set
	size_t length() const{
		return set.length;
	}
	/// Returns: Wether the set is empty or not
	bool empty() const{
		return (length == 0);
	}

	/// Remove all items from the set
	void clear(){
		set.clear;
	}

	/**
	  Support &= (intersect)
	  	|= Union
		-= Set difference
		**/
	ref auto opOpAssign(string op)(Set!T rhs){
		static if (op == "&"){
			this = (this & rhs);
			return this;
		} else static if (op == "|"){
			rhs[].each!(t=>add(t));
			return this;
		} else static if (op == "-"){
			rhs[].each!(t=>remove(t));
			return this;
		} else static assert(0, "Operator "~op~" not implemented");
    }
	/**
	  ~= - add item to set
	  -= - remove item from set
	  **/
	ref auto opOpAssign(string op)(T lhs){
		static if (op == "~"){
			add(lhs);
			return this;
		} else static if (op == "-"){
			remove(lhs);
			return this;
		} else static assert(0, "Operator "~op~" not implemented");
    }


	bool opEquals()(in Set!T rhs) const {
		return set == rhs.set;
    }
	size_t toHash() const{
		return typeid(set).getHash(&set);
	}

	/**
	  Support & (intersect)
	  	| Union
		- Set difference
		**/
	typeof(this) opBinary(string op)(typeof(this) rhs) {
		static if (op == "&"){
			return typeof(this)(setIntersection(set[], rhs.set[]));
		} else static if (op == "|"){
			return typeof(this)(merge(set[], rhs.set[]));
		} else static if (op == "-"){
			return typeof(this)(setDifference(set[], rhs.set[]));
		} else static assert(0, "Operator "~op~" not implemented");
	}

	/// Allows checking if an item is in the set
	bool opBinaryRight(string op)(T lhs) {
		static if (op == "in") return set.contains(lhs);
		else static assert(0, "Operator "~op~" not implemented");
	}

	/// Check wehther an item is in the set with opIndex
	bool opIndex(T t){
		return (t in this);
	}

	/// opSlice for iterating over all items in range
	auto opSlice() {
		return set[];
	}

	/// Duplicate the set
	auto dup() {
		typeof(this) s;
		s.set = set;
		return s;
	}
}

@nogc unittest{
	import std.container.array;
	auto set = Set!int(1,2,3);
	auto set2 = Set!int(Array!int(1,2,3).opSlice);
	assert(1 in set);
	assert(set == set2);
	assert(set.add(1) == true);
	assert(set == set2);
	assert(4 !in set);
	assert(set.add(4) == false);
	assert(4 in set);
	assert(set != set2);
	assert(set.remove(4) == true);
	assert(set == set2);
	assert(set.remove(4) == false);
	assert(4 !in set);
	assert(set == set2);
	assert(1 in set);
	auto set3 = set.dup;
	assert(set == set3);
	set3.remove(1);
	assert(set != set3);
	assert(set - set3 == Set!int(1));
	assert((set -= set - set3) == Set!int(2,3));
	assert((set & Set!int(2,3,4)) == Set!int(2,3));
	assert((set &= Set!int(2,3,4)) == Set!int(2,3));
	assert((set | Set!int(2,4)) == Set!int(2,3,4));
	assert((set |= Set!int(2,4)) == Set!int(2,3,4));
	auto set4 =  Set!int();
	foreach(t; set){
		set4.add(t);
	}
	set2.clear();
	assert(set2.empty);
}
@nogc unittest{
	auto set = Set!int(1,2,3);
	auto set2 = set;
	assert(set2 == set);
	set.remove(2);
	assert(set2 != set);
	set.add(2);
	assert(set2 == set);
}
