import gleam/io

import gleam/otp/actor
import gleam/erlang/process

pub type Message {

    Shutdown

    Calculate(value: Int, reply_to: process.Subject(Message))

    Check(is_valid: Bool)
}

pub fn get_supervision_spec() -> Result(actor.Started(process.Subject(Message)), actor.StartError) {

    actor.new(Nil)
    |> actor.on_message(handle_worker_messages)
    |> actor.start
}

fn handle_worker_messages (
    _state: Nil,
    message: Message,
    ) -> actor.Next(Nil, Message) {
    
    case message {

        Shutdown -> actor.stop()

        Calculate(val, _) -> {
            io.println("Recieved the Calculate Message")
            let _ = calc_sum_squares(val, 0)
            actor.stop()
        }

        _ -> {
            actor.stop()
        }
    }

}

fn calc_sum_squares(_start_val: Int, _accumulator: Int) -> Bool {

    io.println("Started work")

    True
}
