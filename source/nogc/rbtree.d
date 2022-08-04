module drm.nogc.rbtree;
import std.experimental.allocator.mallocator : Mallocator;
import std.experimental.allocator : make, dispose;
import std.functional : binaryFun;
import std.algorithm;
import std.range;
import core.lifetime : move;

struct Tree(T, Allocator = Mallocator, bool allowDuplicates = false,
		alias less = "a < b") {
	//align(1):
	private enum Color : ubyte {
		Black, Red,
	}
	private struct Node{
		//align(1):
		import std.bitmanip : bitfields;
		Node* p, left, right;
		T payload;
		mixin(bitfields!(
					Color, "color",    1,
					ubyte, "initialized",    1,
					ulong, "alignment", 6));
	}

	static bool isNil(in Node* ptr) {
		return ptr is null || ptr == &nil || !ptr.initialized;
	}

	private static Node nil;
	private Node* root;
	alias _less = binaryFun!less;
	private size_t _length;

	/// Remove all items from the Tree and free memory
	void clear(){
		clearSubTree(root);
		root = null;
		nil.p = &nil;
		_length = 0;
	}

	private void clearSubTree(Node* x){
		if (isNil(x)) return;
		clearSubTree(x.left);
		clearSubTree(x.right);
		destroy!false(x.payload);
		dispose(Allocator.instance, x);
	}

	this(ref return scope typeof(this) rhs){
		root = cloneTree(rhs.root);
		_length = rhs._length;
	}


	void opAssign(ref typeof(this) rhs) {
		clear();
		root = cloneTree(rhs.root);
		_length = rhs._length;
	}
	void opAssign(typeof(this) rhs) {
		clear();
		moveEmplace(rhs.root, root);
		_length = rhs._length;
		rhs._length = 0;
	}

	private Node* cloneTree(scope Node* rhs) nothrow{
		if (isNil(rhs)) return &nil;
		auto z = make!Node(Allocator.instance);
		z.color = rhs.color;
		z.initialized = 1;
		z.payload = rhs.payload;
		z.left = cloneTree(rhs.left);
		z.right = cloneTree(rhs.right);
		if (!isNil(z.left)) z.left.p = z;
		if (!isNil(z.right)) z.right.p = z;
		return z;
	}

	~this(){
		clear();
	}

    bool opEquals()(auto ref const typeof(this) rhs) const {
		return equal(this[], rhs[]);
	}

	private void leftRotate(Node* x) in (!isNil(x.right)){
		//assert(!isNil(x.right), "Trying to rotate when right child is nil");
		auto y = x.right;
		x.right = y.left;
		if (!isNil(y.left))
			y.left.p = x;
		y.p = x.p;
		if (isNil(x.p))
			root = y;
		else if (x.p.left == x)
			x.p.left = y;
		else 
			x.p.right = y;
		y.left = x;
		x.p = y;
	}
	private void rightRotate(Node* y) in (!isNil(y.left)){
		//assert(!isNil(y.left), "Trying to rotate when right child is nil");
		auto x = y.left;
		y.left = x.right;
		if (!isNil(x.right))
			x.right.p = y;
		x.p = y.p;
		if (isNil(y.p))
			root = x;
		else if (y.p.left == y)
			y.p.left = x;
		else 
			y.p.right = x;
		x.right = y;
		y.p = x;
	}

	bool contains(T value){
		return !isNil(getNode(value));
	}

	/// Allows checking if an item is in the set
	ref auto opBinaryRight(string op)(T lhs) const {
		static if (op == "in") {
			auto n = getNode(lhs);
			if (isNil(n)) return null;
			return *n;
		}
		else static assert(0, "Operator "~op~" not implemented");
	}
	

	private Node* getNode(T value){
		auto x = root;
		while (!isNil(x)){
			if (_less(value, x.payload)){
				x = x.left;
			} else if (_less(x.payload, value)){
				x = x.right;
			} else {
				return x;
			}
		}
		return &nil;
	}
	package(drm.nogc){
		T* getNodePointer(T value) {
			auto x = getNode(value);
			if (isNil(x)) return null;
			return &x.payload;
		}
	}

	size_t insert(T value, bool overwrite = false) @nogc{
		auto y = &nil;
		auto x = root;
		while (!isNil(x)){
			y = x;
			static if (!allowDuplicates){
				if (_less(value, x.payload)){
					x = x.left;
				} else if (_less(x.payload, value)){
					x = x.right;
				} else {
					// Item is already in tree
					if (overwrite) {
						x.payload = value;
						return 1;
					}
					return 0;
				}
			} else {
				if (_less(value < x.payload)){
					x = x.left;
				} else if (overwrite && !_less(x.payload, value)){
					x.payload = value;
					return 1;
				} else {
					x = x.right;
				}
			}
		}
		++_length;
		auto z = make!Node(Allocator.instance);
		z.color = Color.Red;
		z.initialized = 1;
		z.payload = value;
		z.p = y;
		z.left = &nil;
		z.right = &nil;

		if (isNil(y))
			root = z;
		else if (_less(z.payload, y.payload))
			y.left = z;
		else
			y.right = z;

		insertFixup(z);
		return 1;
	}
	
	/// Ditto
	void insertMulty(T[] ts...){
		ts.each!(t=>insert(t));
	}
	/// Ditto
	void insert(Range)(Range r, bool overwrite = false) if (isInputRange!Range){
		r.each!(t=>insert(t, overwrite));
	}

	alias add = insert;

	private void insertFixup(Node* z){
		while (!isNil(z.p) && !isNil(z.p.p) && z.p.color == Color.Red){
			if (z.p == z.p.p.left){
				auto y = z.p.p.right;
				if (y.color == Color.Red){
					z.p.color = Color.Black;
					y.color = Color.Black;
					z.p.p.color = Color.Red;
					z = z.p.p;
				} else {
					if (z == z.p.right){
						z = z.p;
						leftRotate(z);
					}
					z.p.color = Color.Black;
					z.p.p.color = Color.Red;
					rightRotate(z.p.p);
				}
			} else {
				// Same mirror
				auto y = z.p.p.left;
				if (y.color == Color.Red){
					z.p.color = Color.Black;
					y.color = Color.Black;
					z.p.p.color = Color.Red;
					z = z.p.p;
				} else {
					if (z == z.p.left){
						z = z.p;
						rightRotate(z);
					}
					z.p.color = Color.Black;
					z.p.p.color = Color.Red;
					leftRotate(z.p.p);
				}
			}
			root.color = Color.Black;
		}
	}

	private void transplant(Node* u, Node* v) in (!isNil(u)) {
		if (isNil(u.p))
			root = v;
		else if (u == u.p.left)
			u.p.left = v;
		else
			u.p.right = v;
		v.p = u.p;
	}

	private Node* treeMinimum(Node* x) {
		if (isNil(x))
			return x;
		while (!isNil(x.left))
			x = x.left;
		return x;
	}

	bool remove(T value){
		auto z = getNode(value);
		if (isNil(z)) return false;

		auto y = z;
		auto yOriginalColor = y.color;
		Node* x;
		if (isNil(z.left)){
			x = z.right;
			transplant(z, z.right);
		} else if (isNil(z.right)){
			x = z.left;
			transplant(z, z.left);
		} else {
			y = treeMinimum(z.right);
			yOriginalColor = y.color;
			x = y.right;
			if (y.p == z)
				x.p = y;
			else {
				transplant(y, y.right);
				y.right = z.right;
				y.right.p = y;
			}
			transplant(z, y);
			y.left = z.left;
			y.left.p = y;
			y.color = z.color;
		}
		if (yOriginalColor == Color.Black)
			deleteFixup(x);
		if (!isNil(z)) {
			nil.p = &nil;
			destroy!false(z.payload);
			dispose(Allocator.instance, z);
		}
		--_length;
		return true;
	}

	/// Ditto
	void remove(T[] ts...){
		ts.each!(t=>remove(t));
	}
	/// Ditto
	void remove(Range)(Range r) if (isInputRange!Range){
		r.each!(t=>remove(t));
	}

	private void deleteFixup(Node* x){
		while (x != root && x.color == Color.Black){
			if (x == x.p.left){
				auto w = x.p.right;
				if (w.color == Color.Red){
					w.color = Color.Black;
					x.p.color = Color.Red;
					leftRotate(x.p);
					w = x.p.right;
				}
				if (w.left.color == Color.Black && w.right.color == Color.Black){
					w.color = Color.Red;
					x = x.p;
				} else {
					if (w.right.color == Color.Black) {
						w.left.color = Color.Black;
						w.color = Color.Red;
						rightRotate(w);
						w = x.p.right;
					}
					w.color = x.p.color;
					x.p.color = Color.Black;
					w.right.color = Color.Black;
					leftRotate(x.p);
					x = root;
				}
			} else {
				// Mirror
				auto w = x.p.left;
				if (w.color == Color.Red){
					w.color = Color.Black;
					x.p.color = Color.Red;
					rightRotate(x.p);
					w = x.p.left;
				}
				if (w.right.color == Color.Black && w.left.color == Color.Black){
					w.color = Color.Red;
					x = x.p;
				} else {
					if (w.left.color == Color.Black) {
						w.right.color = Color.Black;
						w.color = Color.Red;
						leftRotate(w);
						w = x.p.left;
					}
					w.color = x.p.color;
					x.p.color = Color.Black;
					w.left.color = Color.Black;
					rightRotate(x.p);
					x = root;
				}
			}
		}
		x.color = Color.Black;
	}

	size_t length() const {
		return _length;
	}

	bool empty() const {
		return _length == 0;
	}

	auto opSlice(this This)() inout @trusted @nogc {
		return Range!(This)(cast(const(Node)*) root);
	}

	static struct Range(ThisT){

		T front() const @property @nogc {
			return cast(typeof(return)) current.payload;
		}

		bool empty() const nothrow @nogc @safe @property {
			return isNil(current);
		}

		void popFront() in (!empty) {
			if (!isNil(current.right)){
				current = current.right;
				currentToLeftmost;
				return;
			}
			if (isNil(current.p)){
				current = &nil;
				return;
			}
			if (current == current.p.left){
				current = current.p;
				return;
			}
			do {
				current = current.p;
			} while (!isNil(current.p) && current.p.right == current);
			current = current.p;
		}

		private:

		void currentToLeftmost() @nogc {
			if (isNil(current))
				return;
			while (!isNil(current.left))
				current = current.left;
		}

		this(inout(Node)* n) @nogc
		{
			current = n;
			currentToLeftmost();
		}

		const(Node)* current;
	}

}

