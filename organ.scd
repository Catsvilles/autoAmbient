(
SynthDef(\octaves, {
	arg semitone = 0, out = 0, gate = 1;

	var sig = Mix.fill(
		10,
		{
			|i|
			Mix.fill(
				5,
				{
					|j|
					FSinOsc.ar((semitone+(12*i)).midicps * (j + 1)) * (1/(j+1))
				}
			)
		}
	)!2 * 0.2;

	var env = EnvGen.kr(Env.adsr(0.08, 0.12, 0.9, 0.2, 1, -4), gate, doneAction: Done.freeSelf);
	sig = BLowPass4.ar(
		in: sig,
		freq: 1200,
		rq: 2,
	);
	/*sig = BHiPass4.ar(
		in: sig,
		freq: 150,
		rq: 2,
	);*/
	sig = BPZ2.ar(sig);
	// sig = FreeVerb.ar(sig, 0.5, 0.7, 0.5);
	Out.ar(
		out,
		sig * env
	)
}).add;
)

s.freqscope;

(
Pbind(
	\instrument, \octaves,
	\semitone, Pseq([
		Array.fill(8, { [0, 4, 7] }),
		Array.fill(8, { [0, 4, 9] }),
		Array.fill(8, { [1, 4, 9] }),
		Array.fill(8, { [2, 5, 10] }),
		Array.fill(8, { [2, 7, 11] }),
].flatten(1), inf),
	\dur, 0.25,
	\sustain, 0.25
).play;
)


Quarks.gui


