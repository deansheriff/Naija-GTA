extends RefCounted
## Shared browser/Android world identity. Layout changes require a version bump.

const VERSION = 2
const SEED = 260713
static var character_seed := SEED
const DISTRICTS = [
	{"id": 0, "name": "Home street", "seed": 0, "description": "Amaka, Yemi and your little corner."},
	{"id": 1, "name": "Market Road", "seed": SEED + 101, "description": "Busy storefronts and a shaded neighborhood square."},
	{"id": 2, "name": "Palm Junction", "seed": SEED + 202, "description": "A quieter block beyond the market."},
]

static func valid(id: int) -> bool:
	return id >= 0 and id < DISTRICTS.size()

static func profile(id: int) -> Dictionary:
	var result: Dictionary = DISTRICTS[id].duplicate(true) if valid(id) else DISTRICTS[0].duplicate(true)
	if result.id != 0: result.seed = character_seed + int(result.id) * 101
	return result

static func chunk_seed(origin: int, destination: int, index: int, last: int) -> int:
	if index <= 0: return profile(origin).seed
	if index == last: return profile(destination).seed
	# Arithmetic mixing, not a process-dependent hash or wall-clock random seed.
	return (character_seed * 48271 + origin * 7919 + destination * 104729 + index * 15485863) % 2147483647
