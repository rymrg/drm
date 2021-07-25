module drm.atomic;
public import core.atomic : MemoryOrder;

/// Atomic data like std::atomic
struct Atomic(T) if (__traits(isIntegral, T) || isPointer!T){
	import core.atomic : atomicLoad, atomicStore, atomicExchange, atomicFetchAdd,
		   atomicFetchSub, atomicCas = cas, atomicCasWeak = casWeak, atomicOp;

    private shared T val;

	/// Constructor
	this(T init) shared{
		val.atomicStore(init);
	}

    private shared(T)* ptr() shared {
		return &val;
	}

	/// Load the value from the atomic location with SC access
	alias load this;

	/// ditto
    T load(MemoryOrder mo = MemoryOrder.seq)() shared {
        return val.atomicLoad!mo;
    }

	/// Store the value to the atomic location
    void store(MemoryOrder mo = MemoryOrder.seq)(T newVal) shared {
        return val.atomicStore!mo(newVal);
    }

	/// Store using SC access
	alias opAssign = store;


	/// Atomically increment the value
    T fadd(MemoryOrder mo = MemoryOrder.seq)(T mod) shared {
        return atomicFetchAdd(val, mod);
    }

	/// Atomically decrement the value
    T fsub(MemoryOrder mo = MemoryOrder.seq)(T mod) shared {
        return atomicFetchSub(val, mod);
    }
    
	/// Atomically swap the value
    T exchange(MemoryOrder mo = MemoryOrder.seq)(T desired) shared {
        return atomicExchange(&val, desired);
    }

	/// Compare and swap
    bool cas(MemoryOrder mo = MemoryOrder.seq, MemoryOrder fmo = MemoryOrder.seq)(T oldVal, T newVal) shared {
        return atomicCas!(mo, fmo)(ptr, oldVal, newVal);
    }

	/// ditto
    bool casWeak(MemoryOrder mo = MemoryOrder.seq, MemoryOrder fmo = MemoryOrder.seq)(T oldVal, T newVal) shared {
        return atomicCasWeak!(mo, fmo)(ptr, oldVal, newVal);
    }
    
	/// Op assign with SC semantics
    T opOpAssign(string op)(T rhs) shared {
        return val.atomicOp!(op ~ `=`)(rhs);
    }
    
	/// Implicit conversion to FADD and FSUB
    T opUnary(string op)() shared if (op == `++`) {
            return val.atomicOp!`+=`(1);
	}

    T opUnary(string op)() shared if (op == `--`) {
            return val.atomicOp!`-=`(1);
    }

    auto ref opUnary(string op)() shared if (op == `*`) {
            return *(load);
    }
}

@safe unittest{
	shared Atomic!int a;
	assert(a == 0);
	assert(a.load == 0);
	assert(a.fadd!(MemoryOrder.raw)(5) == 0);
	assert(a.load!(MemoryOrder.acq) == 5);
	assert(!a.casWeak(4,5));
	assert(!a.cas(4,5));
	assert(a.cas!(MemoryOrder.rel, MemoryOrder.acq)(5,4));
	assert(a.fsub!(MemoryOrder.acq_rel)(2) == 4);
	assert(a.exchange!(MemoryOrder.acq_rel)(3) == 2);
	assert(a.load!(MemoryOrder.raw) == 3);
	a.store!(MemoryOrder.rel)(7);
	assert(a.load == 7);
	a = 32;
	assert(a == 32);
	a+=5;
	assert(a == 37);
	assert(a++ == 37);
	assert(a == 38);
}

// static array of shared atomics
@safe unittest{
	static shared(Atomic!int)[5] arr;
	arr[4] = 4;
	assert(arr[4].load == 4);
}

unittest{
	import core.thread : Thread;
	shared(Atomic!int)[2] arr;

	void reltest() @safe{
		arr[0].store!(MemoryOrder.rel)(1);
		arr[1].store!(MemoryOrder.rel)(1);
	}
	void acqtest() @safe{
		while (arr[1].load!(MemoryOrder.acq) != 1){}
		assert(arr[0].load!(MemoryOrder.acq) == 1);
	}

	auto t1 = new Thread(&acqtest);
	auto t2 = new Thread(&reltest);
	t2.start;
	t1.start;
	t2.join;
	t1.join;
}

@safe unittest{
	shared Atomic!(shared(int)) a = 5;
	assert(a.load == shared(int)(5));
	a = 2;
	assert(a == 2);
}
@safe unittest{
	shared Atomic!(shared(int)*) ptr = new shared(int);
	*ptr.load!(MemoryOrder.raw)() = 5;
	assert(*ptr.load == 5);
	*(ptr.load) = 42;
	assert(*ptr.load == 42);
}
@safe unittest{
	shared Atomic!(shared(int)*) ptr = new shared(int);
	*ptr = 5;
	assert(*ptr == 5);
	*ptr = 42;
	assert(*ptr == 42);
}

unittest{
	//shared Atomic!(shared(Atomic!(int))*) ptr = new shared(Atomic!int);
}


private enum bool isAggregateType(T) = is(T == struct) || is(T == union) ||
                               is(T == class) || is(T == interface);
private enum bool isPointer(T) = is(T == U*, U) && !isAggregateType!T;
