# Atomic

Implementing `core.atomic.Atomic!T` like C++ `std::atomic<T>`.

## Rationale

Currently in order to use atomic access to a variable in D, one has to always explicitly annotate his access to the variable.
Otherwise, the programmer might insert a non-atomic access by mistake.
Introducing an unwanted behavior (which we still need to define).
Using shared slightly mitigates this problem, but is inconvenient and cumbersome to use.

In C and C++ where the memory model originates, the default access to the variable without annotation does the right thing[1,2], that is to say all accesses by default exhibit sequential consistency.
The programmer can rely on sequential consistency from std::atomic without manual annotation.

In addition, C++ has an atomic struct `std::atomic<T>`.
This struct makes it easier to perform atomic access with weaker access.
Preventing the need for calling  a function with a pointer to the atomic location.

The proposal implements a similar struct for D.
This allows the program to do the "right thing" when accessing atomic location.
It also provides easier usage for the sequentially consistent access, by implementing opAssign and opUnary.
In addition, it provides an easy access to the weaker atomic access providing functions to the struct and prevents easy misuse of the atomic.

By implementing this struct, we gain easier translation from C/C++ to D as the automatic sequentially consistent semantics are preserved.
Note, the translation isn't going to be 1:1 from C.
Since C does not allow easy usage of initialization. 
This behavior caused problems in C++ and C++ is going to break apart from C in this case[3].

It also worth noting that other languages (such as Rust[4]) implement a similar struct.


## Memory Order
`MemoryOrder.raw` should be renamed to `MemoryOrder.rlx`. 
Since `raw` makes it sound like it is a non atomic access while in truth it is an atomic access that provides no synchronization (by itself). 
This access is called relaxed in C/C++[5].
Hence making transition from C/C++ easier.
Given that we use the names `acq` and `rel` in D instead of `acquire` and `release`, I propose `rlx` instead of `relaxed`.
Rust also calls this kind of access `Relaxed`[6].


[1] https://en.cppreference.com/w/c/atomic
  
[2] https://en.cppreference.com/w/cpp/atomic
  
[3] http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p0883r2.pdf
  
[4] https://doc.rust-lang.org/std/sync/atomic/index.html
  
[5] https://en.cppreference.com/w/cpp/atomic/memory_order
  
[6] https://doc.rust-lang.org/std/sync/atomic/enum.Ordering.html
