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
	return get_bitboard_square(cast(int)letter - 97, 7 - (cast(int)number - 49))
}

get_move_from_notation :: proc(move: string) -> Move {
	move := strings.trim_space(move)
	return Move {
		from = get_square_from_notation(move[0], move[1]),
		to = get_square_from_notation(move[3], move[4]),
	}
}

handle_move_notation_input :: proc(board: ^Board, buffer: []byte, retrying: string) -> Move {
	if retrying != "" do fmt.printf("%s, please retry : ", retrying)
	else do fmt.print("Enter the move to be played (for example : a2-a3) : ")

	os.read(os.stdin, buffer[:])
	str_move := string(buffer[:])
	move, err := process_move(board, str_move)

	if err != "" do return handle_move_notation_input(board, buffer, err)

	return move
}

process_move :: proc(board: ^Board, str_move: string) -> (Move, string) {
	if !is_valid_notation(str_move) do return Move{}, "Move is in an incorrect format"

	move := get_move_from_notation(str_move)
	available_targets := get_moves(board, move.from)

	for target in available_targets {
		display_bitboard(target)
		if target == move.to {
			return move, ""
		}
	}

	return move, "Move is not possible"

}

main :: proc() {
	board := DEFAULT_BOARD
	buffer: [10]byte

	for {
		fmt.print("\e[2J\e[H")
		display_board(&board)
		move := handle_move_notation_input(&board, buffer[:], "")
		fmt.println(move)
		perform_move(&board, move)
	}
}

