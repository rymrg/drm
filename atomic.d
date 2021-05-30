module drm.atomic;
public import core.atomic : MemoryOrder;

/// Atomic data like std::atomic
struct Atomic(T) if (__traits(isIntegral, T)){
	import core.atomic : atomicLoad, atomicStore, atomicExchange, atomicFetchAdd,
		   atomicFetchSub, atomicCas = cas, atomicCasWeak = casWeak, atomicOp;

    private shared T val;

	/// Constructor
	this(T init){
		val.atomicStore(init);
	}

    private shared(T)* ptr() shared {
		return &val;
	}

	/// Load the value from the atomic location with SC access
	alias load this;

	/// ditto
    T load(MemoryOrder mo = MemoryOrder.seq)() shared const {
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
    //bool casWeak(MemoryOrder mo = MemoryOrder.seq, MemoryOrder fmo = MemoryOrder.seq)(T oldVal, T newVal) shared {
    //    return atomicCasWeak!(mo, fmo)(ptr, oldVal, newVal);
    //}
    
	/// Op assign with SC semantics
    T opOpAssign(string op)(T rhs) shared {
        return val.atomicOp!(op ~ `=`)(rhs);
    }
    
	/// Implicit conversion to FADD and FSUB
    T opUnary(string op)() shared
    {
        static if (op == `++`)
            return val.atomicOp!`+=`(1);
        static if (op == `--`)
            return val.atomicOp!`-=`(1);
    }
}

@safe unittest{
	shared Atomic!int a;
	assert(a == 0);
	assert(a.load == 0);
	assert(a.fadd!(MemoryOrder.raw)(5) == 0);
	assert(a.load!(MemoryOrder.acq) == 5);
	//assert(!a.casWeak(4,5));
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
