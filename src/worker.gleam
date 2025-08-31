import gleam/io
import gleam/int
import gleam/list
import gleam/float

import gleam/otp/actor
import gleam/erlang/process

pub type Message {

    Shutdown

    TryRegister(self_subject: process.Subject(Message))

    RegisterWorker(worker_subject: process.Subject(Message))

    Calculate(k: Int, range: Int, start_value: Int)

    Check(int_list: List(Int))
}


pub fn start() -> Result(actor.Started(process.Subject(Message)), actor.StartError) {

    io.println("[WORKER]: start function started")

    let act = actor.new_with_initialiser(10, init)
    |> actor.on_message(handle_worker_messages)
    |> actor.start

    act
}

fn init(
    sub: process.Subject(Message)
    ) -> Result(
        actor.Initialised(
            Nil, 
            Message, 
            process.Subject(Message)), 
        String) {

    io.println("[WORKER]: init function started")

    process.send(sub, TryRegister(sub))

    let init = actor.initialised(Nil)
    |> actor.returning(sub)

    Ok(init)

}

fn handle_worker_messages (
    _state: Nil,
    message: Message,
    ) -> actor.Next(Nil, Message) {

    io.println("[WORKER]: got message")
    let coord_name = process.new_name("Coordinator")
    |>process.named_subject
    
    
    case message {

        Shutdown -> actor.stop()

        TryRegister(sub) -> {

            io.println("[WORKER]: recvd TryRegister message")
            process.send(coord_name, RegisterWorker(sub))
            actor.continue(Nil)
        }

        Calculate(k, count, start_num) -> {

            io.println("[WORKER]: recvd Calculate message:\nk" <> int.to_string(k) <> "count: " <> int.to_string(count) <> "start_num: " <> int.to_string(start_num))

            process.send(coord_name, Check(calc_sum_squares(k, count, start_num)))
            actor.continue(Nil)
        }

        _ -> {
            io.println("[WORKER]: worker recvd invalid message")
            actor.continue(Nil)
        }
    }

}

fn calc_sum_squares(k: Int, count: Int, start_idx: Int) -> List(Int) {

    list.range(start_idx, count + start_idx)
    |> list.filter(fn(x) {
                    let calc_val = list.range(x, k + x)
                    |> list.fold(0, fn(acc, a) {
                                        {acc * acc + a * a}
                                    }
                               )

                    let assert Ok(float_val) = int.square_root(calc_val) 
                    float_val == float.ceiling(float_val)
                }
        )

}
