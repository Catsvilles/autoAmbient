(
~figs = [
	[1, 4],
	[2, 4],
	[2, 5],
	[3, 4],
	[3, 5]
];

TempoClock.default.tempo = 0.85;

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
		levels: [0, 0.8, 0.35, 0, 0],
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
	\degree, Plet(\pedal, Pfuncn({ (-4..4).choose }, inf)).trace,
	// \dur, (Prand([ 2, 4, [3, 1], [1, 1] ], inf).flatten * 8).trace,
	\dur, (Prand([ [1, 1] ], inf).flatten * 8).trace,
	\scale, Plet(\scale, Prand([Scale.major, Scale.minor], inf), inf),
	\amp, 0,
);

~bassDurs = Plet(\bassHit, Pxrand([1, 0.75, 0.5], inf));

~bass = Pbind(
	\instrument, \bassTone,
	\degree, Pget(\pedal, 0, inf).trace,
	\scale, Pget(\scale, Scale.major, inf),
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
	var indices = (0..4).scramble.keep(2);
	[
		[~figs[indices[0]], 7],
		[~figs[indices[1]], 7]
	].flatten2(-1);
}, 1);
~blocks = Pbind(
	\instrument, \tone,
	\figures, Pdup(2, ~blocksFigures).flatten(0),
	\octave, [5, 4, 4],
	\scale, Pget(\mode, Scale.major, inf),
	\degree, Pget(\pedal, 0, inf) + Pkey(\figures).trace,
	\dur, 4,
	\sustain, Pkey(\dur),
	\amp, [0.2, 0.3, 0.2],
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
	var arpOrder = (0..4).scramble;

	var figArr1 = ~figs[indices[0]];
	var figArr2 = ~figs[indices[1]];

	var arpArr1 = figArr1++7++(7+figArr1);
	var arpArr2 = figArr2++7++(7+figArr2);

	var scrambledArpArr1 = arpOrder.collect({|i| arpArr1[i] });
	var scrambledArpArr2 = arpOrder.collect({|i| arpArr2[i] });

	(
		scrambledArpArr1++
		[Rest()!3]++
		scrambledArpArr2++
		[Rest()!3]
	).flatten(1);
}, 1);
~arps = Pbind(
	\instrument, \tone,
	\figures, Pdup(4, ~arpsFigures).flatten(0).trace,
	\octave, 4,
	\scale, Pget(\mode, Scale.major, inf),
	\degree, Pget(\pedal, 0, inf) + Pkey(\figures),
	\dur, 0.25,
	\sustain, Pkey(\dur),
	\amp, Pseq([0.35, 0.35, 0.3, 0.2!5].flatten(1), inf) * 0.8,
	\out, [0, ~delayThenReverbBus],
	\group, ~sourceGroup,
	\pan, Pseq(([0.5, -0.5]!4).flatten.mirror2, inf)
);

~comps = Ptpar([
	0,
	~blocks,
	16,
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

Plambda(Ppar([
	~fundamental,
	~bassDurs,
	~kick,
	~bass,
	~comps,
	~highHat
], inf)).play;

)
