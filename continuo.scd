/*

start with pedal bassline that moves once every 20 seconds or so aong major scale

create bank of combinations of consonant notes above pedal

every 4 seconds, play notes picked randomly from bank of combos relative to bass note

share bass note with uppers (Plambda with Plet/Pget???) to calculate pitches

create arrays of upper note sequences to remember and play at different pitch levels (bass notes)

*/

(
var figDict = ('P2': 2, 'm3': 3, 'M3': 4, 'P4': 5, 'P5': 7, 'm6': 8, 'M6': 9);
~figs = (
	\major: [
		['P2', 'P5'],
		['M3', 'P5'],
		['M3', 'M6'],
		['P4', 'P5'],
		['P4', 'M6'],
	],
	\minor: [
		['P2', 'P5'],
		['m3', 'P5'],
		['m3', 'm6'],
		['P4', 'P5'],
		['P4', 'm6'],
	]
);
~convFigs = (
	\major: ~figs[\major].deepCollect(2, { |i| figDict[i]}),
	\minor: ~figs[\minor].deepCollect(2, { |i| figDict[i]})
);


SynthDef(\tone, {
	arg freq = 50, out = 1, gate = 1, amp = 0.5, pan=0;
	var sig, env, envGen, vib;

	env = Env([0, 0.5, 0], [0.01, 0.1], releaseNode: 1);
	envGen = EnvGen.ar(envelope: env, gate: gate, doneAction: Done.freeSelf);

	vib = SinOsc.ar(3, 0, 1.25);
	sig = Mix.ar([SinOsc.ar(freq: freq + vib, mul: amp), Saw.ar(freq: freq + vib, mul: amp/2.25)]);
	sig = sig * envGen;
	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig);
}).add;

SynthDef(\bassTone, {
	arg freq = 50, out = 1, gate = 1, amp = 0.5, pan=0;
	var sig, env, envGen;

	env = Env(
		levels: [0, 0.9, 0.4, 0, 0],
		times: [0.01, 0.05, 0.05, 0.05],
		curve: [3, -3, 3, -3],
		releaseNode: 2
	);

	envGen = EnvGen.ar(envelope: env, gate: gate, doneAction: Done.freeSelf);

	sig = Mix.ar([SinOsc.ar(freq: freq, mul: amp), Saw.ar(freq: freq, mul: amp/7)]);
	sig = sig * envGen;
	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig);
}).add;

SynthDef(\highHat, {
	arg out = 1, gate = 1, amp = 0.5, pan=0;
	var sig, env, envGen;

	env = Env([0, 0.5, 0], [0.0005, 0.05], releaseNode: 1);
	envGen = EnvGen.ar(envelope: env, gate: gate, doneAction: Done.freeSelf);

	sig = Mix.ar([ClipNoise.ar(amp,  0), BrownNoise.ar(amp, 0)]);
	sig = sig * envGen;
	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig);
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
	sig = CombC.ar(sig, 4, 1/2, 6);
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

~fundamental = Pbind(
	\event, \rest,
	\degree, Plet(\pedal, Pfuncn({ (-1..7).choose }, inf)),
	\dur, 16,
	\amp, 0,
);

~pedal = Pbind(
	\instrument, \bassTone,
	\degree, Pget(\pedal, 0, inf),
	\scale, Scale.chromatic,
	\octave, Pwrand([3, 4], [0.75, 0.25], inf),
	\dur, Pxrand([1, 0.75, 0.5], inf),
	\sustain, Pkey(\dur),
	\out, ~bassBus,
	\group, ~sourceGroup,
	\amp, 1,
	\pan, Pseq((1..9).normalize(-1,1).mirror1, inf)
);

~blocksFigures = Pfuncn({
	var mode = [\major, \minor].choose;
	var indices = (0..4).scramble.keep(2);
	[
		[~convFigs[mode][indices[0]], 12],
		[~convFigs[mode][indices[1]], 12]
	].flatten2(-1);
}, 1);
~blocks = Pbind(
	\instrument, \tone,
	\figures, Pdup(2, ~blocksFigures).flatten(0).trace,
	\octave, 4,
	\scale, Scale.chromatic,
	\degree, Pget(\pedal, 0, inf) + Pkey(\figures).trace,
	\dur, 4,
	\sustain, Pkey(\dur),
	\amp, 0.4,
	\out, ~bassBus,
	\group, ~sourceGroup,
	\pan, Pfunc({ |e|
		Array.fill(
			e[\degree].size,
			{|i| (i/(e[\degree].size + 1))*2 - 0.5 }
	) })
);

~arpsFigures = Pfuncn({
	var mode = [\major, \minor].choose;
	var indices = (0..4).scramble.keep(2);
	[
		~convFigs[mode][indices[0]],
		12,
		12 + ~convFigs[mode][indices[0]],
		Rest()!3,
		~convFigs[mode][indices[1]],
		12,
		12 + ~convFigs[mode][indices[1]],
		Rest()!3
	].flatten(1);
}, 1).trace;
~arps = Pbind(
	\instrument, \tone,
	\figures, Pdup(4, ~arpsFigures).flatten(0),
	\octave, 4,
	\scale, Scale.chromatic,
	\degree, Pget(\pedal, 0, inf) + Pkey(\figures),
	\dur, 0.25,
	\sustain, Pkey(\dur),
	\amp, Pseq([0.35, 0.35, 0.3, 0.2!5].flatten(1), inf),
	\out, [0, ~pentaBus],
	\group, ~pentaGroup,
	\pan, Pseq(([0.5, -0.5]!4).flatten.mirror2, inf)
);

~comps = Ptpar([
	0, ~blocks, 16, ~arps
], inf);


~highHat = Pbind(
	\instrument, \highHat,
	\sustain, Pwrand([0.01, 0.04], [0.75, 0.25], inf),
	\dur, Pdup(
		Pxrand([4 ,8, 12, 16], inf),
		Pxrand([1/4 ,1/8, 1/16], inf)
	),
	\amp, Pseq([0.2, 0.15, 0.15, 0.15], inf) * Pwrand([1, 0.5, 0], [0.7, 0.2, 0.1], inf),
	\out, ~bassBus,
	\group, ~sourceGroup,
	\pan, Pseq([0.2, 0.3], inf)
);

Plambda(Ppar([~fundamental, ~pedal, ~comps, ~highHat], inf)).play;

)