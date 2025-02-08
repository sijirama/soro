# Soro 

insane work in progress
current goal, to interprete and evaluate this

```
// Recursive FizzBuzz in Soro
oya fizzbuzz(num, limit) {
    if (num > limit) {
        comot; // Base case: stop recursion
    }

    if (num % 3 == 0 and num % 5 == 0) {
        yarn("FizzBuzz");
        comot fizzbuzz(num + 1, limit); 
    }

    if (num % 3 == 0) {
        yarn("Fizz");
        comot fizzbuzz(num + 1, limit);
    }

    if (num % 5 == 0) {
        yarn("Buzz");
        comot fizzbuzz(num + 1, limit); 
    }

    yarn(num);
    comot fizzbuzz(num + 1, limit); 
}

// Start FizzBuzz from 1 to limit
oya start() {
    abeg limit = 15;
    fizzbuzz(1, limit);
}

start();
```


