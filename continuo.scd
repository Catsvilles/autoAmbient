(
var figDict = (
	'P2': 2,
	'm3': 3,
	'M3': 4,
	'P4': 5,
	'P5': 7,
	'm6': 8,
	'M6': 9
);

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
		levels: [0, 0.6, 0.4, 0, 0],
		times: [0.01, 0.05, 0.05, 0.05],
		curve: [3, -3, 3, -3],
		releaseNode: 2
	);

	envGen = EnvGen.ar(envelope: env, gate: gate, doneAction: Done.freeSelf);

	sig = Mix.ar([
		SinOsc.ar(freq: freq, mul: amp),
		SinOsc.ar(freq: freq*2, mul: amp/3),
		Saw.ar(freq: freq, mul: amp/7),
	]);
	sig = sig * envGen;
	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig);
}).add;

SynthDef(\kick, {
	arg freq = 500, pan = 0, out = 0, amp = 0.5;

	var freqSweep = Env(
		[freq/2, freq/2, freq/10, freq/50],
		[0.01, 0.01, 0.48],
		[0, 1, -1,]
	).ar;

	var env = EnvGen.kr(Env([0,1,0], [0.01, 0.49], [1, 6]), doneAction: Done.freeSelf);

	var sig = SinOsc.ar(freqSweep, pi/2);
	sig = sig * env;
	sig = Pan2.ar(sig, pan, amp);
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
~reverbBus = Bus.audio(numChannels: 2);
~delayThenReverbBus = Bus.audio(numChannels: 2);

~sourceGroup = Group.new;
~effectsGroup = Group.after(~sourceGroup);

~delayThenReverb = Synth.new(\delay, [\in, ~delayThenReverbBus, \out, ~reverbBus], ~effectsGroup, \addToHead);
~reverb = Synth.new(\reverb, [\in, ~reverbBus, \out, 0], ~effectsGroup, \addToTail);

~fundamental = Pbind(
	\event, \rest,
	\degree, Plet(\pedal, Pfuncn({ (-4..4).choose }, inf)),
	\dur, 32,
	\amp, 0,
);

~bassDurs = Plet(\bassHit, Pxrand([1, 0.75, 0.5], inf));

~bass = Pbind(
	\instrument, \bassTone,
	\degree, Pget(\pedal, 0, inf),
	\scale, Scale.chromatic,
	\octave, Pwrand([3, 4], [0.75, 0.25], inf),
	\dur, Pget(\bassHit, 1, inf),
	\sustain, Pkey(\dur),
	\out, [0, ~reverbBus],
	\group, ~sourceGroup,
	\amp, 0.6,
	\pan, Pseq((1..9).normalize(-0.8,0.8).mirror1, inf)
);

~kick = Pbind(
	\instrument, \kick,
	\degree, Pget(\pedal, 500, inf),
	\amp, 0.6,
	\group, ~sourceGroup,
	\out, [0, ~reverbBus],
	\dur, 1,
	\pan, 0
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
	\figures, Pdup(2, ~blocksFigures).flatten(0),
	\octave, 4,
	\scale, Scale.chromatic,
	\degree, Pget(\pedal, 0, inf) + Pkey(\figures),
	\dur, 4,
	\sustain, Pkey(\dur),
	\amp, 0.3,
	\out, [0, ~reverbBus],
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
	var figArr1 = ~convFigs[mode][indices[0]];
	var figArr2 = ~convFigs[mode][indices[1]];
	var arpArr1 = figArr1++12++(12+figArr1);
	var arpArr2 = figArr2++12++(12+figArr2);

	(
		arpArr1++
		[Rest()!3]++
		arpArr2++
		[Rest()!3]
	).flatten(1);
}, 1);
~arps = Pbind(
	\instrument, \tone,
	\figures, Pdup(4, ~arpsFigures).flatten(0),
	\octave, 4,
	\scale, Scale.chromatic,
	\degree, Pget(\pedal, 0, inf) + Pkey(\figures),
	\dur, 0.25,
	\sustain, Pkey(\dur),
	\amp, Pseq([0.35, 0.35, 0.3, 0.2!5].flatten(1), inf) * 0.8,
	\out, [0, ~reverbBus, ~delayThenReverbBus],
	\group, ~sourceGroup,
	\pan, Pseq(([0.5, -0.5]!4).flatten.mirror2, inf)
);

~comps = Ptpar([
	0,
	~arps,
	16,
	~blocks,
], inf);


~highHat = Pbind(
	\instrument, \highHat,
	\sustain, Pwrand([0.01, 0.04], [0.75, 0.25], inf),
	\dur, Pdup(
		Pxrand([4 ,8, 12, 16], inf),
		Pxrand([1/4 ,1/8, 1/16], inf)
	),
	\amp, Pseq([0.2, 0.15, 0.15, 0.15], inf) * Pwrand([0.6, 0.3, 0], [0.7, 0.2, 0.1], inf),
	\out, [0, ~reverbBus],
	\group, ~sourceGroup,
	\pan, Pseq([0.2, 0.3], inf)
);

Plambda(Ppar([
	~fundamental,
	~bassDurs,
	~kick,
	~bass,
	~comps,
	~highHat
], inf)).play;

)
