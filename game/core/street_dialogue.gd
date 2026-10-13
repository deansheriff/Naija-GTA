extends RefCounted
## Authored conversation graph. Session familiarity only; no economy or AI calls.

const PARK = {
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
