import gleam/io
import gleam/int
import gleam/list
//import gleam/float

import gleam/otp/actor

import gleam/erlang/process
import gleam/erlang/atom
//
// import gleam/time/timestamp
// import gleam/time/duration

import worker.{type Message}

type CoordState {

    CoordState(
        count: Int, 
        last_count: Int,
        k: Int, 
        num_workers: Int,
        finished_count: Int,
        main_subject: process.Subject(Nil),
        sub: process.Subject(Message),
        total_printed: Int,
        curr_idx: Int,
    )
}

@external(erlang, "global", "register_name")
pub fn register_name(dst: atom.Atom, pid: process.Pid) -> atom.Atom

@external(erlang ,"global", "registered_names")
pub fn registered_names() -> List(atom.Atom)

@external(erlang, "erlang", "send")
pub fn send_global(dst: process.Pid, msg: worker.Message) -> worker.Message

pub fn start(
    count: Int, 
    last_count: Int,
    k: Int, 
    num_workers: Int, 
    worker_list: List(process.Subject(Message)),
    main_subject: process.Subject(Nil),
    is_remote: Bool,
    ) -> Result(
        actor.Started(process.Subject(Message)),
        actor.StartError) {


    io.println("[COORDINATOR]: starting coordinator")


    let act = actor.new_with_initialiser(100000, fn(sub) {
                                                    init(
                                                        sub, 
                                                        count, 
                                                        last_count,
                                                        k,
                                                        num_workers,
                                                        worker_list,
                                                        main_subject,
                                                        is_remote
                                                    )
                                                  }
               )
    |> actor.on_message(handle_coord_message)
    |> actor.start
    io.println("[COORDINATOR]: start function end")

    act
}

fn init(
    sub: process.Subject(Message),
    count: Int,
    last_count: Int,
    k: Int,
    num_workers: Int,
    worker_list: List(process.Subject(Message)),
    main_subject: process.Subject(Nil),
    is_remote: Bool,
    ) -> Result(
        actor.Initialised(
            CoordState, 
            worker.Message, process.Subject(worker.Message)
            ), 
        String,
        ) {


    io.println("[COORDINATOR]: init function started")

    io.println("[COORDINATOR]: initalising with:\n" <> "count: " <> int.to_string(count) <> " last_count: " <> int.to_string(last_count) <> " k: " <>int.to_string(k) <> " num_workers: " <> int.to_string(num_workers))


    let init_state = CoordState(
                        sub: sub,
                        count: count,
                        last_count: last_count,
                        k: k,
                        num_workers: num_workers,
                        finished_count: 0,
                        main_subject: main_subject,
                        total_printed: 0,
                        curr_idx: 0,
                    )

    let init = actor.initialised(init_state)
    |> actor.returning(sub)
    //io.println("[COORDINATOR]: init function finished")


    //let assert Ok(_) = process.register(pid, process.new_name("shreyas_coordinator"))
    case is_remote {

        False -> {
            list.index_map(worker_list, fn(worker_sub, curr_idx) {
                                           case curr_idx < num_workers - 1 {

                                           True -> {
                                               process.send(worker_sub, worker.Calculate(
                                                                                coord_sub: sub, 
                                                                                k: k,
                                                                                count: count,
                                                                                start_num:  1 + {curr_idx * count},
                                                                        )
                                               )
                                           }

                                           False -> {

                                               process.send(worker_sub, worker.Calculate(
                                                                                coord_sub: sub, 
                                                                                k: k,
                                                                                count: last_count,
                                                                                start_num: 1 + {curr_idx * count},
                                                                        )
                                               )

                                           }
                                       }

                                        #(worker_sub, curr_idx)
                                    }
            )
            Nil
        }

        True -> {

			let assert Ok(pid) = process.subject_owner(sub)

			case register_name(atom.create("shreyas_coordinator"), pid)
			|> atom.to_string {
				
				"no" -> io.println("failed to register name")

				"yes" -> io.println("registered coord name globally")

				_ -> io.println("found random name ")
			}
			registered_names()
			|> list.each(fn(a) {
				io.println("[COORDINATOR]: registered atoms: " <> atom.to_string(a))
			})

			let selector = process.new_selector()
				|> process.select(sub)
				|> process.select_record(worker.Tag,
										1,
										handle_registration
							)

		}
    }

    Ok(init)
}

fn handle_coord_message(
    state: CoordState, 
    message: worker.Message
    ) -> actor.Next(CoordState, worker.Message) {

    io.println("[COORDINATOR]: handling messsage")

    case message {

        worker.Shutdown -> {

            // let end_cpu = get_cpu_time_ms()
            // let total_cpu_ms = int.to_float(end_cpu - state.start_cpu_time)
            // let cpu_time_s = total_cpu_ms /. 1000.0
            //
            // let end_real = timestamp.system_time()
            // let total_real_duration = timestamp.difference(state.start_time, end_real)
            //
            // let real_time_s = duration.to_seconds(total_real_duration)
            //
            // let ratio = case real_time_s >. 0.0 {
            //   True -> cpu_time_s /. real_time_s
            //   False -> 0.0
            // }
            //
            // io.println("--- Results ---")
            // io.println("REAL TIME: " <> float.to_string(real_time_s) <> "s")
            // io.println("CPU TIME: " <> float.to_string(cpu_time_s) <> "s")
            // io.println("CPU TIME / REAL TIME Ratio: " <> float.to_string(ratio))
            //


            actor.stop()
        }

        worker.FinishedWork -> {
            io.println("[COORDINATOR]: worker finished sending") 
            actor.continue(state)
        }

        worker.RegisterWorker(worker_pid) -> {

            case state.curr_idx < state.num_workers - 1 {

                True -> {

                    send_global(worker_pid, worker.Calculate(
                                                        coord_sub: state.sub, 
                                                        k: state.k,
                                                        count: state.count,
                                                        start_num: 1 + {state.curr_idx * state.count},
                                                    )
                    )
                }

                False -> {

                    send_global(worker_pid, worker.Calculate(
                                                        coord_sub: state.sub, 
                                                        k: state.k,
                                                        count: state.last_count,
                                                        start_num: 1 + {state.curr_idx * state.count},
                                                    )
                    )
                }

            }

            let new_state = CoordState(
                                ..state,
                                curr_idx: state.curr_idx + 1,
                            )
            actor.continue(new_state)
        }

        worker.Check(num_list) -> {

            //io.println("[COORDINATOR]: rcvd check message from worker")
            let num_count = list.fold(num_list, 0, fn(acc, a) {

                                    io.println(int.to_string(a))
                                    acc + 1
                                }
            )

            let new_state = CoordState(
                ..state,
                finished_count: state.finished_count + 1,
                total_printed: state.total_printed + num_count
            )

            case new_state.finished_count == new_state.num_workers {

                True -> {

                    case state.total_printed == 0 {

                        True -> io.println("----- NO ANSWERS FOUND -----")

                        False -> Nil
                    }
                    actor.send(state.main_subject, Nil)
                    actor.stop()
                }

                False -> {
                    actor.continue(new_state)

                } 

            }

        }

        _ -> {

            echo message
            io.println("[COORDINATOR]: recvd invalid message")
            actor.continue(state)
        }

    }
}
