//import gleam/io
import gleam/int
import gleam/list
import gleam/float

import gleam/otp/actor

import gleam/erlang/process

pub type WorkerState {

    WorkerState(coord_sub: process.Subject(Message), sub: process.Subject(Message))
}

pub type Message {

    FinishedWork

    Shutdown

    TestMessage

    TryRegister(self_subject: process.Subject(Message))

    RegisterWorker(worker_subject: process.Subject(Message))

    Calculate(k: Int, count: Int, start_num: Int)

    Check(destroy: process.Subject(Message), int_list: List(Int))
}

pub fn start(
    coord_sub: process.Subject(Message)
    ) -> Result(actor.Started(process.Subject(Message)), actor.StartError) {

    //io.println("[WORKER]: start function started")

    let ret = actor.new_with_initialiser(10000, fn(sub) {init(sub, coord_sub)})
    |> actor.on_message(handle_worker_messages)
    |> actor.start 


    //io.println("[WORKER]: start function finished")
    ret
    
}

fn init(
    sub: process.Subject(Message),
    coord_sub: process.Subject(Message)
    ) -> Result(
        actor.Initialised(
            WorkerState,
            Message, 
            process.Subject(Message)), 
        String) {

    //io.println("[WORKER]: init function started")

    let init_state = WorkerState(
                        sub: sub,
                        coord_sub: coord_sub
                    )

    let init = actor.initialised(init_state)
    |> actor.returning(sub)

    //process.send(sub, TryRegister(sub))

    //io.println("[WORKER]: init function finished")
    Ok(init)

}

fn handle_worker_messages (
    state: WorkerState,
    message: Message,
    ) -> actor.Next(WorkerState, Message) {

    //io.println("[WORKER]: got message")
    
    case message {

        Shutdown -> actor.stop()

        // TestMessage -> {
        //     //io.println("[WORKER]; ____GOT_TEST____")
        //     actor.continue(state)
        // }
        //
        // TryRegister(sub) -> {
        //
        //     //io.println("[WORKER]: recvd TryRegister message")
        //
        //     //actor.send(state.coord_sub, TestMessage)
        //     actor.send(state.coord_sub, RegisterWorker(sub))
        //     actor.continue(state)
        // }

        Calculate(k, count, start_num) -> {

            //io.println("[WORKER]: recvd Calculate message:\nk: " <> int.to_string(k) <> " count: " <> int.to_string(count) <> " start_num: " <> int.to_string(start_num))

            let ret_list = calc_sum_squares(k, count, start_num)
            actor.send(state.coord_sub, Check(state.sub, int_list: ret_list))
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
