import argv
import gleam/io
import gleam/int
import gleam/string
import gleam/result

pub type ParseError {
    NotEnoughArgs(required: Int)
    InvalidArgs
}

pub fn main() -> Result(Int, ParseError) {

    let res = case argv.load().arguments {

        [str1, str2] -> {

            {
                use int1 <- result.try(int.parse(str1)
                |>result.map_error(fn(_) { InvalidArgs }))
                use int2 <- result.try(int.parse(str2)
                |>result.map_error(fn(_) { InvalidArgs }))
                Ok(#(int1, int2))
            }

        }

        _ -> Error(NotEnoughArgs(required: 2))
    }

    case res {

        Ok(#(num1, num2)) -> {

            calc_sum_of_squares(num1, num2)
        }

        _ -> Error(InvalidArgs)
    }

}


pub fn calc_sum_of_squares(num1: Int, num2: Int) -> Result(Int, ParseError) {

    int.to_string(num1)
    |>string.append("Numbers paresd are: ", _)
    |>string.append(int.to_string(num2))
    |>io.println

    Ok(0)
}
