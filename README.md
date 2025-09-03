# sum_of_consecutive_squares

[![Package Version](https://img.shields.io/hexpm/v/sum_of_consecutive_squares)](https://hex.pm/packages/sum_of_consecutive_squares)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/sum_of_consecutive_squares/)

```sh
gleam add sum_of_consecutive_squares@1
```

## Usage 

```sh
./shreyas <N> <k> [max_workers]

        OR

gleam run <N> <k> [max_workers]   # Run the project
```
- N is the end of the Domain(the maximum number in the calculation space)
- k grouping of numbers per calculation for a potential solution
- Optional max_workers used for benchmarking puprposes

## Benchmarking and Calculations

### Best Size of Work Unit
- Upon running the "benchmarking.sh" script that runs multiple number of actors
  the size that showed best performance over 10 runs was showing with around 100 - 200 workers

1. Best Work Unit Size: 1/100 of total range: for 100_000_000 is **1000000 Work Units**

2. Solution for ```gleam run 1000000 4``` **does not exist** 

3. the ratio of CPU_TIME:REAL_TIME was 0.1666/0.02644 = 6.3106
    - for reference with 1 worker the ratio was 1.7 (due to worker cleanup overhead)
    - ratios for bigger solutions of 100000000 2 for example which has solutions gave us a ratio of 5-6
    which is closer to what is to be expected

4. Largest problem solved was  
```
shreyas@Shreyass-MacBook-Pro sum-of-consecutive-squares % gleam run 100000000 200
   Compiled in 0.02s
    Running sum_of_consecutive_squares.main
45130177
70601237
49792562
76676118
46697307
72051352
68563275
33888618
81849726
58256450
97802377
21053398
88708865
--- Results ---
REAL TIME: 37.851144375s
CPU TIME: 255.664s
CPU TIME / REAL TIME Ratio: 6.754458926448245
```
