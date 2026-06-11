package chess

import "core:fmt"
import "core:math/bits"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"

UCI_State :: struct {
	board:             Board,
	player:            Piece_Color,
	searching:         bool,
	stop_search:       bool,
	debug:             bool,
	wtime:             i64,
	btime:             i64,
	winc:              i64,
	binc:              i64,
	movestogo:         i32,
	depth:             i32,
	nodes:             i64,
	movetime:          i64,
	infinite:          bool,
	nodes_searched:    i64,
	search_start_time: time.Tick,
	best_move:         Move,
	ponder_move:       Move,
}

uci_state: UCI_State

move_to_uci :: proc(move: Move) -> string {
	from_str := square_to_notation(move.from)
	to_str := square_to_notation(move.to)

	if move.promotion != .None {
		prom_char: u8
		#partial switch move.promotion {
		case .Queen:
			prom_char = 'q'
		case .Rook:
			prom_char = 'r'
		case .Bishop:
			prom_char = 'b'
		case .Knight:
			prom_char = 'n'
		case:
			prom_char = 'q'
		}
		return fmt.tprintf("%s%s%c", from_str, to_str, prom_char)
	}

	return fmt.tprintf("%s%s", from_str, to_str)
}

uci_identify :: proc() {
	fmt.println("id name Chess-Odin 1.0")
	fmt.println("id author CreativeCoders")
	fmt.println("option name Hash type spin default 64 min 1 max 1024")
	fmt.println("option name Threads type spin default 1 min 1 max 8")
	fmt.println("uciok")
}

uci_isready :: proc() {
	fmt.println("readyok")
}

uci_newgame :: proc() {
	uci_state.board = DEFAULT_BOARD
	uci_state.player = Piece_Color.White
	uci_state.searching = false
	uci_state.stop_search = false
	uci_state.nodes_searched = 0
}

parse_position :: proc(command: string) -> bool {
	parts := strings.split(command, " ")
	if len(parts) < 2 do return false

	if parts[1] == "startpos" {
		uci_state.board = DEFAULT_BOARD
		uci_state.player = Piece_Color.White

		if len(parts) > 2 && parts[2] == "moves" {
			for i in 3 ..< len(parts) {
				move_str := parts[i]
				move, err := process_move(&uci_state.board, move_str)
				if err == "" {
					force_move(&uci_state.board, move)
					uci_state.player = invert_color(uci_state.player)
				}
			}
		}
	} else if parts[1] == "fen" {
		if len(parts) < 3 do return false

		fen_str := strings.join(parts[2:3], " ")
		for i := 0; i < len(parts) && i < 3 && parts[i] != "moves"; i += 1 {
			fen_str = fmt.tprintf("%s %s", fen_str, parts[i])
		}

		if !load_fen(&uci_state.board, &uci_state.player, fen_str) {
			return false
		}

		moves_idx := -1
		for j in 2 ..< len(parts) {
			if parts[j] == "moves" {
				moves_idx = j
				break
			}
		}

		if moves_idx != -1 {
			for j in moves_idx + 1 ..< len(parts) {
				move_str := parts[j]
				move, err := process_move(&uci_state.board, move_str)
				if err == "" {
					force_move(&uci_state.board, move)
					uci_state.player = invert_color(uci_state.player)
				}
			}
		}
	} else {
		return false
	}

	return true
}

uci_go :: proc(command: string) {
	uci_state.wtime = -1
	uci_state.btime = -1
	uci_state.winc = 0
	uci_state.binc = 0
	uci_state.movestogo = -1
	uci_state.depth = -1
	uci_state.nodes = -1
	uci_state.movetime = -1
	uci_state.infinite = false
	uci_state.stop_search = false

	parts := strings.split(command, " ")

	i := 1
	for i < len(parts) {
		switch parts[i] {
		case "wtime":
			if i + 1 < len(parts) {
				uci_state.wtime = strconv.parse_i64(parts[i + 1]) or_else -1
				i += 2
			}
		case "btime":
			if i + 1 < len(parts) {
				uci_state.btime = strconv.parse_i64(parts[i + 1]) or_else -1
				i += 2
			}
		case "winc":
			if i + 1 < len(parts) {
				uci_state.winc = strconv.parse_i64(parts[i + 1]) or_else 0
				i += 2
			}
		case "binc":
			if i + 1 < len(parts) {
				uci_state.binc = strconv.parse_i64(parts[i + 1]) or_else 0
				i += 2
			}
		case "movestogo":
			if i + 1 < len(parts) {
				uci_state.movestogo = cast(i32)(strconv.parse_int(parts[i + 1]) or_else -1)
				i += 2
			}
		case "depth":
			if i + 1 < len(parts) {
				uci_state.depth = cast(i32)(strconv.parse_int(parts[i + 1]) or_else -1)
				i += 2
			}
		case "nodes":
			if i + 1 < len(parts) {
				uci_state.nodes = strconv.parse_i64(parts[i + 1]) or_else -1
				i += 2
			}
		case "movetime":
			if i + 1 < len(parts) {
				uci_state.movetime = strconv.parse_i64(parts[i + 1]) or_else -1
				i += 2
			}
		case "infinite":
			uci_state.infinite = true
			i += 1
		case:
			i += 1
		}
	}

	uci_state.searching = true
	uci_state.search_start_time = time.tick_now()
	uci_state.nodes_searched = 0

	uci_search()
}

