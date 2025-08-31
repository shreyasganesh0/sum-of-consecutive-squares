import argv
import gleam/io
import gleam/int
import gleam/string
import gleam/list
import gleam/result

import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision

import worker
import coordinator


pub type ParseError {
    NotEnoughArgs(required: Int)
    InvalidArgs
}

pub fn main() -> Result(Int, ParseError) {

    let res = case argv.load().arguments {

        [str1, str2] -> {

            {
                use int1 <- result.try(int.parse(str1)
                |>result.map_error(fn(_) { InvalidArgs }))
                use int2 <- result.try(int.parse(str2)
                |>result.map_error(fn(_) { InvalidArgs }))
                Ok(#(int1, int2))
            }

        }

        _ -> Error(NotEnoughArgs(required: 2))
    }

    case res {

        Ok(#(num1, num2)) -> {

            calc_sum_of_squares(num1, num2)
        }

        _ -> Error(InvalidArgs)
    }

}


pub fn calc_sum_of_squares(n: Int, k: Int) -> Result(Int, ParseError) {

    int.to_string(n)
    |>string.append("Numbers paresd are: ", _)
    |>string.append(int.to_string(k))
    |>io.println

    //let num_cores = system.schedulers_online()

    let num_workers = 8 // hardcoded for now

    let count = n / num_workers
    let last_count = count + {n % num_workers} 

    let worker_list = list.range(1, num_workers)

    io.println("Number of availble workers: " <> int.to_string(num_workers))

    let _ = supervisor.new(strategy: supervisor.OneForOne)
    |> supervisor.add(supervision.worker(fn() {coordinator.start(count,
                                                                last_count,
                                                                k,
                                                                num_workers
                                                                )
                                        } 
                                    )
    )
    |> list.fold(worker_list, _, fn(builder, _) -> supervisor.Builder {
                                    supervisor.add(
                                        builder,
                                        supervision.worker(worker.start)
                                    )
                                }
        )
    |> supervisor.start


    Ok(0)
}
