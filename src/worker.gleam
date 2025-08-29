import gleam/io
import gleam/int

import gleam/otp/actor
import gleam/erlang/process

pub type Message {

    Shutdown

    TryRegister(self_subject: process.Subject(Message))

    RegisterWorker(worker_subject: process.Subject(Message))

    Calculate(reply_to: process.Subject(Message), value: Int)

    Check(checked_num: Int)
}


pub fn start() -> Result(actor.Started(process.Subject(Message)), actor.StartError) {

    io.println("Starting worker")

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

    io.println("Sending coord registration from worker")

    process.send(sub, TryRegister(sub))

    let init = actor.initialised(Nil)
    |> actor.returning(sub)

    Ok(init)

}

fn handle_worker_messages (
    _state: Nil,
    message: Message,
    ) -> actor.Next(Nil, Message) {

    io.println("Started actor")
    
    case message {

        Shutdown -> actor.stop()

        TryRegister(sub) -> {

            process.new_name("Coordinator")
            |> process.named_subject
            |> process.send(RegisterWorker(sub))
            actor.continue(Nil)
        }

        Calculate(subject, val) -> {
            io.println("Recieved the Calculate Message: " <> int.to_string(val))
            let _ = calc_sum_squares(val, 0)
            process.send(subject, Check(val))
            actor.continue(Nil)
        }

        _ -> {
            io.println("worker recvd invalid message")
            actor.continue(Nil)
        }
    }

}

fn calc_sum_squares(_start_val: Int, _accumulator: Int) -> Bool {

    io.println("Started work")

    True
}
