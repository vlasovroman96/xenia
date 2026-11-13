# Overview of Xenia Server Source Code Structure

At that moment see CODE_OVERVIEW_BASE.md 

## Structure of code

1. Every struct must be defined in its own module.
   **1 struct - 1 module**.

	**NO**
   ```d
	module veryBigModule;

	//Foo stuffs
	struct Foo;

	//Boo stuffs
	struct Boo;

	struct IDKWIMDH;
   ```

   **YES**
   ```d
	module foo;

	//Foo stuffs
	struct Foo;
   ```

    ```d
	module boo;

	//Boo stuffs
	struct Boo;
   ```

    ```d
	module idkwimdh;

	struct IDKWIMDH;
   ```

2. Avoid as possible secondary definitions/aliasing for symbols.
   Exceptions: 
   * X protocol definings, etc.
   * Functions/delegates named aliases;
   * Very long names wrapper (inside module only)

	**NO**
	```d
	alias MAXINT = INT_MAX;

	auto foo(MAXINT a);
	```

	**YES**
	```d
	module foo;

	auto foo(INT_MAX a);
	```

3. All modules must be imported **privately**

	**NO**
	```d
	public import foo;
	import boo;
	```

	**YES**
	```d
	import foo;
	import boo;
	```

4. If >50 % of **public interface** of module need symbol from other module, 
   second module **can be** imported as **public** into the first module.

	**CAN BE**
	```d
	module foo;

	struct Foo;
	```

	```d
	module Boo;

	import foo; // Imported privetely

	struct Boo {
		void a(Foo);
		Foo b();
		Foo c(Foo);
		uint d();
		void e(uint)
	}
	```

	By 3 rules must be:

	```d
	module mod;

	import boo;	
	import foo; //In most case must be imported together 

	Boo c;
	```

	**But by 4 rule it can be:**

	```d
	module Boo;

	//3 of 5 methods of public interface needs `foo`
	//import it publicly
	public import foo; 

	struct Boo {
		void a(foo);
		foo b();
		foo c(foo);
		uint d();
		void e(uint)
	}
	```

	```d
	module mod;

	import boo;	
	//Not need import foo

	Boo c;
	```