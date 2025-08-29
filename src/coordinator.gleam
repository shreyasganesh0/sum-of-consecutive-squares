import gleam/io
import gleam/int

import gleam/otp/actor
import gleam/erlang/process

import worker.{type Message}

type CoordState {

    CoordState(
        workers: List(process.Subject(worker.Message))
    )
}

pub fn start() -> Result(actor.Started(process.Subject(Message)), actor.StartError) {

    let coord_name = process.new_name("Coordinator")


    io.println("Starting coordinator")
    let act = actor.new_with_initialiser(10, init)
    |> actor.named(coord_name)
    |> actor.on_message(handle_coord_message)
    |> actor.start

    act

}

fn init(
    sub: process.Subject(Message)
    ) -> Result(
        actor.Initialised(
            CoordState, 
            worker.Message, process.Subject(worker.Message)
            ), 
        String,
        ) {

    let init_state = CoordState([])

    let init = actor.initialised(init_state)
    |> actor.returning(sub)
    io.println("registering coord finished init")

    Ok(init)
}

fn handle_coord_message(
    state: CoordState, 
    message: worker.Message
    ) -> actor.Next(CoordState, worker.Message) {

    case message {

        worker.Shutdown -> actor.stop()

        worker.Check(checked_num) -> {

            case checked_num {

                num if num > 1 -> io.println("Found valid number" <> int.to_string(num))

                _ -> io.println("invalid number sent")
            }

            actor.continue(state)

        }

        worker.RegisterWorker(worker_subject) -> {

            let new_state = CoordState(
                workers: [worker_subject, ..state.workers]
            )

            io.println("added worker to state")
            actor.continue(new_state)
        }

        _ -> {

            io.println("coordinator recvd invalid message")
            actor.continue(state)
        }

    }
}
