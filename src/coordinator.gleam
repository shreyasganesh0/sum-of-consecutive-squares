import gleam/io
import gleam/int
import gleam/list
import gleam/float

import gleam/otp/actor

import gleam/erlang/process
import gleam/erlang/atom

import gleam/time/timestamp
import gleam/time/duration

import worker.{type Message}

type CoordState {

    CoordState(
        count: Int,
        last_count: Int,
        k: Int,
        num_workers: Int,
        curr_idx: Int,
        start_num: Int,
        finished_count: Int,
        start_cpu_time: Int,
        subject: process.Subject(Message),
        main_subject: process.Subject(Nil),
        start_time: timestamp.Timestamp,
        workers: List(process.Subject(worker.Message))
    )
}

@external(erlang, "erlang", "statistics")
fn statistics(item: atom.Atom) -> #(Int, Int)

fn get_cpu_time_ms() -> Int {
  let runtime_atom = atom.create("runtime")
  let #(_, total_runtime_ms) = statistics(runtime_atom)
  total_runtime_ms
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

    let act = actor.new_with_initialiser(1000000, fn(sub) {init(sub, count, last_count, k, num_workers, main_sub)})
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

    let start_time = timestamp.system_time()
    let start_cpu = get_cpu_time_ms()

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
                        start_cpu_time: start_cpu,
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

            let end_cpu = get_cpu_time_ms()
            let total_cpu_ms = int.to_float(end_cpu - state.start_cpu_time)
            let cpu_time_s = total_cpu_ms /. 1000.0

            let end_real = timestamp.system_time()
            let total_real_duration = timestamp.difference(state.start_time, end_real)

            let real_time_s = duration.to_seconds(total_real_duration)

            let ratio = case real_time_s >. 0.0 {
              True -> cpu_time_s /. real_time_s
              False -> 0.0
            }

            io.println("--- Results ---")
            io.println("REAL TIME: " <> float.to_string(real_time_s) <> "s")
            io.println("CPU TIME: " <> float.to_string(cpu_time_s) <> "s")
            io.println("CPU TIME / REAL TIME Ratio: " <> float.to_string(ratio))


            actor.send(state.main_subject, Nil)
            
            actor.stop()
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