should_stop_search :: proc() -> bool {
	if uci_state.stop_search do return true

	if uci_state.movetime != -1 {
		elapsed := time.tick_diff(uci_state.search_start_time, time.tick_now())
		if elapsed >= cast(time.Duration)uci_state.movetime * time.Millisecond {
			return true
		}
	}

	if uci_state.nodes != -1 && uci_state.nodes_searched >= uci_state.nodes {
		return true
	}

	if uci_state.wtime != -1 || uci_state.btime != -1 {
		current_time := (uci_state.player == Piece_Color.White) ? uci_state.wtime : uci_state.btime
		time_inc := (uci_state.player == Piece_Color.White) ? uci_state.winc : uci_state.binc

		if current_time != -1 {
			elapsed := time.tick_diff(uci_state.search_start_time, time.tick_now())
			remaining := current_time - cast(i64)elapsed

			if uci_state.movestogo != -1 {
				time_per_move := remaining / cast(i64)uci_state.movestogo
				if cast(i64)elapsed >= time_per_move {
					return true
				}
			} else {
				if cast(i64)elapsed >= remaining / 40 {
					return true
				}
			}
		}
	}

	return false
}

uci_search :: proc() {
	board_copy := uci_state.board
	player_copy := uci_state.player
	max_depth := (uci_state.depth != -1) ? cast(u8)uci_state.depth : 10
	if uci_state.movetime == -1 {
		uci_state.movetime = 1000
	}

	best_move := Move{}
	available_moves := get_all_moves_possible(&board_copy, player_copy, context.temp_allocator)

	if len(available_moves) == 0 {
		uci_state.best_move = Move{}
		uci_state.searching = false

		fmt.println("bestmove (none)")
		return
	}

	capture_sort_moves(&available_moves)

	search_ctx: Search_Context
	search_ctx.stop_check = should_stop_search
	search_ctx.node_counter = &uci_state.nodes_searched

	for current_depth: u8 = 1; current_depth <= max_depth; current_depth += 1 {
		if should_stop_search() ||
		   (uci_state.depth != -1 && current_depth > cast(u8)uci_state.depth) {
			break
		}

		initial_negamax(
			&board_copy,
			current_depth,
			player_copy,
			bits.I64_MIN + 1,
			bits.I64_MAX - 1,
			&available_moves,
			&search_ctx,
		)

		elapsed := time.tick_diff(uci_state.search_start_time, time.tick_now())
		nodes := uci_state.nodes_searched

		fmt.printfln(
			"info depth %d nodes %d time %d",
			current_depth,
			nodes,
			elapsed / time.Millisecond,
		)

		if len(available_moves) > 0 {
			best_move = available_moves[0]
		}
	}

	uci_state.best_move = best_move
	uci_state.searching = false

	if best_move.from != 0 && best_move.to != 0 {
		move_str := move_to_uci(best_move)
		fmt.printfln("bestmove %s", move_str)
	} else {
		fmt.println("bestmove (none)")
	}
}

uci_stop :: proc() {
	uci_state.stop_search = true
}

uci_quit :: proc() {
	uci_state.stop_search = true
	os.exit(0)
}

uci_loop :: proc() {
	buffer: [1024]byte

	uci_state.board = DEFAULT_BOARD
	uci_state.player = Piece_Color.White
	uci_state.searching = false
	uci_state.stop_search = false
	uci_state.debug = false

	for {
		bytes_read := os.read(os.stdin, buffer[:]) or_break
		if bytes_read <= 0 do break

		command := strings.trim_space(string(buffer[:bytes_read]))

		if strings.has_prefix(command, "uci") {
			uci_identify()
		} else if strings.has_prefix(command, "isready") {
			uci_isready()
		} else if strings.has_prefix(command, "ucinewgame") {
			uci_newgame()
		} else if strings.has_prefix(command, "position") {
			if !parse_position(command) {
				fmt.println("info string Invalid position command")
			}
		} else if strings.has_prefix(command, "go") {
			uci_go(command)
		} else if strings.has_prefix(command, "stop") {
			uci_stop()
		} else if strings.has_prefix(command, "quit") {
			uci_quit()
		} else if strings.has_prefix(command, "debug") {
			parts := strings.split(command, " ")
			if len(parts) > 1 {
				uci_state.debug = parts[1] == "on"
			}
		} else if strings.has_prefix(command, "setoption") {
			fmt.println("info string Option handling not fully implemented")
		}
	}
}

