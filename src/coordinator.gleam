import gleam/io
import gleam/int

import gleam/otp/actor
import gleam/erlang/process

import worker.{type Message}

pub fn start() -> Result(actor.Started(process.Subject(Message)), actor.StartError) {

    io.println("Starting coordinator")
    let act = actor.new(Nil)
    |> actor.on_message(handle_coord_message)
    |> actor.start

    case act {

        Ok(actor) -> {

            process.send(actor.data, worker.Calculate(actor.data, 10))
        }

        Error(_) -> io.println("error starting coord")
    }

    act

}

fn handle_coord_message(
    _state: Nil,
    message: worker.Message
    ) -> actor.Next(Nil, Message) {

    case message {

        worker.Shutdown -> actor.stop()

        worker.Check(checked_num) -> {

            case checked_num {

                num if num > 1 -> io.println("Found valid number" <> int.to_string(num))

                _ -> io.println("invalid number sent")
            }

            actor.continue(Nil)

        }

        _ -> {

            io.println("coordinator recvd invalid message")
            actor.continue(Nil)
        }

    }
}
