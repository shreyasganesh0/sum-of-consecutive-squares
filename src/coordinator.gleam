import gleam/io
import gleam/int
import gleam/list

import gleam/otp/actor

import gleam/erlang/atom
import gleam/erlang/process

import gleam/time/timestamp
import gleam/time/duration

import worker.{type Message}

@external(erlang, "erlang", "statistics")
fn get_stats(option: atom.Atom) -> #(Int, Int)

fn get_total_runtime_ms() -> Int {
  let runtime_atom = atom.create("runtime")
  let #(_, total_runtime) = get_stats(runtime_atom)
  total_runtime
}

type CoordState {

    CoordState(
        count: Int,
        last_count: Int,
        k: Int,
        num_workers: Int,
        curr_idx: Int,
        start_num: Int,
        finished_count: Int,
        subject: process.Subject(Message),
        main_subject: process.Subject(Nil),
        start_time: timestamp.Timestamp,
        start_time_cpu: Int,
        workers: List(process.Subject(worker.Message))
    )
}

pub fn start(
    count: Int, 
    last_count: Int,
    k: Int, 
    num_workers: Int, 
    main_sub: process.Subject(Nil),
    ) -> Result(
        actor.Started(process.Subject(Message)),
        actor.StartError) {


    //io.println("[COORDINATOR]: starting coordinator")

    let act = actor.new_with_initialiser(1000, fn(sub) {init(sub, count, last_count, k, num_workers, main_sub)})
    |> actor.on_message(handle_coord_message)
    |> actor.start

    act
}

fn init(
    sub: process.Subject(Message),
    count: Int,
    last_count: Int,
    k: Int,
    num_workers: Int,
    main_subject: process.Subject(Nil)
    ) -> Result(
        actor.Initialised(
            CoordState, 
            worker.Message, process.Subject(worker.Message)
            ), 
        String,
        ) {


    //io.println("[COORDINATOR]: init function started")

    //io.println("[COORDINATOR]: initalising with:\n" <> "count: " <> int.to_string(count) <> " last_count: " <> int.to_string(last_count) <> " k: " <>int.to_string(k) <> " num_workers: " <> int.to_string(num_workers))

    let start_cpu_ms = get_total_runtime_ms()
    let start_time = timestamp.system_time()

    let init_state = CoordState(
                        count: count,
                        last_count: last_count,
                        k: k,
                        num_workers: num_workers,
                        curr_idx: 1,
                        start_num: 1,
                        finished_count: 0,
                        subject: sub,
                        main_subject: main_subject,
                        start_time: start_time,
                        start_time_cpu: start_cpu_ms,
                        workers: []
                    )

    let init = actor.initialised(init_state)
    |> actor.returning(sub)
    //io.println("[COORDINATOR]: init function finished")

    Ok(init)
}

fn handle_coord_message(
    state: CoordState, 
    message: worker.Message
    ) -> actor.Next(CoordState, worker.Message) {

    case message {

        worker.Shutdown -> {

             let end_cpu_ms = get_total_runtime_ms()

            let elapsed_cpu_ms = end_cpu_ms - state.start_time_cpu

            io.println("Finished.")
            io.println(
            "The work took " <> int.to_string(elapsed_cpu_ms) <> "ms of CPU time.",
            )

            let end = timestamp.system_time()
            let #(time_s, time_ns) = timestamp.difference(state.start_time, end)
            |> duration.to_seconds_and_nanoseconds
            io.println("Time Taken: " <> int.to_string(time_s) <> "." <> int.to_string(time_ns))

            actor.send(state.main_subject, Nil)
            
            actor.stop()
        }

        worker.TestMessage -> {
            //io.println("[COORDINATOR]: ____GOT_TEST____")
            actor.continue(state)
        }

        worker.Check(worker_sub, num_list) -> {

            //io.println("[COORDINATOR]: rcvd check message from worker")
            list.each(num_list, fn(a) {

                                    io.println(int.to_string(a))
                                }
            )

            process.send(worker_sub, worker.Shutdown)

            let new_state = CoordState(
                ..state,
                finished_count: state.finished_count + 1
            )

            case new_state.finished_count == new_state.num_workers {

                True -> {
                    process.send(new_state.subject, worker.Shutdown)
                }

                False -> Nil 

            }

            actor.continue(new_state)

        }

        // worker.RegisterWorker(worker_subject) -> {
        //
        //     io.println("[COORDINATOR]: added worker to state")
        //
        //     actor.send(worker_subject, worker.Calculate(state.k, state.count, state.start_num))
        //
        //     case state.curr_idx < {state.num_workers - 1} {
        //
        //         True -> { 
        //             let new_state = CoordState(
        //                 ..state,
        //                 curr_idx: state.curr_idx + 1,
        //                 start_num: state.start_num + state.count,
        //                 workers: [worker_subject, ..state.workers]
        //             )
        //             actor.continue(new_state)
        //         }
        //
        //         False -> { // last worker
        //             let new_state = CoordState(
        //                 ..state,
        //                 count: state.last_count,
        //                 curr_idx: state.curr_idx + 1,
        //                 start_num: state.start_num + state.count,
        //                 workers: [worker_subject, ..state.workers]
        //             )
        //             actor.continue(new_state)
        //         }
        //     }
        //
        //     io.println("[COORDINATOR]: received worker registrartion")
        //
        //     actor.continue(state)
        //
        // }

        _ -> {

            //io.println("[COORDINATOR]: recvd invalid message")
            actor.continue(state)
        }

    }
}
