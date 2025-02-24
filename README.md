# Soro

### A programming language inspired by Nigerian Pidgin English

Soro (meaning "speak" in Yoruba) is an experimental programming language that blends Pidgin English syntax with modern programming concepts. It’s designed to be both simple and familiar, especially for those who are familiar with nigerian pidgin english.

Soro is powered by its own tokenizer, parser, and compiler that generates custom bytecode to run on its virtual machine. 

### Current Milestone

Make Soro capable of interpreting and evaluating recursive FizzBuzz.

Here’s what the language should be able to handle soon:

```
// Recursive FizzBuzz in Soro
oya fizzbuzz(num, limit) {
    abi (num > limit) {
        comot; // Base case: stop recursion
    }

    abi (num % 3 == 0 and num % 5 == 0) {
        yarn("FizzBuzz");
        comot fizzbuzz(num + 1, limit); 
    }

    abi (num % 3 == 0) {
        yarn("Fizz");
        comot fizzbuzz(num + 1, limit);
    }

    abi (num % 5 == 0) {
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

## Why Soro?

Soro hopes to create an easier way for people in Nigeria to begin coding, even for those who may not be well-versed in English. By using Nigerian Pidgin as its foundation, Soro lowers the barrier to entry for programming, making it a more inclusive and accessible experience.
