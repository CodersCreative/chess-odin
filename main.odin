package chess

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"


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

handle_move_notation_input :: proc(
	board: ^Board,
	buffer: []byte,
	player: Piece_Color,
	retrying: string,
) -> Move {
	if retrying != "" do fmt.printf("%s, please retry : ", retrying)
	else do fmt.print("Enter the move to be played (for example : a2-a3) : ")

	os.read(os.stdin, buffer[:])
	str_move := string(buffer[:])
	move, err := process_move(board, str_move)

	if err != "" do return handle_move_notation_input(board, buffer, player, err)

	if get_piece_color(get_piece(board, move.from)) != player do return handle_move_notation_input(board, buffer, player, "Move is not possible because it is not your piece")

	return move
}

process_move :: proc(board: ^Board, str_move: string) -> (Move, string) {
	if !is_valid_notation(str_move) do return Move{}, "Move is in an incorrect format"

	move := get_move_from_notation(str_move)
	available_targets := get_moves(board, move.from)

	for target in available_targets {
		if target == move.to {
			return move, ""
		}
	}

	return move, "Move is not possible"

}

get_ai_players :: proc(buffer: []byte) -> (bool, bool) {
	player1 := false
	player2 := false

	fmt.print("Should Player 1 Be AI (y/n)? ")
	os.read(os.stdin, buffer[:])
	str := string(buffer[:])
	player1 = strings.contains_any(str, "y")

	fmt.print("Should Player 2 Be AI (y/n)? ")
	os.read(os.stdin, buffer[:])
	str = string(buffer[:])
	player2 = strings.contains_any(str, "y")

	return player1, player2
}

MINIMAX_DEPTH :: 4
AI_MOVE_DURATION_SEC :: 1.0

HistoryMove :: struct {
	piece: Piece,
	move:  Move,
}

main :: proc() {
	for {
		fmt.print("\e[2J\e[H")
		board := DEFAULT_BOARD
		history: [dynamic]HistoryMove
		buffer: [10]byte
		player := Piece_Color.White
		is_player1_ai, is_player2_ai := get_ai_players(buffer[:])

		for {
			fmt.print("\e[2J\e[H")
			display_board(&board)
			display_history(history[:])
			in_check := is_in_check(&board, player)

			#partial switch player {
			case Piece_Color.Black:
				fmt.println("Player : Black")
			case Piece_Color.White:
				fmt.println("Player : White")
			}

			if in_check {
				winner := check_win(&board)

				switch winner {
				case Piece_Color.White:
					fmt.println("White Won!!!")
					break
				case Piece_Color.Black:
					fmt.println("Black Won!!!")
					break
				case Piece_Color.None:
					fmt.println("In Check - Protect your king.\n")
				}

			} else do fmt.println("")

			move: Move
			if player == Piece_Color.White && is_player1_ai ||
			   player == Piece_Color.Black && is_player2_ai {
				start := time.tick_now()
				move = start_minimax(&board, MINIMAX_DEPTH, player)
				duration := time.tick_diff(start, time.tick_now())

				if duration < AI_MOVE_DURATION_SEC * time.Second {
					time.sleep(AI_MOVE_DURATION_SEC * time.Second - duration)
				}


			} else {
				move = handle_move_notation_input(&board, buffer[:], player, "")
			}

			piece := get_piece(&board, move.from)
			append(&history, HistoryMove{piece, move})

			force_move(&board, move)
			player = invert_color(player)
		}
	}
}

