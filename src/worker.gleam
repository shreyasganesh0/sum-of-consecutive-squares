import gleam/io
import gleam/int
import gleam/list
import gleam/float
import gleam/result
import gleam/option.{type Option, Some, None}
import gleam/dynamic
import gleam/dynamic/decode

import gleam/otp/actor

import gleam/erlang/node
import gleam/erlang/atom

import gleam/erlang/process

pub type WorkerState {

    WorkerState(coord_sub: process.Subject(Message))
}

pub type Message {

    FinishedWork

    Shutdown

    TestMessage

    TryRegister(self_subject: process.Subject(Message))

    RegisterWorker(worker_subject: process.Pid)

    Calculate(coord_sub: process.Subject(Message), k: Int, count: Int, start_num: Int)

    Check(int_list: List(Int))
}

@external(erlang, "global", "send")
pub fn send_intlist(dst: atom.Atom, msg: #(atom.Atom, List(Int))) -> #(atom.Atom, List(Int))

@external(erlang, "global", "send")
pub fn send_pid(dst: atom.Atom, msg: #(atom.Atom, process.Pid)) -> process.Pid

@external(erlang, "global", "whereis_name")
pub fn whereis_name(name: atom.Atom) -> process.Pid

@external(erlang ,"global", "registered_names")
pub fn registered_names() -> List(atom.Atom)

@external(erlang, "gleam_stdlib", "identity")
fn unsafe_coerce(a: a) -> b
//
@external(erlang, "erlang", "is_pid")
pub fn is_pid(term: dynamic.Dynamic) -> Bool

pub fn start(
    remote_node: Option(node.Node),
    ) -> Result(actor.Started(process.Subject(Message)), actor.StartError) {

    //io.println("[WORKER]: start function started")

    let coord_name = atom.create("shreyas_coordinator")
    let _coord_pid = whereis_name(coord_name)

    let ret = actor.new_with_initialiser(10000, fn(sub) {init(sub, remote_node)})
    |> actor.on_message(handle_worker_messages)
    |> actor.start 

    case remote_node {
        Some(_node) -> {
			io.println("[WORKER]: checking registered names")
			process.sleep(1000)
			registered_names()
			|> list.each(fn(a) {
				io.println("[WORKER]: registered atoms: " <> atom.to_string(a))
			})
			let assert Ok(ret_sub) = ret
			let assert Ok(pid) = process.subject_owner(ret_sub.data)

			io.println("[WORKER]: sending registration message")
			//process.send(coord_pid, RegisterWorker(pid))
			//send_global(coord_pid, RegisterWorker(pid))
			let reg_worker = atom.create("RegisterWorker")
            send_pid(coord_name, #(reg_worker, pid))  
            Nil
        }

        None -> Nil
    }

    //io.println("[WORKER]: start function finished")
    ret
    
}

fn init(
    sub: process.Subject(Message),
    remote_node: Option(node.Node),
    ) -> Result(
        actor.Initialised(
            Nil,
            Message, 
            process.Subject(Message)), 
        String) {

    //io.println("[WORKER]: init function started")

    let init = actor.initialised(Nil)
    |> actor.returning(sub)

    let fin_init = case remote_node {

        Some(_) -> {

            let calc = atom.create("Calculate")
			let selector = process.new_selector()
                           |> process.select_record(calc,
                                                    3,
                                                    fn (msg) {
                                                        handle_calculations(msg,
                                                       )
                                                    },
				              )
            let final_init = actor.selecting(init, selector)

            final_init
        }

        None -> init

    }

    //process.send(sub, TryRegister(sub))

    //io.println("[WORKER]: init function finished")
    Ok(fin_init)

}

pub fn pid_decoder() -> decode.Decoder(process.Pid) {

    let tmp_pid = process.spawn(fn() {Nil})
    io.println("[COORDINATOR]: received message from worker in selector")
    process.kill(tmp_pid)
    decode.new_primitive_decoder("Pid", fn(data) {

                                            case is_pid(data) {

                                                True -> {

                                                    let pid: process.Pid = unsafe_coerce(data)
                                                    Ok(pid)
                                                }

                                                False -> {

                                                    Error(tmp_pid)
                                                }
                                            }
                                        }
    )
}

fn handle_calculations(
    msg: dynamic.Dynamic,
    ) -> Message {

	io.println("[WORKER]: handling calculations")

    let assert Ok(#(k, count, start_num)) = {
        use k <- result.try(decode.run(msg, decode.at([1], decode.int)))
        use count <- result.try(decode.run(msg, decode.at([2], decode.int)))
        use start_num <- result.try(decode.run(msg, decode.at([3], decode.int)))
        Ok(#(k, count, start_num))
    }

    let ret_list = calc_sum_squares(k, count, start_num)
    let check = atom.create("Check")
    let coord_name = atom.create("shreyas_coordinator")
	io.println("[WORKER]: sending calculations")
    send_intlist(coord_name, #(check, ret_list))
    FinishedWork

}


fn handle_worker_messages (
    state: Nil, 
    message: Message,
    ) -> actor.Next(Nil, Message) {

    //io.println("[WORKER]: got message")
    
    case message {

        Shutdown -> actor.stop()

        Calculate(coord_sub, k, count, start_num) -> {

            //io.println("[WORKER]: recvd Calculate message:\nk: " <> int.to_string(k) <> " count: " <> int.to_string(count) <> " start_num: " <> int.to_string(start_num))

            let ret_list = calc_sum_squares(k, count, start_num)
            actor.send(coord_sub, Check(int_list: ret_list))
            actor.continue(state)
        }

        _ -> {
            //io.println("[WORKER]: worker recvd invalid message")
            actor.continue(state)
        }
    }

}

fn calc_sum_squares(k: Int, count: Int, start_idx: Int) -> List(Int) {

    //io.println("[WORKER]: checking start_idx: " <> int.to_string(start_idx) <> " count: " <> int.to_string(count) <> " k: " <> int.to_string(k))

    let ret_list = list.range(start_idx, {count - 1} + start_idx)
    |> list.filter(fn(x) {
                    //io.println("[WORKER]: using value from array: " <> int.to_string(x))
                    let calc_val = list.range(x, {k - 1} + x)
                    |> list.fold(0, fn(acc, a) {
                                        {acc + a * a}
                                    }
                               )
                    //io.println("[WORKER]: sum squared value " <> int.to_string(calc_val))

                    let assert Ok(float_val) = int.square_root(calc_val) 
                    ////io.println("[WORKER]: checking float" <> float.to_string(float_val))
                    float_val == float.ceiling(float_val)
                }
        )


    ret_list

}
