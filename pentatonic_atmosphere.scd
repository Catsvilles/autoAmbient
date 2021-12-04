(
SynthDef(\softBell, {
	arg freq = 100, out = 0, gate = 1;

	var sig, env, envGen;

	env = Env.new(levels: [0, 0.9, 0.2, 0], times: [0.01, 0.3, 0.5], releaseNode: 2, curve: [0, -5, 2, 3]);
	envGen = EnvGen.ar(envelope: env, gate: gate, doneAction: Done.freeSelf);

	sig = SinOsc.ar(freq: freq, mul: 0.2);
	sig = sig * envGen;

	Out.ar(out, sig!2);
}).add;

SynthDef(\bassKick, {
	arg freq = 50, out = 2;
	var sig, env, envGen;

	env = Env.new(levels: [0, 1, 0], times: [0.05, 1.95], curve: [-2, 2]);
	envGen = EnvGen.ar(envelope: env, doneAction: Done.freeSelf);

	sig = SinOsc.ar(freq: freq, mul: 0.5);
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
~pentaBus = Bus.audio(numChannels: 2).postln;
~bassBus = Bus.audio(numChannels: 2).postln;

~sourceGroup = Group.new;
~pentaGroup = Group.after(~sourceGroup);
~bassGroup = Group.after(~pentaGroup);

Synth.new(\reverb, [\in, ~pentaBus, \out, ~pentaBus], ~pentaGroup);
Synth.new(\delay, [\in, ~pentaBus, \out, 0], ~pentaGroup);

Synth.new(\reverb, [\in, ~bassBus, \out, 0], ~bassGroup);


//create a pbind with the shared data

~softBellPattern = Pbind(
	\instrument, \softBell,
	\freq, Pxrand([100, 112.5, 125, 150, 167, 175, 200], inf),
	\dur, Prand([1, 2, 3], inf),
	\sustain, 4,
	\gate, 0,
	\out, ~pentaBus,
	\group, ~sourceGroup
).play(quant: [2, 0, 0]);

~bassKickPattern = Pbind(
	\instrument, \bassKick,
	\freq, Pseq([50, 100], inf),
	\dur, 4,
	\out, ~bassBus,
	\group, ~sourceGroup
).play(quant: [2, 0, 0]);

)