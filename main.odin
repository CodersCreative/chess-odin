package chess

import "core:fmt"
import "core:math/bits"
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
	return get_bitboard_square(cast(int)letter - 97, (cast(int)number - 49))
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
	player: ^Piece_Color,
	retrying: string,
) -> Move {
	if retrying != "" do fmt.printf("%s, please retry : ", retrying)
	else do fmt.print("Enter the move to be played (for example : a2-a3 or a3 - algebraic notation allowed ) :\n")


	os.read(os.stdin, buffer[:])
	str_move := string(buffer[:])

	if strings.contains(str_move, "fen") {
		return handle_move_notation_input(
			board,
			buffer,
			player,
			fmt.tprintf("FEN output:\n%s", get_fen(board, player)),
		)
	} else if strings.contains(str_move, "pgn") {
		return handle_move_notation_input(
			board,
			buffer,
			player,
			fmt.tprintf("PGN output:\n%s", get_pgn(board, player)),
		)
	} else if strings.contains(str_move, "end") || strings.contains(str_move, "quit") {
		player^ = Piece_Color.None
		return Move{}
	} else if strings.contains(str_move, "clear") {
		clear()
		display_board(board)
		handle_move_notation_input(board, buffer, player, "")
	}


	str_move = strings.trim_space(str_move)
	move, err := process_move(board, str_move)

	if err != "" {
		algebraic_move, success := get_algebraic_notation_move_details(str_move)
		if success {
			move, success = process_algebraic_move(board, player^, algebraic_move)
			if !success do return handle_move_notation_input(board, buffer, player, err)
			else do return move
		}

		position := get_square_from_notation(str_move[0], str_move[1])
		ones := bits.count_ones(position)
		if ones != 1 do return handle_move_notation_input(board, buffer, player, err)
		bitboard := get_moves_bitboard(get_moves(board, position)[:])
		if bitboard == 0 do fmt.printfln("No Targets available for position %s", str_move)
		else {
			clear()
			display_board(board)
			fmt.printfln("Targets available for move %s", str_move)
			display_pretty_bitboard(bitboard)
			fmt.println("")
		}
		return handle_move_notation_input(board, buffer, player, "")
	}

	if err != "" do return handle_move_notation_input(board, buffer, player, err)

	if get_piece_color(get_piece(board, move.from)) != player^ do return handle_move_notation_input(board, buffer, player, "Move is not possible because it is not your piece")

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

handle_fen :: proc(board: ^Board, player: ^Piece_Color, buffer: []byte) {
	fmt.print("Load a FEN situation (y/n)? ")
	os.read(os.stdin, buffer[:])
	str := string(buffer[:])
	if strings.contains_any(str, "y") {
		for true {
			fmt.print("FEN : ")
			os.read(os.stdin, buffer[:])
			fen := string(buffer[:])

			if load_fen(board, player, fen) {
				fmt.println("FEN successfully loaded!")
				break
			} else {
				fmt.println("Invalid FEN string entered, try again.")
			}
		}
	}

	fmt.println("Remember the FEN can be displayed at any time by inputting `fen`")
	time.sleep(1 * time.Second)
}

handle_pgn :: proc(board: ^Board, player: ^Piece_Color, buffer: []byte) {
	fmt.print("Load a PGN situation (y/n)? ")
	os.read(os.stdin, buffer[:])
	str := string(buffer[:])
	if strings.contains_any(str, "y") {
		for true {
			fmt.print("PGN : ")
			os.read(os.stdin, buffer[:])
			pgn := string(buffer[:])

			if load_pgn_from_path(board, player, pgn) {
				fmt.println("PGN successfully loaded!")
				break
			} else if load_pgn(board, player, pgn) {
				fmt.println("PGN successfully loaded!")
				break
			} else {
				fmt.println("Invalid PGN path/string entered, try again.")
			}
		}
	}

	fmt.println("Remember the PGN can be displayed at any time by inputting `pgn`")
	time.sleep(1 * time.Second)
}

MINIMAX_DEPTH :: 4
AI_MOVE_DURATION_SEC :: 1.0

HistoryMove :: struct {
	piece: Piece,
	move:  Move,
}

clear :: proc(debug: bool = false) {
	if !debug do fmt.print("\e[2J\e[H")
}

inner_game_loop :: proc() {
	board := DEFAULT_BOARD
	history: [dynamic]HistoryMove
	buffer: [512]byte
	player := Piece_Color.White
	is_player1_ai, is_player2_ai := get_ai_players(buffer[:])
	handle_fen(&board, &player, buffer[:])
	handle_pgn(&board, &player, buffer[:])
	fmt.println("The game can be restarted by inputting `end` or `quit` at any time.")
	time.sleep(1 * time.Second)

	for {
		clear()
		display_board(&board)
		display_history(history[:])
		in_check := is_in_check(&board, player)
		winner, stalemate := check_win(&board)

		#partial switch player {
		case Piece_Color.Black:
			fmt.println("Player : Black")
		case Piece_Color.White:
			fmt.println("Player : White")
		}

		if in_check || (stalemate || winner != Piece_Color.None) {
			switch winner {
			case Piece_Color.White:
				fmt.println("White Won!!!")
				return
			case Piece_Color.Black:
				fmt.println("Black Won!!!")
				return
			case Piece_Color.None:
				if stalemate {
					fmt.println("Stalemate")
					return
				} else {
					fmt.println("In Check - Protect your king.\n")
				}

			}
		} else do fmt.println("")

		move: Move
		if player == Piece_Color.White && is_player1_ai ||
		   player == Piece_Color.Black && is_player2_ai {
			start := time.tick_now()
			move = start_negamax(&board, MINIMAX_DEPTH, player)
			duration := time.tick_diff(start, time.tick_now())

			if duration < AI_MOVE_DURATION_SEC * time.Second {
				time.sleep(AI_MOVE_DURATION_SEC * time.Second - duration)
			}
		} else {
			move = handle_move_notation_input(&board, buffer[:], &player, "")
		}

		if player == Piece_Color.None {
			fmt.println("Restart Requested. Please Wait...")
			time.sleep(1 * time.Second)
			return
		}

		piece := get_piece(&board, move.from)
		append(&history, HistoryMove{piece, move})

		force_move(&board, move)
		player = invert_color(player)
	}
}

game_loop :: proc() {
	clear()
	for {
		inner_game_loop()
		time.sleep(3 * time.Second)
	}
}

uci_loop :: proc() {
	// TODO Add UCI functionality
	game_loop()
}

main :: proc() {
	args := os.args

	if len(args) > 1 {
		action := args[1]
		if action == "play" {
			game_loop()
			return
		}
	}

	uci_loop()
}

