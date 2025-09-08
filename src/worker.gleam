//import gleam/io
import gleam/int
import gleam/list
import gleam/float
import gleam/option.{type Option, Some, None}

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

    TryRegister(self_subject: process.Subject(Message))

    RegisterWorker(worker_subject: process.Subject(Message))

    Calculate(coord_sub: process.Subject(Message), k: Int, count: Int, start_num: Int)

    Check(int_list: List(Int))
}

@external(erlang, "global", "send")
pub fn send_rem(dst: atom.Atom, msg: Message) -> process.Pid

@external(erlang, "global", "whereis_name")
pub fn whereis_name(name: atom.Atom) -> process.Pid


pub fn start(
    remote_node: Option(node.Node)
    ) -> Result(actor.Started(process.Subject(Message)), actor.StartError) {

    //io.println("[WORKER]: start function started")

    let coord_name = atom.create("shreyas_coordinator")
    let _coord_pid = whereis_name(coord_name)

    let ret = actor.new(Nil)
    |> actor.on_message(handle_worker_messages)
    |> actor.start 

    let assert Ok(ret_sub) = ret
    case remote_node {
        Some(_node) -> {
            send_rem(coord_name, RegisterWorker(ret_sub.data))  
            Nil
        }

        None -> Nil
    }

    //io.println("[WORKER]: start function finished")
    ret
    
}

// fn init(
//     sub: process.Subject(Message),
//     ) -> Result(
//         actor.Initialised(
//             Nil,
//             Message, 
//             process.Subject(Message)), 
//         String) {
//
//     //io.println("[WORKER]: init function started")
//
//
//     let init = actor.initialised(Nil)
//     |> actor.returning(sub)
//
//     //process.send(sub, TryRegister(sub))
//
//     //io.println("[WORKER]: init function finished")
//     Ok(init)
//
// }

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
