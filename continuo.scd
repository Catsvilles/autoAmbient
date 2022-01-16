(
~figs = [
	[3, 5, 7],
	[3, 5, 6],
	[3, 4, 6],
	[2, 4, 6],
	[2, 5, 6],
	[4, 5, 7],
].deepCollect(5, {|i| i - 1});

~sectionLength = 16;

SynthDef(\tone, {
	arg freq = 50, out = 1, gate = 1, amp = 0.5, pan=0;
	var sig, env, envGen, vib, lagFreq;

	env = Env([0, 0.5, 0], [0.01, 0.1], releaseNode: 1);
	envGen = EnvGen.ar(envelope: env, gate: gate, doneAction: Done.freeSelf);

	vib = SinOsc.ar(3, 0, 1.25);
	lagFreq = Lag.kr(freq, 0.1);
	sig = Mix.ar([
		SinOsc.ar(freq: lagFreq + vib, mul: amp),
		Saw.ar(freq: lagFreq + vib, mul: amp/3)
	]);
	sig = sig * envGen;
	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig);
}).add;

SynthDef(\harp, {
	arg freq = 50, out = 1, gate = 1, amp = 0.5, pan=0;
	var sig, env, envGen, vib;

	env = Env([0, 0.7, 0.35, 0], [0.01, 0.1, 0.2], releaseNode: 2);
	envGen = EnvGen.ar(envelope: env, gate: gate, doneAction: Done.freeSelf);

	vib = SinOsc.ar(3, 0, 1.25);
	sig = Mix.ar([
		SinOsc.ar(freq: freq + vib, mul: amp),
		Pulse.ar(freq: freq + vib, mul: amp/3)]);
	sig = sig * envGen;
	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig);
}).add;

SynthDef(\bassTone, {
	arg freq = 50, out = 1, gate = 1, amp = 0.5, pan=0;
	var sig, env, envGen, lagFreq;

	env = Env(
		levels: [0, 0.9, 0.3, 0],
		times: [0.005, 0.05, 0.44],
		curve: [3, -3, 0],
		releaseNode: 2
	);

	envGen = EnvGen.ar(envelope: env, gate: gate, doneAction: Done.freeSelf);

	sig = Mix.ar([
		SinOsc.ar(freq: freq/4, mul: amp),
		SinOsc.ar(freq: freq/2, mul: amp),
		SinOsc.ar(freq: freq, mul: amp),
		SinOsc.ar(freq: freq*2, mul: amp/6),
		SinOsc.ar(freq: freq*3, mul: amp/5),
		Saw.ar(freq: freq, mul: amp/3),
		Saw.ar(freq: freq*2, mul: amp/12),
	]);
	sig = sig * envGen;
	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig);
}).add;

