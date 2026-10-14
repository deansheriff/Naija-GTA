extends RefCounted
## Authored sandbox errand. Progress and rewards are enforced by simulation/server.
const OBJECTIVES = {
	"available": {"text": "Ask Amaka about a light for the square. Say hello and finish the starter radio repair first.", "place": "food", "step": 0},
	"collect": {"text": "Collect Chidi's old lantern from the park crew.", "place": "park", "step": 1},
	"repair": {"text": "Bring the lantern to Yemi's workshop. Repair: 10 seconds, 8 energy; start with 15 energy.", "hud": "Repair Chidi's lantern at Yemi's. Start with 15 energy.", "place": "repair", "step": 2},
	"ready": {"text": "Return to the park crew and choose a spot: noticeboard or shaded bench.", "hud": "Choose a lantern spot with the park crew.", "place": "park", "step": 3},
	"installed": {"text": "The lantern is in place. Tell Amaka for a one-time 40 SC thank-you.", "hud": "Tell Amaka the lantern is up. Thank-you: 40 SC.", "place": "food", "step": 4},
	"complete": {"text": "Complete. The square keeps your lantern and your neighbours remember. Thank-you: 40 SC paid once.", "place": "square", "step": 5},
}
static func objective(errand: Dictionary) -> Dictionary:
	return OBJECTIVES.get(errand.get("stage", "available"), OBJECTIVES.available)

static func line(place: String, state: Dictionary) -> String:
	var stage: String = state.errand.stage
	if place == "food":
		return {
			"available": "AMAKA: The square gets dark after supper. Chidi has an old rechargeable lantern, and Yemi can help you fix it. Would you carry it between them? No rush; you can come back whenever you like.",
			"collect": "AMAKA: Ask Chidi for the old lantern. He keeps it beside the park bench. You don't have to join their football argument.",
			"repair": "AMAKA: Yemi is expecting the lantern. Use his workshop bench; his note keeps the job available if he steps out.",
			"ready": "AMAKA: Working again? Let the park crew choose with you where it will help most.",
			"installed": "AMAKA: I saw the light! Thank you for seeing it through. Here are 40 StreetCoins from the neighbourhood collection.",
			"complete": "AMAKA: My lantern neighbour! People can sit and read the noticeboard after supper now. Small work, plenty of difference.",
		}.get(stage, "")
	if place == "repair":
		if stage == "repair": return "YEMI: Chidi's lantern! The bench is ready. Ten seconds of careful work together, then take it back to the square. No charge for parts."
		if stage in ["ready", "installed", "complete"]: return "YEMI: That lantern is ready for the square. A repair means more when people can use it. Your regular repair jobs are still here."
		return "YEMI: Amaka mentioned the square needs a light. Collect Chidi's old lantern first; then we'll work on it here."
	if stage == "collect": return "CHIDI: Amaka sent you? Here's the old rechargeable lantern. Take it to Yemi's bench. We'll keep the path clear while you pass."
	if stage == "repair": return "CHIDI: You've got the lantern. Yemi's workshop is the next stop; we'll keep a space for it here."
	if stage == "ready": return "RAZOR: See light! Put it by the noticeboard for the announcements, or by the shaded bench for evening gist. Your choice, neighbour."
	if stage in ["installed", "complete"]:
		return "CHIDI: The %s looks different with that lantern. We remember who helped. And if you need space, the path is still yours." % ("noticeboard" if state.errand.spot == "board" else "shaded bench")
	return "SMALLIE: A light for this corner? Tell Amaka we're interested. We can manage the football argument without another spotlight."
