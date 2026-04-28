package chess

import "core:fmt"
import "core:os"
import "core:strings"


is_valid_notation :: proc(move: string) -> bool {
	move := strings.trim_space(move)

	for i in 0 ..< 5 {
		c := move[i]
		if (i == 0 || i == 3) && (c < 97 || c > 104) do return false
		else if (i == 1 || i == 4) && (c < 49 || c > 56) do return false
	}

	return true
}

get_square_from_notation :: proc(letter: u8, number: u8) -> u64 {
	return get_bitboard_square(97 - cast(int)letter, 7 - (49 - cast(int)number))
}

get_move_from_notation :: proc(move: string) -> Move {
	move := strings.trim_space(move)
	return Move {
		from = get_square_from_notation(move[0], move[1]),
		to = get_square_from_notation(move[3], move[4]),
	}
}

handle_move_notation_input :: proc(buffer: []byte, retrying: bool) -> Move {
	if retrying do fmt.print("Move is in an incorrect format or not possible, please retry : ")
	else do fmt.print("Enter the move to be played (for example : a2-a3) : ")

	os.read(os.stdin, buffer[:])
	str_move := string(buffer[:])
	if !is_valid_move(str_move) do return handle_move_notation_input(buffer, true)

	move := get_move_from_notation(str_move)
	// Add move verification logic
	return move
}

is_valid_move :: proc(move: string) -> bool {
	return is_valid_notation(move)
}

main :: proc() {
	board := DEFAULT_BOARD
	buffer: [10]byte

	for {
		fmt.print("\e[2J\e[H")
		display_board(&board)
		move := handle_move_notation_input(buffer[:], false)
		fmt.println(move)
	}

}