SynthDef(\kick, {
	arg freq = 500, pan = 0, out = 0, amp = 0.5;

	var freqSweep = Env(
		[freq/2, freq/2, freq/10, freq/50],
		[0.01, 0.02, 0.47],
		[0, 1, -1,]
	).ar;

	var env = EnvGen.kr(Env([0,0.75,0], [0.01, 0.49], [1, 6]), doneAction: Done.freeSelf);

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

~scaleOptions = [
	Scale.major,
	Scale.dorian,
	Scale.lydian,
	Scale.mixolydian,
	Scale.minor
];

~fundamental = Pbind(
	\event, \rest,
	\scale, Plet(\mode, Prand(~scaleOptions, inf), inf),
	\root, Plet(\pedal, Pxrand((-5..5), inf)).trace,
	\tuning, Plet(\tuning, Tuning.pythagorean, inf),
	\dur, Prand([ 2, 4, [3, 1], [1, 1] ], inf).flatten * 8,
	\amp, 0,
);

~bass = Pbind(
	\instrument, \bassTone,
	\root, Pget(\pedal, 0, inf),
	\scale, Pget(\mode, Scale.major, inf),
	\tuning, Pget(\tuning, Tuning.pythagorean, inf),
	\octave, Pwrand([3, 4], [0.75, 0.25], inf),
	\degree, 0,
	\dur, Prand([1, 0.75, 0.5], inf),
	\sustain, Pkey(\dur) - 0.25,
	\out, [0, ~reverbBus],
	\group, ~sourceGroup,
	\amp, 0.6,
	\pan, 0
);

~kick = Pbind(
	\instrument, \kick,
	\type, Pseq([
		Pwrand([\note, Rest()], [0.9, 0.1]),
		Pwrand([\note, Rest()], [0.1, 0.9]),
		Pwrand([\note, Rest()], [0.2, 0.8]),
		Pwrand([\note, Rest()], [0.2, 0.8]),
	], inf),
	\freq, 300,
	\amp, 0.6,
	\group, ~sourceGroup,
	\out, [0, ~reverbBus],
	\dur, 0.25,
	\pan, -0.2
);

~blocksFigures = Pfuncn({
	var indices = (0..4).scramble.keep(2);
	[
		[~figs[indices[0]], 7],
		[~figs[indices[1]], 7]
	].flatten2(-1);
}, 1);

~blocks = Pmono(\tone,
	\tuning, Pget(\tuning, Tuning.pythagorean, inf),
	\root, Pget(\pedal, 0, inf),
	\octave, [5, 4, 4],
	\degree, Pdup(2, ~blocksFigures).flatten(0),
	\scale, Pget(\mode, Scale.minor, inf),
	\dur, 4,
	\sustain, Pkey(\dur),
	\amp, [0.2, 0.3, 0.3],
	\out, [0, ~reverbBus],
	\group, ~sourceGroup,
	\pan, Pfunc({ |e|
		Array.fill(
			e[\degree].size,
			{|i| (i/(e[\degree].size + 1))*2 - 0.5 }
	) })
);

~walkMelody = Pfindur(
	~sectionLength,
	Pmono(
		\tone,
		\tuning, Plet(\tuning, Tuning.pythagorean, inf),
		\root, Pget(\pedal, 0, inf),
		\octave, 5,
		\degree, Pwalk((0..15), Prand([-2, -1, 1, 2], inf), -1, (0..12).choose),
		\dur, Prand([4, 0.5], inf),
		\sustain, Pkey(\dur),
		\lag, 0.05,
		\amp, 0.3
	),
);

~arpsFigures = Pfuncn({
	var indices = (0..(~figs.size - 1)).scramble.keep(2);

	var figArr1 = ~figs[indices[0]];
	var figArr2 = ~figs[indices[1]];

	var arpArr1 = (figArr1++(7+figArr1));
	var arpArr2 = figArr2++(7+figArr2);

	var arpOrder = (0..5).scramble;
	var scrambledArpArr1 = arpOrder.collect({|i| arpArr1[i] });
	var scrambledArpArr2 = arpOrder.collect({|i| arpArr2[i] });

	[
		scrambledArpArr1++scrambledArpArr1.keep(2),
		scrambledArpArr2++scrambledArpArr2.keep(2)
	].flatten(0);
}, 1);
~durArr = {|dur| dur!7++[(0.25*8)-(dur*7)]};
~arps = Pbind(
	\instrument, \harp,
	\tuning, Pget(\tuning, Tuning.pythagorean, inf),
	\figures, Pdup(4, ~arpsFigures).flatten(1),
	\octave, 4,
	\scale, Pget(\mode, Scale.major, inf),
	\root, Pget(\pedal, 0, inf),
	\degree, Pkey(\figures),
	\dur, Pdup(4, (Prand([0.25,0.125,0.025].collect(~durArr), inf))).flatten(0),
	\sustain, 0.5,
	\amp, Pseq([0.35, 0.35, 0.3, 0.2!5].flatten(1), inf) * 0.8,
	\out, [0, ~delayThenReverbBus],
	\group, ~sourceGroup,
	\pan, Pseq(([0.5, -0.5]!4).flatten.mirror2, inf)
);

~comps = Ptpar([
	0,
	~arps,
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

~tempo = Pbind(
	\note, Rest(),
	\dur, 64,
	\tempo, Prand([0.5, 0.85, 1], inf),
	\callback, { |e| TempoClock.default.tempo = e.tempo; }
);

Plambda(Ppar([
	~fundamental,
	~bassDurs,
	~kick,
	~bass,
	~comps,
	~highHat,
	~tempo
], inf)).play;
)
