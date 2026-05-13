--!strict
-- Tutorial step definitions, shared so the server can validate step
-- advancement and the client can render the matching popup.
--
-- Flow:
--   tutorialStep == 0      — first session, modal will appear after
--                            AgencySetup completes (agencyName is non-empty)
--   tutorialStep in 1..N   — step N is currently visible
--   tutorialStep == DONE   — tutorial finished or skipped; never shown again

local Tutorial = {}

export type Step = {
	title: string,
	body: string,
}

-- Sentinel value the client + server agree on. Larger than any real step
-- index, so range checks naturally treat it as "done".
Tutorial.DONE = 999

Tutorial.STEPS = {
	{
		title = "Welcome, Director",
		body = "Your agency just got its charter. Tap the 🚀 Sounding Rocket on the left to launch your first mission — each launch pays out funds (top-center) and science (top-right).",
	},
	{
		title = "Build Your Fleet",
		body = "Press the green BUY button on any vehicle to add another to your fleet. Each one you own multiplies the contract value of every launch.",
	},
	{
		title = "Hire a Mission Director",
		body = "Once you own enough of a vehicle, you'll be able to hire a Mission Director under the BUY button. Directors automate launches forever — true idle income while you sleep.",
	},
	{
		title = "Research New Tech",
		body = "Click 🔬 R&D in the left sidebar to spend science on the tech tree. Researching Telemetry Systems unlocks Comm Satellites; every chain step opens a new mission program.",
	},
	{
		title = "Take Contracts",
		body = "Three procedural mission contracts live at the bottom of the screen. Hit their targets through normal play, then claim them for bonus funds + science. Good luck, Director.",
	},
} :: { Step }

Tutorial.TOTAL_STEPS = #Tutorial.STEPS

-- True iff the given step index points at a real tutorial entry. Anything
-- outside [1, N] (including DONE) is treated as "tutorial complete".
function Tutorial.isActiveStep(step: number): boolean
	return step >= 1 and step <= Tutorial.TOTAL_STEPS
end

return Tutorial
