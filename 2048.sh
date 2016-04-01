#!/bin/bash
# Bash 2048 Game by Mekswhy

declare -A COLORS
COLORS[0]=$'\e[0m' # Reset
COLORS[1]=$'\e[31m' # Red for last piece
COLORS[2]=$'\e[32m' # Green
COLORS[4]=$'\e[33m' # Yellow
COLORS[8]=$'\e[34m' # Blue
COLORS[16]=$'\e[35m' # Magenta
COLORS[32]=$'\e[36m' # Cyan
COLORS[64]=$'\e[32m\e[7m' # Green backgroud
COLORS[128]=$'\e[33m\e[7m' # Yellow background
COLORS[256]=$'\e[34m\e[7m' # Blue background
COLORS[512]=$'\e[35m\e[7m' # Magenta background
COLORS[1024]=$'\e[36m\e[7m' # Cyan background
COLORS[2048]=$'\e[31m\e[7m' # Red background
readonly COLORS

SIZE=4
TARGET=2048
declare -A MOVE

# Game State
BOARD=()
PIECES=0
LAST=0

main() {
  init "$@"
  while true; do
    print_board
    check_state
    key_react
    gen_piece
  done
}

init() {
  exec 3> /dev/null
  while getopts "s:t:l:" opt; do
    case $opt in
      s)
        SIZE="$OPTARG"
        if (( SIZE < 3 || SIZE > 9 )); then
          echo "Board size between 3 and 9" >&2
          exit 1
        fi
        ;;
      t)
        TARGET="$OPTARG"
        if (( TARGET < 16 || TARGET > 8196 )); then
          echo "Target between 16 and 8196" >&2
          exit 1
        fi
        ;;
      l)
        exec 3> "$OPTARG"
        ;;
      *)
        usage
        ;;
    esac
  done
  
  readonly SIZE
  readonly TARGET
  MOVE[up]=-$SIZE
  MOVE[down]=+$SIZE
  MOVE[left]=-1
  MOVE[right]=+1
  readonly MOVE

  local i
  for (( i = 0; i < SIZE*SIZE; i++ )); do
    BOARD[$i]=0
  done
  gen_piece
  gen_piece
}

usage() {
  echo "Usage: $0 [-s <3-9>] [-t <16-8196>]" >&2
  echo "s: Board Size" >&2
  echo "t: Target" >&2
  echo "l: Log Path" >&2
  exit 1
}

gen_piece() {
  (( PIECES == SIZE*SIZE )) && return
  while true; do
    (( LAST = RANDOM % (SIZE*SIZE) ))
    (( BOARD[LAST] == 0 )) && {
      (( BOARD[LAST] = RANDOM%10 ? 2 : 4 ))
      (( PIECES++ ))
      printf $'Generate piece %d on %d\n' ${BOARD[$LAST]} $LAST >&3
      break
    } 
  done
}

print_board() {
  clear
  echo 'Bash 2048 Game by Mekswhy'
  local i j
  for (( i = 0; i < SIZE; i++ )); do
    print_line
    for (( j = 0; j < SIZE; j++ )); do
      local val=$(( BOARD[i*SIZE+j] ))
      local color=$(( i*SIZE+j == LAST ? 1 : $val ))
      printf '|%s%4d%s' ${COLORS[$color]} $val ${COLORS[0]}
    done
    echo '|'
  done
  print_line
}

print_line() {
  local i
  for (( i = 0; i < SIZE; i++ )); do
    printf '+----'
  done
  echo '+'
}

check_state() {
  # Win?
  if [[ "${BOARD[@]}" =~ $TARGET ]]; then
    echo Win!
    exit 0
  fi
  # Failed?
  # (( PIECES != SIZE*SIZE )) && return
  # Save game state
  local old_board=("${BOARD[@]}")
  local old_pieces=$PIECES
  local merged=no
  for dir in up down left right; do
    push_all $dir
    if (( PIECES < old_pieces )); then
      echo 'Can merge' >&3
      merged=yes
      break
    fi
  done
  BOARD=("${old_board[@]}")
  PIECES=$old_pieces
  if (( PIECES == SIZE*SIZE )) && [[ $merged == no ]]; then
    echo Failed...
    exit 1
  fi
}

key_react() {
  read -sn 1
  [[ "$REPLY" == $'\e' ]] && {
    read -sn 1 -t 0.1
    [[ "$REPLY" == '[' ]] && {
      read -sn 1 -t 0.1
      case $REPLY in
        A) push_all up ;;
        B) push_all down ;;
        C) push_all right ;;
        D) push_all left;;
      esac
    }
  }
}

# Push all pieces from one direction
# $1: direction
push_all() {
  local index
  for (( index = 0; index < SIZE; index++ )); do
    push_line $1 $index
  done
}

# Push pieces in one row or column
# $1: direction
# $2: index of row or column
push_line() {
  local dir index
  dir=$1; index=$2
  printf $'Push from %s at %d row/col\n' $dir $index >&3

  # Traverse direction is opposite to push direction
  case $dir in
    up) dir=down ;;
    down) dir=up ;;
    left) dir=right ;;
    right) dir=left ;;
  esac

  # Merge and shrink in one pass
  local start end pos cur last_merged
  start=$(get_start_cell $dir $index)
  end=$(get_end_cell $dir $index)

  pos=$start
  # Prevent pieces got merged twice
  last_merged=-1
  for (( cur = start; cur != end; cur += MOVE[$dir] )); do
    # Merge
    if (( pos != start && BOARD[cur] == BOARD[pos-MOVE[$dir]] &&
      last_merged != pos-MOVE[$dir] )); then
      (( BOARD[cur] = 0 ))
      (( BOARD[pos-MOVE[$dir]] *= 2))
      (( last_merged = pos-MOVE[$dir] ))
      (( PIECES-- ))
      continue
    fi
    # Shrink
    if (( BOARD[cur] > 0 )); then
      if (( cur != pos )); then
        (( BOARD[pos] = BOARD[cur] ))
        (( BOARD[cur] = 0 ))
      fi
      (( pos += MOVE[$dir] ))
    fi
  done
}

# Get the start cell in one row or column
# $1: direction
# $2: index of row or column
# return: start cell index
get_start_cell() {
  local dir index
  dir=$1; index=$2
  case $dir in
    up) echo $(( SIZE*(SIZE-1) + index )) ;;
    down) echo $(( 0 + index )) ;;
    left) echo $(( SIZE-1 + index*SIZE )) ;;
    right) echo $(( 0 + index*SIZE )) ;;
  esac
}

# Get one pass the last cell in one row or column
# $1: direction
# $2: index of row or column
# return: end cell index
get_end_cell() {
  local dir index
  dir=$1; index=$2
  case $dir in
    up) echo $(( -SIZE + index )) ;;
    down) echo $(( SIZE*SIZE + index )) ;;
    left) echo $(( -1 + index*SIZE )) ;;
    right) echo $(( SIZE + index*SIZE )) ;;
  esac
}

main "$@"

