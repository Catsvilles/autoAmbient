/*

start with pedal bassline that moves once every 20 seconds or so aong major scale

create bank of combinations of consonant notes above pedal

every 4 seconds, play notes picked randomly from bank of combos relative to bass note

share bass note with uppers (Plambda with Plet/Pget???) to calculate pitches

create arrays of upper note sequences to remember and play at different pitch levels (bass notes)

*/

(
var figDict = ('m3': 3, 'M3': 4, 'P4': 5, 'P5': 7, 'm6': 8, 'M6': 9);
~figs = (
	\major: [
		['M3', 'P5'],
		['M3', 'M6'],
		['P4', 'M6'],
	],
	\minor: [
		['m3', 'P5'],
		['m3', 'm6'],
		['P4', 'm6'],
	]
);
~convFigs = (
	\major: ~figs[\major].deepCollect(2, { |i| figDict[i]}),
	\minor: ~figs[\minor].deepCollect(2, { |i| figDict[i]})
).postln;


SynthDef(\tone, {
	arg freq = 50, out = 1, gate = 1, amp = 0.5;
	var sig, env, envGen;

	env = Env([0, 0.5, 0], [0.02, 0.2], releaseNode: 1);
	envGen = EnvGen.ar(envelope: env, gate: gate, doneAction: Done.freeSelf);

	sig = SinOsc.ar(freq: freq, mul: 0.5, mul: amp);
	sig = sig * envGen;

	Out.ar(out, sig!2);
}).add;

SynthDef(\reverb, {
	arg in=0, out=0;
	var sig = In.ar(in, 2);
	sig = FreeVerb2.ar(sig[0], sig[1], 0.4, 0.8, 0.2);
	Out.ar(out, sig);
}).add;

SynthDef(\delay, {
	arg in=0, out=0;

	var sig = In.ar(in, 2);
	sig = CombC.ar(sig, 8, 0.33, 8);
	Out.ar(out, sig);
}).add;
)


(
s.newBusAllocators;
~pentaBus = Bus.audio(numChannels: 2);
~bassBus = Bus.audio(numChannels: 2);

~sourceGroup = Group.new;
~pentaGroup = Group.after(~sourceGroup);
~bassGroup = Group.after(~pentaGroup);

Synth.new(\reverb, [\in, ~pentaBus, \out, ~pentaBus], ~pentaGroup);
Synth.new(\delay, [\in, ~pentaBus, \out, 0], ~pentaGroup);

Synth.new(\reverb, [\in, ~bassBus, \out, 0], ~bassGroup);

~pedal = Pbind(
	\instrument, \tone,
	\degree, Plet(
		\pedal,
		Pdup(8, Pfuncn({ [0, 2, 4, 5, 7].choose}, inf))
	),
	\scale, Scale.chromatic,
	\octave, 3,
	\dur, Pseq([0.999, Pseq([1], inf)], 1),
	\sustain, 1,
	\out, ~bassBus,
	\group, ~sourceGroup,
	\amp, 0.8,
);

~uppers = Pbind(
	\instrument, \tone,
	\figures, Pdup(
		2,
		Pfunc({
			var mode = [\major, \minor].choose;
			var indices = (0..2).scramble.keep(2);
			[~convFigs[mode][indices[0]], ~convFigs[mode][indices[1]]];
		})
	).flatten(0),
	\octave, 4,
	\scale, Scale.chromatic,
	\degree, Pget(\pedal, 0, inf) + Pkey(\figures),
	\dur, 2,
	\sustain, 2,
	\amp, 0.5,
	\out, ~bassBus,
	\group, ~sourceGroup
);

Plambda(Ppar([~pedal, ~uppers], inf)).play;

)

