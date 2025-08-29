import gleam/io
import gleam/int

import gleam/otp/actor
import gleam/erlang/process

pub type Message {

    Shutdown

    Calculate(reply_to: process.Subject(Message), value: Int)

    Check(checked_num: Int)
}

pub fn start() -> Result(actor.Started(process.Subject(Message)), actor.StartError) {

    io.println("Starting worker")

    actor.new(Nil)
    |> actor.on_message(handle_worker_messages)
    |> actor.start

}

fn handle_worker_messages (
    _state: Nil,
    message: Message,
    ) -> actor.Next(Nil, Message) {

    io.println("Started actor")
    
    case message {

        Shutdown -> actor.stop()

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
