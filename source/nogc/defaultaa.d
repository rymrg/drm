module drm.nogc.defaultaa;
import std.algorithm;
import std.range;
import drm.nogc.treemap;

/**
  Set implemention
  **/
struct DefaultAA(K, V){
	private TreeMap!(K,V) aa;
	private V vInit = V.init;
	alias aa this;

	this(V init){
		vInit = init;
	}

	private V getCopy()() if (__traits(compiles, vInit.dup)){
		return vInit.dup;
	}
	private V getCopy()() if (!__traits(compiles, vInit.dup)){
		return vInit;
	}


	bool opEquals()(in Set!T rhs) const {
		return aa == rhs.aa;
    }
	size_t toHash() const{
		return typeid(aa).getHash(&aa);
	}

	/// Take the item or create a new one
	ref auto opIndex(K k){
		return aa.require(k, getCopy);
	}

	/// Duplicate the aa
	auto dup() {
		typeof(this) s;
		s.aa = aa;
		s.vInit = vInit;
		return s;
	}

	/// Remove item from aa
	auto remove(K k){
		return aa.remove(k);
	}
}

@nogc
unittest{
	DefaultAA!(int,int) aa = (5);
	assert(aa.length == 0);
	assert(aa[5] == 5);
	assert(aa.length == 1);
	aa.remove(5);
	assert(aa.length == 0);
}
unittest{
	DefaultAA!(string,int) aa = (5);
	assert(aa.length == 0);
	assert(aa["foo"] == 5);
	assert(aa.length == 1);
	aa.remove("foo");
	assert(aa.length == 0);
}

