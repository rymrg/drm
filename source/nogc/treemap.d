module drm.nogc.treemap;
import drm.nogc.rbtree;
import std.experimental.allocator.mallocator : Mallocator;
import std.experimental.allocator : make, dispose;
import std.functional : binaryFun;
import std.algorithm;
import std.range;

struct TreeMap(K, V, Allocator = Mallocator, bool allowDuplicates = false,
		alias less = "a < b") {
	align(1):

	alias _less = binaryFun!less;
	private struct Payload{
		align(1):
		K key;
		V value;

		int opCmp(ref const typeof(this) rhs) const { 
			if (_less(key, rhs.key)) return -1;
			if (_less(rhs.key, key)) return 1;
			return 0;
		}

		this (K _key, V _value){
			key = _key;
			value = _value;
		}
		this(ref return scope typeof(this) src) {
			foreach (i, ref field; src.tupleof)
				this.tupleof[i] = field;
		}
	}

	private Tree!(Payload, Allocator, allowDuplicates) tree;

	/// Remove all items from the TreeMap and free memory
	void clear(){
		tree.clear();
	}

	this(ref return scope typeof(this) rhs){
		tree = rhs.tree;
	}

	void opAssign(typeof(this) rhs) {
		tree = rhs.tree;
	}

    bool opEquals()(auto ref const typeof(this) rhs) const {
		return equal(this[], rhs[]);
	}

	/// Allows checking if an item is in the set
	ref auto opBinaryRight(string op)(K lhs) {
		static if (op == "in") {
			auto n = tree.getNodePointer(Payload(lhs, V.init));
			if (!n) return null;
			return &n.value;
		}
		else static assert(0, "Operator "~op~" not implemented");
	}

	size_t insert(K key, V value, bool overwrite = false){
		return tree.insert(Payload(key, value), overwrite);
	}
	
	/// Ditto
	void insert(Range)(Range r, bool overwrite = false) if (isInputRange!Range){
		r.each!(t=>insert(t[0], t[1], overwrite));
	}

	alias add = insert;


	bool remove(K key){
		return tree.remove(Payload(key, V.init));
	}

	/// Ditto
	void remove(K[] ts...){
		ts.each!(t=>remove(t));
	}
	/// Ditto
	void remove(Range)(Range r) if (isInputRange!Range){
		r.each!(t=>remove(t));
	}

	size_t length() const {
		return tree.length;
	}

	bool empty() const {
		return tree.empty;
	}

	auto opSlice() {
		return byKeyValue;
	}

	auto byKeyValue() {
		return tree[];
	}
	auto byKey(){
		return tree[].map!(t=>t.key);
	}
	auto byValue(){
		return tree[].map!(t=>t.value);
	}

	ref auto opIndex(K k){
		auto t = k in this;
		assert(t != null);
		return *t;
	}

	ref auto opIndexAssign(V v, K k){
		// TODO: Make it only a single pass
		tree.insert(Payload(k, v), true);
		auto t = k in this;
		assert(t != null);
		return *t;
	}

	ref auto require(K k, V v){
		// TODO: Make it only a single pass
		auto t = k in this;
		if (t != null) return *t;
		return this[k] = v;
	}

}

@nogc unittest{
	TreeMap!(int,int) a;
	assert(a.empty);
	assert(a.length == 0);
	assert(a.remove(3) == false);
	assert(a.insert(3, 2) == true);
	assert(a.length == 1);
	assert(a.insert(3, 2) == false);
	assert(a.length == 1);
	assert(a.remove(3) == true);
	assert(a.empty);
}

@nogc unittest{
	TreeMap!(int,int) a;
	assert(a.insert(3, 2) == true);
	assert(a.insert(3, 1) == false);
	assert(a.length == 1);
	assert(a.insert(2, 2) == true);
	assert(a.length == 2);
	assert(2 in a);
	assert(3 in a);
	assert(4 !in a);
}

@nogc unittest{
	TreeMap!(int,int) a;
	assert(a.insert(3, 1) == true);
	assert(a.insert(2, 2) == true);
	assert(a.insert(1, 3) == true);
	if (auto v = 3 in a)
		assert(*v == 1);
	if (auto v = 1 in a)
		assert(*v == 3);
	if (auto v = 1 in a)
		*v = 1;
	if (auto v = 1 in a)
		assert(*v == 1);
}

@nogc unittest{
	TreeMap!(int, Tree!int) a;
}

unittest{
	Tree!int a,b;
	a.insert(20.iota, 1);
	b.insert(20.iota.map!(x=>x+1));
	assert(a != b);
}
@nogc unittest{
	TreeMap!(int,int) a;
	a.insert(zip(20.iota, 1.repeat));
	foreach(int key; a.byKey())
		assert(*(key in a) == 1);
}
@nogc unittest{
	TreeMap!(int,int) a;
	a.insert(zip(20.iota, 20.iota.map!(x=>x+1)));
	foreach(int key; a.byKey()){
		assert(*(key in a) == key+1);
	}
}
@nogc unittest{
	TreeMap!(int,int) a;
	foreach(int key; 20.iota){
		a[key] = key+1;
	}
	foreach(int key; a.byKey()){
		assert(a[key] == key+1);
	}
	foreach(int key; a.byKey()){
		assert(*(key in a) == key+1);
	}
}

@nogc unittest{
	TreeMap!(int,int) a;
	foreach(int key; 20.iota){
		assert(a.require(key, 0) == 0);
	}
	foreach(int key; 20.iota){
		assert(a[key] == 0);
	}
	foreach(int key; 20.iota){
		a.require(key, 1);
	}
	foreach(int key; 20.iota){
		assert(a[key] == 0);
	}
}

unittest{
	TreeMap!(const(void)*, int) a;
}
