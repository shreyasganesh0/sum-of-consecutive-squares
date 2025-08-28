import argv
import gleam/io
import gleam/int
import gleam/string
import gleam/list
import gleam/result

import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision

import worker


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


pub fn calc_sum_of_squares(num1: Int, num2: Int) -> Result(Int, ParseError) {

    int.to_string(num1)
    |>string.append("Numbers paresd are: ", _)
    |>string.append(int.to_string(num2))
    |>io.println

    //let num_cores = system.schedulers_online()

    let num_workers = num2 / 100

    let worker_list = list.range(0, num_workers)
    io.println("Number of availble workers: " <> int.to_string(num_workers))

    let assert Ok(_) = supervisor.new(strategy: supervisor.OneForOne)
  //|>supervisor.add(master.get_supervision_spec())
    |>list.fold(worker_list, _, fn(builder, _) -> supervisor.Builder {
        supervisor.add(builder, supervision.worker(worker.get_supervision_spec))
        })
    |>supervisor.start

    Ok(0)
}
