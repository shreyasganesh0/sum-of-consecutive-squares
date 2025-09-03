import argv
import gleam/io
import gleam/int
//import gleam/string
import gleam/list
import gleam/result

import gleam/otp/actor

import gleam/erlang/process
import gleam/erlang/node
import gleam/erlang/atom

import worker
import coordinator

pub type ParseError {
    NotEnoughArgs(required: Int)
    InvalidArgs
    ActorError(error: actor.StartError)
    NodeError(error: node.ConnectError)
}

pub fn main() -> Result(Int, ParseError) {

    let res = case argv.load().arguments {

        [str1, str2] -> {

            {
                use int1 <- result.try(int.parse(str1)
                |>result.map_error(fn(_) { InvalidArgs }))

                use int2 <- result.try(int.parse(str2)
                |>result.map_error(fn(_) { InvalidArgs }))

                Ok(#(int1, int2, 100))
            }
        }

        [str1, str2, str3] -> {

            {
                use int1 <- result.try(int.parse(str1)
                |>result.map_error(fn(_) { InvalidArgs }))

                use int2 <- result.try(int.parse(str2)
                |>result.map_error(fn(_) { InvalidArgs }))

                use int3 <- result.try(int.parse(str3)
                |>result.map_error(fn(_) { InvalidArgs }))

                Ok(#(int1, int2, int3))
            }

        }

        [str1, str2, str3, remote_node_addr] -> {

            {
                use int1 <- result.try(int.parse(str1)
                |>result.map_error(fn(_) { InvalidArgs }))

                use int2 <- result.try(int.parse(str2)
                |>result.map_error(fn(_) { InvalidArgs }))

                use int3 <- result.try(int.parse(str3)
                |>result.map_error(fn(_) { InvalidArgs }))

                let addr_atom = atom.create(remote_node_addr)

                let ret = case node.connect(addr_atom) {

                    Ok(_my_node) -> {

                        Ok(#(int1, int2, int3))
                    }

                    Error(err) -> {
                    
                        Error(NodeError(error: err))

                    }
                }

                ret
            }
        }

        _ -> Error(NotEnoughArgs(required: 3))
    }

    case res {

        Ok(#(num1, num2, num3)) -> {

            calc_sum_of_squares(num1, num2, num3)
        }

        Error(InvalidArgs) -> {
            io.println("Input provided to args were not integers") 
            Error(InvalidArgs)
        }

        Error(NotEnoughArgs(required)) -> {
            io.println("Expected 3 args")
            io.println("Usage: gleam run <N> <k> <max_workers>")
            Error(NotEnoughArgs(required: required))
        }

        Error(ActorError(actor_error)) -> {

            case actor_error {

                actor.InitTimeout -> {
                    io.println("Actor failed to start in exepected time")
                }

                actor.InitFailed(str) -> {
                    io.println("Couldnt initialize actor: " <> str)
                }

                actor.InitExited(_exit_reason) -> {

                    io.println("Actor exited")
                }

            }
            Error(ActorError(actor_error))
        }

        Error(NodeError(connect_err)) -> {

            case connect_err {
                node.FailedToConnect -> {

                    io.println("Failed to connect to node")
                    Error(NodeError(connect_err))
                } 

                node.LocalNodeIsNotAlive -> {

                    io.println("local node not alive, unalbe to connect to other nodes.")
                    Error(NodeError(connect_err))
                }
            }
        }
                                        
    }

}


pub fn calc_sum_of_squares(n: Int, k: Int, max_workers: Int) -> Result(Int, ParseError) {

    //let num_cores = system.schedulers_online()

    let num_workers = case n <= max_workers {

        True -> n

        False -> max_workers
    }

    let count = n / num_workers
    let last_count = count + {n % num_workers} 

    let worker_list = list.range(1, num_workers - 1)

    //io.println("Number of availble workers: " <> int.to_string(num_workers))

    // let _ = supervisor.new(strategy: supervisor.OneForOne)
    // |> supervisor.add(supervision.worker(fn() {coordinator.start(count,
    //                                                             last_count,
    //                                                             k,
    //                                                             num_workers
    //                                                             )
    //                                     } 
    //                                 )
    // )
    // |> list.fold(worker_list, _, fn(builder, _) -> supervisor.Builder {
    //                                 supervisor.add(
    //                                     builder,
    //                                     supervision.worker(worker.start)
    //                                 )
    //                             }
    //     )
    // |> supervisor.start

    let main_sub = process.new_subject()

    let coord = coordinator.start(count,
        last_count,
        k,
        num_workers,
        main_sub,
    )

    case coord {

        Ok(act) -> {

            let coord_subject = act.data
            list.each(worker_list, fn(a) {

                                    let assert Ok(curr_worker) = worker.start(coord_subject)
                                    process.send(curr_worker.data, 
                                                 worker.Calculate(
                                                                k: k, 
                                                                count: count,
                                                                start_num: {1 + {a - 1} * count},
                                                  )
                                    )
                                }
            )

            let assert Ok(curr_worker) = worker.start(coord_subject)
            process.send(curr_worker.data, 
                         worker.Calculate(
                                        k: k, 
                                        count: last_count,
                                        start_num: 1 + {num_workers - 1} * count,
                          )
            )
            process.receive_forever(main_sub)
            Ok(0)
        }

        Error(error) -> {
            io.println("Failed to start coordinator")
            Error(ActorError(error))
        }
    }




}
