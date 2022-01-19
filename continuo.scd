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

SynthDef(\harp, {
	arg freq = 50, out = 1, gate = 1, amp = 0.5, pan=0;
	var sig, env, envGen, vib;

	env = Env([0, 0.5, 0.2, 0], [0.01, 0.1, 0.2], releaseNode: 2);
	envGen = EnvGen.ar(envelope: env, gate: gate, doneAction: Done.freeSelf);

	vib = SinOsc.ar(3, 0, 1.25);
	sig = Mix.ar([
		SinOsc.ar(freq: freq + vib, mul: amp),
		Pulse.ar(freq: freq + vib, mul: amp*Line.kr(1/4, 1/12, 0.1))
	]);
	sig = sig * envGen;
	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig);
}).add;

SynthDef(\bassTone, {
	arg freq = 50, out = 1, gate = 1, amp = 0.5, pan=0;
	var sig, env, envGen, lagFreq;

	env = Env(
		levels: [0, 0.5, 0.2, 0],
		times: [0.0075, 0.05, 0.94],
		curve: [3, -3, 0]
	);

	envGen = EnvGen.ar(envelope: env, gate: 1, doneAction: Done.freeSelf);

	sig = Mix.ar([
		SinOsc.ar(freq: freq/4, mul: amp*Line.kr(1/2, 1, 0.5)),
		SinOsc.ar(freq: freq/2, mul: amp*Line.kr(1/2, 1, 0.5)),
		SinOsc.ar(freq: freq, mul: amp),
		SinOsc.ar(freq: freq*2, mul: amp*Line.kr(1/3, 1/12, 0.5)),
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

	var env = EnvGen.kr(Env([0,0.4,0], [0.01, 0.49], [1, 6]), doneAction: Done.freeSelf);

	var sig = SinOsc.ar(freqSweep, pi/2);
	sig = sig * env;
	sig = Pan2.ar(sig, pan, amp);
	Out.ar(out, sig);
}).add;

SynthDef(\highHat, {
	arg out = 1, gate = 1, amp = 0.5, pan=0, freq=10000;
	var sig, env, envGen;

	env = Env([0, 0.4, 0], [0.0005, 0.05], releaseNode: 1);
	envGen = EnvGen.ar(envelope: env, gate: gate, doneAction: Done.freeSelf);

	sig = Mix.ar([ClipNoise.ar(amp,  0), BrownNoise.ar(amp, 0)]);
	sig = BPF.ar(sig, freq, 0.75) * envGen;
	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig);
}).add;

SynthDef(\reverb, {
	arg in=0, out=0;
	var sig = In.ar(in, 2);
	sig = FreeVerb2.ar(sig[0], sig[1], 0.4, 0.6, 0.2);
	Out.ar(out, sig);
}).add;

SynthDef(\delay, {
	arg in=0, out=0;

	var sig = In.ar(in, 2);
	sig = CombC.ar(sig, 3.5, 1/2, 5);
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
	\delta, Prand([1, 0.75, 0.5], inf),
	\sustain, 0,
	\out, [0, ~reverbBus],
	\group, ~sourceGroup,
	\amp, 0.7,
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
	\delta, Pdup(16, (Prand([0.25,0.125,0.025].collect(~durArr), inf))).flatten(0),
	\amp, Pseq([0.35, 0.35, 0.3, 0.2!5].flatten(1), inf) * 0.8,
	\out, [0, ~delayThenReverbBus],
	\group, ~sourceGroup,
	\pan, Pseq(([0.75, -0.75]!4).flatten.mirror2, inf)
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
	\freq, Pwrand(
		[
			10000 * (0.9**Pseq((0..7), 1)),
			Pseq(10000!4, 1)
		],
		[0.25, 0.75],
		inf
	),
	\amp, Pseq([0.2, 0.15, 0.15, 0.15], inf) * Pwrand([0.6, 0.3, 0], [0.7, 0.2, 0.1], inf),
	\out, [0, ~reverbBus],
	\group, ~sourceGroup,
	\pan, Pseq([0.2, 0.3], inf)
);

~changeTempo = {
	arg newTempo = 1, changeDur = 1, stepCount = 10;
	var delta = newTempo - TempoClock.default.tempo;
	var deltaSlice = delta/stepCount;
	var stepper = Routine.new({
		stepCount.do({
			TempoClock.default.tempo = TempoClock.default.tempo + deltaSlice;
			(changeDur/stepCount).wait;
		});
	}).play;
};
~tempo = Pbind(
	\amp, Rest(),
	\dur, Prand([64, 128, 256], inf),
	\tempoNum, Pxrand([0.7, 0.85, 1], inf),
	\callback, { |e| topEnvironment[\changeTempo].value(e.tempoNum, 2, 20) }
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