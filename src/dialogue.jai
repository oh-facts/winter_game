OPENING_PROMPT :: #string DONE
Cutscene
DONE;

TREE_TALK :: #string DONE
Tree.
DONE

SIREN_TALK :: #string DONE
blah blah blah
DONE

AoS_Opening_0 :: #string DONE
Since you are alive
You must be a protagonist
Perhaps even "The Protagonist"
In fact, *We* are protagonists
You and I
DONE

AoS_Opening_1 :: #string DONE
AoS : Psst. I can hold my breath forever, but I'll catch a cold if I stay like this
DONE

AoS_Opening_2 :: #string DONE
Do you remember your lines?
DONE

AoS_Opening_3 :: #string DONE
AOS : Lets go over this again :).
Look for victims of this sadness
If you find any, hold their hands
This will wake them up.
Then, bring them here, to me

DONE

AoS_Opening_4 :: #string DONE
AOS : If you do this, they will go to heaven.
Otherwise, they will experience nothingness forever
DONE

AoS_Opening_5 :: #string DONE
AOS : Lets try again
DONE

//AoS_Demo_

/*
I am writing game stuff here

aos : *while lying down* if you try talking to her, she say "pst .. hold my hands"

Then the hold hands option appears

when you interact with someone, you see a prompt and then you can pick what you want

I am thinking in the real beginning, you follow the beam and when you find her, she tells you how happy she is. how absolutely happy and then you zone out and when you zone in, the "past .. hold my hands part" starts
*/


/*
	if dialogue_phase == {
		
		case 7;
		if editor_button("Hold Hands").active {
			dialogue_phase += 1;
		}
		
		case 8;
		editor_label("Well done! You are so good at this! Now walk me to the altar.");
		
		active_interaction.e.frame_n = 0;
		
		if os.event(events, .E, .Pressed) { 
			dialogue_phase += 1;
		}
		
		case 9;
		push_world_complete_interaction();
		dialogue_phase += 1;
		active_interaction.e.frame_n = 1;
		
		case 10;
		editor_label("Aos : Sorry :(");
		editor_label("My leg hurts");
		editor_label("Can you try lifting me?");
		
		if os.event(events, .E, .Pressed) { 
			dialogue_phase += 1;
		}
		
		case 11;
		
		if editor_button("Hold Hands").active {
			dialogue_phase = 8;
		}
		
		if editor_button("Pick up").active {
			dialogue_phase += 1;
		}
		
		case 12;
		editor_label("*You weren't able to pick AoS because you are too weak*");
		
		if os.event(events, .E, .Pressed) { 
			dialogue_phase += 1;
		}
		
		case 13;
		editor_label("Lol. I am too fat.");
		editor_label("Anyways, I am sure you will be able to figure this out");
		editor_label("Good Luck!");
		
		if os.event(events, .E, .Pressed) { 
			dialogue_phase += 1;
		}
		
		case 14;
		push_world_complete_interaction();
}
	*/