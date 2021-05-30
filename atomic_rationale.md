# Atomic

## Rationale:

C++ has an atomic struct std::atomic<T>.
Implementing such a struct in D would make it easier to work with atomics.
The proposed struct gives easy access to explicit weaker access and automatic Sequential Consist (SC) for implicit access.
This means, that the programmer can easily use atomics variables without explicitly calling things like `atomicOp`.

In addition, it provides easier translation from C/C++ to D, as the automatic SC semantics are persevered.
Note, the translation isn't going to be 1:1 from C.
Since C does not allow easy usage of initialization. 
This behavior caused problems in C++ and C++ is going to break apart from C in this case[1].


## Memory Order
`MemoryOrder.raw` should be renamed to `MemoryOrder.rlx`. 
Since `raw` makes it sound like it is a non atomic access while in truth it is an atomic access that provides no synchronization (by itself). 
This access is called relaxed in C/C++.
Given that we use the names `acq` and `rel` in D instead of `acquire` and `release`, I propose `rlx` instead of `relaxed`.


[1] http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p0883r2.pdf
