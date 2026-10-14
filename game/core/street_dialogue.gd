extends RefCounted
## Authored dialogue; consequential choices go through the simulation/server rules.

const PARK = {
	"space": {"speaker": "CHIDI · PARK CREW", "line": "You asked for space last time. We remember. The path is clear; just say if you feel like talking today.", "choices": [["I'd like to introduce myself now.", "welcome"], ["Thanks. I'll keep walking.", "leave"]]},
	"intro": {"speaker": "RAZOR · PARK CREW", "line": "Omo, new face! You dey pass, or you wan gist? This corner gets loud, but everybody still has to share it.", "choices": [["I'm your new neighbor.", "welcome"], ["What's happening on this street?", "street"], ["I'll keep my distance.", "distance"]]},
	"return": {"speaker": "RAZOR · PARK CREW", "line": "Our new neighbor! You don come back. Smallie is still arguing about football. What brings you?", "choices": [["What's the argument?", "football"], ["Any useful street advice?", "street"], ["Just passing through.", "leave"]]},
	"welcome": {"speaker": "SMALLIE · PARK CREW", "line": "Then welcome. Razor talks tough, but he was the one carrying benches when the rain came. Don't tell him I said that.", "choices": [["So this is your hangout?", "corner"], ["Who's winning the football argument?", "football"], ["Nice meeting you. I should go.", "leave"]]},
	"corner": {"speaker": "CHIDI · PARK CREW", "line": "We chill here, play drafts, and hear half the street's gist. Aunty Amaka says we must leave space for other people. Fair enough.", "choices": [["What would make this park better?", "park"], ["Point me toward honest work.", "work"], ["I'll see you around.", "leave"]]},
	"street": {"speaker": "CHIDI · PARK CREW", "line": "Yemi's workshop is good for learning a repair. Amaka feeds half the neighborhood. Watch the road; the keke drivers are always in a hurry.", "choices": [["Tell me about work.", "work"], ["How's the park doing?", "park"], ["Back to the gist.", "return"]]},
	"football": {"speaker": "SMALLIE · PARK CREW", "line": "Razor said he could have scored that last chance. The man can't even kick his slipper into the right corner!", "choices": [["Everybody is a striker from the bench.", "banter"], ["I'll leave you to settle it.", "leave"]]},
	"banter": {"speaker": "RAZOR · PARK CREW", "line": "Ah! You too? Alright, alright. Next match, all of you are watching me. Chidi, keep the score properly this time.", "choices": [["Deal. What else is happening?", "street"], ["Enjoy your afternoon.", "leave"]]},
	"park": {"speaker": "CHIDI · PARK CREW", "line": "More lights, a bin that gets emptied, and a bench nobody has to fight over. There is a neighborhood noticeboard here if you want to have your say.", "choices": [["Show me the neighborhood poll.", "poll"], ["Let's keep talking.", "return"], ["I'll think about it.", "leave"]]},
	"work": {"speaker": "RAZOR · PARK CREW", "line": "If you're looking for a clean start, learn at Yemi's bench. He's straight with people. Finish his radio and he'll pay you for the job.", "choices": [["Take me to Yemi's workshop.", "repair"], ["Thanks. Back to the park gist.", "return"], ["I'll find my way.", "leave"]]},
	"distance": {"speaker": "RAZOR · PARK CREW", "line": "No wahala. You don't owe us a conversation. The path is open; safe journey, neighbor.", "choices": [["Actually, let me introduce myself.", "welcome"], ["Carry on walking.", "leave"]]},
}

static func relationship(level: int) -> String:
	return ["New face", "Acquainted", "Friendly", "Trusted neighbor"][clampi(level, 0, 3)]

static func favor_goal(favor: String) -> String:
	return {"available": "A plate for Yemi · Say hello and ask Amaka about a favor.", "carrying": "A plate for Yemi · Carry the covered lunch plate to Yemi.", "delivered": "A plate for Yemi · Return to Amaka for her thank-you.", "complete": "A plate for Yemi · Complete. One-time reward: 30 SC."}.get(favor, "")

static func neighbor_line(who: String, state: Dictionary, status: String, content: Dictionary = {}) -> String:
	var context := status + ". "
	if who == "amaka":
		if not state.met_amaka and not str(content.get("amakaLine", "")).is_empty(): return context + str(content.amakaLine)
		if not state.met_amaka: return context + "Welcome, neighbor. I'm Amaka. There's always room for one more person on this street."
		match state.favor:
			"available": return context + "Yemi forgets lunch when he's fixing things. Could you take this covered plate to him? No rush, and it's fine to say no."
			"carrying": return context + "The plate is wrapped and ready. Hand it to Yemi when you see him; then come back and gist."
			"delivered": return context + "He ate? Better! Thank you for looking out for him. I kept 30 StreetCoins aside for your trouble."
			"complete": return context + "My trusted neighbor! Yemi is still talking about that jollof you brought him. How is your day going?"
	if state.favor == "carrying": return context + "Ah, Amaka sent food? That woman remembers everybody. Let me put these tools down."
	if state.favor == "delivered": return context + "That lunch was perfect. Tell Amaka thank you. I'm washing the plate before I return it."
	if state.favor == "complete": return context + "Good to see you, my friend. You brought lunch when I needed it. The repair bench is always here for you."
	if not str(content.get("yemiLine", "")).is_empty(): return context + str(content.yemiLine)
	return context + ("Your radio repair is still playing beautifully. Good work, neighbor." if state.gig_done else "I'm Yemi. Take your time at the practice bench; a steady hand comes with practice.")

const CHATTER = [
	["razor", "Razor: Smallie, who won that match?"],
	["smallie", "Smallie: You watched it! Stop asking."],
	["amaka", "Amaka: Yemi, your food is getting cold!"],
	["yemi", "Yemi: One last screw, Aunty. I'm coming!"],
	["chidi", "Chidi: Leave space. People need to pass."],
	["razor", "Razor: Alright. Shift the chair small."],
	["conductor", "Conductor: Next stop! Make space inside."],
	["smallie", "Smallie: This sun needs its own umbrella."],
	["chidi", "Chidi: You can share mine if you stop arguing."],
]

static func chatter(favor: String, on_break: bool) -> Array:
	var lines := CHATTER.duplicate(true)
	if favor in ["delivered", "complete"]:
		lines[2] = ["amaka", "Amaka: Yemi, did our neighbor's lunch delivery reach you?"]
		lines[3] = ["yemi", "Yemi: Every grain! Thank you, Aunty. That one is a good neighbor."]
	elif favor == "carrying":
		lines[2] = ["amaka", "Amaka: Yemi, our neighbor is bringing your covered lunch plate."]
		lines[3] = ["yemi", "Yemi: Good timing. Let me clear a space and wash my hands."]
	elif on_break:
		lines[2] = ["amaka", "Amaka: Tools down small, Yemi. Take five in the shade."]
		lines[3] = ["yemi", "Yemi: You're right. The bench will still be there after tea."]
	return lines
