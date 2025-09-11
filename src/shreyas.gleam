import argv
import gleam/io
import gleam/int
//import gleam/float
//import gleam/string
import gleam/list
import gleam/result
import gleam/option.{Some, None}
//import gleam/time/duration
import gleam/time/timestamp

import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision

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

    let _start = timestamp.system_time()

    let res = case argv.load().arguments {

        [str1, str2] -> {

            {
                use int1 <- result.try(int.parse(str1)
                |>result.map_error(fn(_) { InvalidArgs }))

                use int2 <- result.try(int.parse(str2)
                |>result.map_error(fn(_) { InvalidArgs }))

                Ok(#("", int1, int2, 100, None))
            }
        }

        [str1, str2, str3] -> {

           {

                let int1 = int.parse(str1)
                           |> result.map_error(fn(_) { InvalidArgs})
                           
                case int1 {

                    Ok(intx) -> {

                        use int2 <- result.try(int.parse(str2)
                        |>result.map_error(fn(_) { InvalidArgs }))
                        use int3 <- result.try(int.parse(str3)
                        |>result.map_error(fn(_) { InvalidArgs }))
                        Ok(#("", intx, int2, int3, None))
                    }

                    Error(_) -> {

                        use int2 <- result.try(int.parse(str2)
                        |>result.map_error(fn(_) { InvalidArgs }))
                        use int3 <- result.try(int.parse(str3)
                        |>result.map_error(fn(_) { InvalidArgs }))
                        Ok(#(str1, int2, int3, 100, None))
                    }
                }

            }

        }


        [node_type, str1, str2, str3] -> {

            {
                use int1 <- result.try(int.parse(str1)
                |>result.map_error(fn(_) { InvalidArgs }))

                use int2 <- result.try(int.parse(str2)
                |>result.map_error(fn(_) { InvalidArgs }))

                use int3 <- result.try(int.parse(str3)
                |>result.map_error(fn(_) { InvalidArgs }))

                Ok(#(node_type, int1, int2, int3, None))
            }

        }

        [node_type, str1, str2, str3, remote_node_addr] -> {

            {
                use int1 <- result.try(int.parse(str1)
                |>result.map_error(fn(_) { InvalidArgs }))

                use int2 <- result.try(int.parse(str2)
                |>result.map_error(fn(_) { InvalidArgs }))

                use int3 <- result.try(int.parse(str3)
                |>result.map_error(fn(_) { InvalidArgs }))

                let addr_atom = atom.create(remote_node_addr)

                let ret = case node.connect(addr_atom) {

                    Ok(my_node) -> {

                        Ok(#(node_type, int1, int2, int3, Some(my_node)))
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

        Ok(#(node_type, num1, num2, num3, maybe_node)) -> {

            // let end = timestamp.system_time()
            // let total_real_duration = timestamp.difference(start, end)
            //
            // let real_time_s = duration.to_seconds(total_real_duration)
            // io.println("Time taken for main: " <> float.to_string(real_time_s))
            case maybe_node {

                Some(remote_node) -> calc_sum_of_squares_remote(node_type, num1, num2, num3, remote_node)

                None -> calc_sum_of_squares(node_type, num1, num2, num3)
            }
        }

        Error(InvalidArgs) -> {
            io.println("Input provided to args were not integers") 
            Error(InvalidArgs)
        }

        Error(NotEnoughArgs(required)) -> {
            io.println("invalid args sent")
            io.println("Usage: gleam run [Node-Type] <N> <k> <max_workers>")
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

pub fn calc_sum_of_squares_remote(node_type: String, 
                            n: Int,
                            _k: Int,
                            max_workers: Int,
                            remote_node: node.Node) -> Result(Int, ParseError) {

    let num_workers = case n <= max_workers {

        True -> n

        False -> max_workers
    }

    io.println("Number of availble workers: " <> int.to_string(num_workers))
    
    let main_sub = process.new_subject()

    let sup_build = supervisor.new(strategy: supervisor.OneForOne)
    
    let #(_worker_list, sup_builder) = case node_type {

        "Worker" -> {

            let worker_list: List(process.Subject(worker.Message)) = []
            list.fold(
                list.range(1, num_workers), 
                #(worker_list, sup_build), 
                fn (curr_tup, _) {
                    
                    let #(worker_list, sup_builder) = curr_tup 

                    let wrk = worker.start(Some(remote_node), True)
                    let assert Ok(sub) = wrk
                    #(
                        [sub.data, ..worker_list],
                        supervisor.add(
                            sup_builder, 
                            supervision.worker(fn() {wrk}
                            )
                        |> supervision.restart(
                            supervision.Transient)
                        )
                    )
                }
             )

        }

        _ -> { 
            io.println("Remote node not expected for non worker nodes")
            process.send(main_sub, Nil)
            #([], sup_build) 
        }
    }
    let _ = supervisor.auto_shutdown(sup_builder, supervisor.AllSignificant)
    |> supervisor.start

    process.receive_forever(main_sub)

    Ok(0)
}

pub fn calc_sum_of_squares(node_type: String, 
                            n: Int,
                            k: Int,
                            max_workers: Int,
                        ) -> Result(Int, ParseError) {

    //let num_cores = system.schedulers_online()
    let _start = timestamp.system_time()

    let num_workers = case n <= max_workers {

        True -> n

        False -> max_workers
    }

    let count = n / num_workers
    let last_count = count + {n % num_workers} 

    io.println("Number of availble workers: " <> int.to_string(num_workers))
    
    let main_sub = process.new_subject()

    let sup_build = supervisor.new(strategy: supervisor.OneForOne)
    
    let #(_worker_list, sup_builder) = case node_type {

        "Coordinator" -> {

            let crd = coordinator.start(
                            count,
                            last_count,
                            k,
                            num_workers,
                            [],
                            main_sub,
                            True,
             )

            let bldr = supervisor.add(sup_build, supervision.worker(fn() {crd})
                                                |> supervision.significant(True)
                                                |> supervision.restart(supervision.Transient)
                    )
            #([],bldr)

        }

        _ -> {
            let worker_list: List(process.Subject(worker.Message)) = []
            let #(final_worker_list, sup_builder) = list.fold(
                list.range(1, num_workers), 
                #(worker_list, sup_build), 
                fn (curr_tup, _) {
                    
                    let #(worker_list, sup_builder) = curr_tup 

                    let wrk = worker.start(None, False)
                    let assert Ok(sub) = wrk
                    #(
                        [sub.data, ..worker_list],
                        supervisor.add(
                            sup_builder, 
                            supervision.worker(fn() {wrk}
                            )
                        |> supervision.restart(
                            supervision.Transient)
                        )
                    )
                }
             )
            let crd = coordinator.start(
                            count,
                            last_count,
                            k,
                            num_workers,
                            final_worker_list,
                            main_sub,
                            False,
             )

            let bldr = supervisor.add(sup_builder, supervision.worker(fn() {crd})
                                                |> supervision.significant(True)
                                                |> supervision.restart(supervision.Transient)
                    )
            #(final_worker_list, bldr)

        }
    }

    let _ = supervisor.auto_shutdown(sup_builder, supervisor.AllSignificant)
    |> supervisor.start

    // let end = timestamp.system_time()
    // let total_real_duration = timestamp.difference(start, end)
    //
    // let real_time_s = duration.to_seconds(total_real_duration)
    // io.println("Time taken for startup: " <> float.to_string(real_time_s))

    process.receive_forever(main_sub)
    
    // let end_new = timestamp.system_time()
    // let total_real_duration = timestamp.difference(start, end_new)
    //
    // let real_time_s = duration.to_seconds(total_real_duration)
    // io.println("Time taken for end: " <> float.to_string(real_time_s))

    Ok(0)


}
