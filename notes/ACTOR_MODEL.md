# Actors Using Erlang OTP

## High Level Flow
- create a supervisor
    - supervisor is a process that is spawned that handles lifetime of actors
    - gleam/otp/static_supervisor
    - supervisor.new(stratgy)
        - use this to create a new supervisor
        - the strategy is a what the supervisor will do on child failure
    - supervisor.add
        - add children to the monitoring tree of the supervisor
        - children are supervision.worker() created ChildSpecifications
        - these are actors that are monitored by the supervisor
    - start the supervisor.start
- craete actors
    - these are worker nodes
    - the ones that actually do the work including distributor/dispatcher and calculation nodes
    - they are created using actor.new(state)
        - state is some value that is modified across lifetimes of actors
        - usually stuff that we want remembered like a global stack or bitmap that actors will modify
        parts of
    - actor.on_message(handler)
        - handler is a fn(state: state, message: message)
        - the state will be given by the actor.new
        - message will be a type that register a process.Subject(messagetype) for given actor
            - this is useful when doing actor.send
            - actor.send is the way actor communicate with each other
            - they send(process.Subject(messagetype), message: messagetype)
            - the subject is like the identity of the actor we are sending the message to
                - note that the type of the the subject for the actor we are sending to and the message
                we are sending must be the same
                - this means when doing on_message(handler) the type we state for the handler's message
                argument is super important as it declares it can recieve no other type
                - makes sense cause it wouldnt know how to handle any other type
    - actor.start
        - start the actor
        - pass the function that calls actor.start as the ChildSpefication 
            - first have to declare the rest of the ChildSpeicification using the 
            supervision.worker(my_actor_starting_func)
            - this can be used to add the actor to the supervisors tree
            - note: its also possible to make an actor a supervisor using the supervision.supervisor
                - this may be useful when we need multiple supervisors to split focus/load