@nogc unittest{
	assert(Tree!int.isNil(&Tree!int.nil));
	Tree!int a;
	assert(a.length == 0);
	assert(a.isNil(a.root));
	assert(a.insert(5) == 1);
	assert(!a.isNil(a.root));
	assert(a.length == 1);
	assert(a.insert(5) == 0);
	assert(a.length == 1);
	assert(a.insert(6) == 1);
	assert(a.length == 2);
}

@nogc unittest{
	Tree!int a;
	a.insert(20.iota.map!(x=>x+1));
	foreach (i; 1..21){
		assert(a.contains(i));
	}
	foreach (i; 21..41){
		assert(!a.contains(i));
	}
	assert(!a.contains(0));
}

unittest{
	Tree!int a;
	a.insert(20.iota);
	assert(equal(a[], 20.iota));
}
unittest{
	Tree!int a;
	a.insert(20.iota);
	assert(equal(a[], 20.iota));
	a.remove(20.iota);
	assert(a.length == 0);
	assert(a.empty);
	assert(a[].empty);
}
unittest{
	{
		Tree!int a;
		a.insert(20.iota);
		assert(equal(a[], 20.iota));
		a.remove(10.iota);
		assert(equal(a[], 10.iota.map!(x=>x+10)));
		assert(a.length == 10);
	}
}
unittest{
	{
		Tree!int a;
		a.insert(20.iota);
		auto b = a;
		assert(a == b);
		assert(b.length == 20);
		b.clear();
		assert(a != b);
		assert(a.length == 20);
		assert(b.length == 0);
		b = a;
		assert(a == b);
		b.clear();
		assert(a != b);
		assert(a.length == 20);
		assert(b.length == 0);
	}
}
unittest{
		Tree!int a,b;
		a.insert(20.iota);
		b.insert(20.iota.map!(x=>x+1));
		assert(a != b);
}
